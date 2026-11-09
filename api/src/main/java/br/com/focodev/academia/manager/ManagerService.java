package br.com.focodev.academia.manager;

import br.com.focodev.academia.billing.BillingProperties;
import br.com.focodev.academia.domain.*;
import br.com.focodev.academia.dto.UserResponse;
import br.com.focodev.academia.exception.ApiException;
import br.com.focodev.academia.manager.ManagerDtos.*;
import br.com.focodev.academia.repository.*;
import br.com.focodev.academia.security.AuthUser;
import br.com.focodev.academia.security.JwtService;
import br.com.focodev.academia.service.DeviceService;
import br.com.focodev.academia.service.TenantService;
import br.com.focodev.academia.util.SlugHelper;
import lombok.RequiredArgsConstructor;
import org.springframework.http.HttpStatus;
import org.springframework.security.crypto.password.PasswordEncoder;
import org.springframework.stereotype.Service;
import org.springframework.transaction.annotation.Transactional;

import java.time.*;
import java.time.format.DateTimeFormatter;
import java.util.*;
import java.util.stream.Collectors;

/**
 * Painel da academia: gestor (ou instrutor autônomo, dono da própria academia) vê instrutores,
 * alunos, desempenho, notas e reclamações. O instrutor de academia usa o recorte dos próprios alunos.
 */
@Service
@RequiredArgsConstructor
public class ManagerService {

    private static final ZoneId ZONE = ZoneId.of("America/Sao_Paulo");
    private static final DateTimeFormatter MONTH = DateTimeFormatter.ofPattern("yyyy-MM");

    private final UserRepository userRepository;
    private final AcademyRepository academyRepository;
    private final WorkoutSessionRepository workoutSessionRepository;
    private final CardioSessionRepository cardioSessionRepository;
    private final SuggestionRepository suggestionRepository;
    private final TenantService tenantService;
    private final PasswordEncoder passwordEncoder;
    private final JwtService jwtService;
    private final DeviceService deviceService;
    private final BillingProperties billingProperties;

    /** Treino concluído (musculação ou outdoor) de um aluno, para as contas do painel. */
    private record Activity(UUID studentId, Instant at, RatingLevel rating) {}

    // ---------------------------------------------------------------- cadastro

    /** Academia ou instrutor autônomo se cadastra pelo app e já entra. */
    @Transactional
    public RegisterBusinessResponse register(RegisterBusinessRequest request) {
        String email = request.email().trim().toLowerCase(Locale.ROOT);
        if (userRepository.existsByEmailIgnoreCase(email)) {
            throw new ApiException("Já existe uma conta com este e-mail. Entre com sua senha.");
        }
        boolean personal = request.type() == BusinessType.INSTRUTOR_AUTONOMO;
        String academyName = personal || request.academyName() == null || request.academyName().isBlank()
                ? request.name().trim()
                : request.academyName().trim();
        if (!personal && (request.academyName() == null || request.academyName().isBlank())) {
            throw new ApiException("Informe o nome da academia.");
        }

        Academy academy = new Academy();
        academy.setName(academyName);
        academy.setSlug(SlugHelper.unique(SlugHelper.fromName(academyName), academyRepository::existsBySlugIgnoreCase));
        academy.setPersonal(personal);
        academy = academyRepository.save(academy);

        User user = new User();
        user.setEmail(email);
        user.setPasswordHash(passwordEncoder.encode(request.password()));
        user.setName(request.name().trim());
        user.setRole(personal ? UserRole.INSTRUTOR : UserRole.GESTOR);
        user.setAcademy(academy);
        user.setLastLoginAt(Instant.now());
        user = userRepository.save(user);

        academy.setOwner(user);
        academyRepository.save(academy);

        if (request.deviceId() != null && !request.deviceId().isBlank()) {
            deviceService.registerDevice(user, request.deviceId(), request.deviceLabel(),
                    request.appClient(), request.appVersion());
        }
        return new RegisterBusinessResponse(
                jwtService.generateToken(new AuthUser(user)), UserResponse.from(user), academy.getSlug());
    }

    // ---------------------------------------------------------------- painel

    @Transactional(readOnly = true)
    public Access access(AuthUser authUser) {
        User user = userRepository.findByIdWithAcademy(authUser.getId())
                .orElseThrow(() -> new ApiException("Usuário não encontrado"));
        tenantService.requireActiveAcademy(user);
        Academy academy = user.getAcademy();
        if (academy == null) {
            return new Access(false, false, null, null);
        }
        return new Access(isManager(user), academy.isPersonal(), academy.getName(), academy.getSlug());
    }

    @Transactional(readOnly = true)
    public Dashboard dashboard(AuthUser authUser) {
        User manager = requireManager(authUser);
        Academy academy = manager.getAcademy();
        Instant now = Instant.now();

        List<User> students = userRepository.findByAcademyIdAndRoleOrderByNameAsc(academy.getId(), UserRole.ALUNO);
        List<User> instructors = instructorsOf(academy);
        List<Activity> activity = academyActivity(academy.getId(), now.minus(Duration.ofDays(190)));
        List<Suggestion> suggestions = suggestionRepository.findByAcademyId(academy.getId());

        Instant last7 = now.minus(Duration.ofDays(7));
        Instant last30 = now.minus(Duration.ofDays(30));
        List<Activity> recent30 = activity.stream().filter(a -> a.at().isAfter(last30)).toList();

        Map<String, Long> distribution = new LinkedHashMap<>();
        for (RatingLevel level : RatingLevel.values()) distribution.put(level.name(), 0L);
        recent30.stream().filter(a -> a.rating() != null)
                .forEach(a -> distribution.merge(a.rating().name(), 1L, Long::sum));

        List<InstructorStats> ranking = instructors.stream()
                .map(i -> instructorStats(i, students, activity, suggestions, last30))
                .sorted(Comparator.comparingLong(InstructorStats::sessions30d).reversed())
                .toList();

        return new Dashboard(
                academy.getName(),
                academy.getSlug(),
                academy.isPersonal(),
                billingProperties.academyMonthlyPriceOrDefault(),
                billingProperties.academyIncludedStudentsOrDefault(),
                instructors.size(),
                students.size(),
                activity.stream().filter(a -> a.at().isAfter(last7)).map(Activity::studentId).distinct().count(),
                recent30.size(),
                averageScore(recent30),
                suggestions.stream().filter(s -> s.getStatus() != SuggestionStatus.RESPONDIDA).count(),
                distribution,
                months(activity, now),
                ranking
        );
    }

    @Transactional(readOnly = true)
    public List<InstructorStats> instructors(AuthUser authUser) {
        Academy academy = requireManager(authUser).getAcademy();
        Instant last30 = Instant.now().minus(Duration.ofDays(30));
        List<User> students = userRepository.findByAcademyIdAndRoleOrderByNameAsc(academy.getId(), UserRole.ALUNO);
        List<Activity> activity = academyActivity(academy.getId(), last30);
        List<Suggestion> suggestions = suggestionRepository.findByAcademyId(academy.getId());
        return instructorsOf(academy).stream()
                .map(i -> instructorStats(i, students, activity, suggestions, last30))
                .toList();
    }

    @Transactional(readOnly = true)
    public List<StudentStats> students(AuthUser authUser) {
        Academy academy = requireManager(authUser).getAcademy();
        return studentStats(academy, userRepository.findByAcademyIdAndRoleOrderByNameAsc(academy.getId(), UserRole.ALUNO));
    }

    /** "Meus alunos" do instrutor de academia (só os dele), com atividade e média das notas. */
    @Transactional(readOnly = true)
    public List<StudentStats> studentsOfInstructor(AuthUser authUser) {
        User instructor = tenantService.requireInstructor(authUser);
        List<User> mine = userRepository.findByInstructorIdAndRoleAndActiveTrueOrderByNameAsc(instructor.getId(), UserRole.ALUNO);
        return studentStats(instructor.getAcademy(), mine);
    }

    @Transactional(readOnly = true)
    public List<RatingEntry> ratings(AuthUser authUser) {
        Academy academy = requireManager(authUser).getAcademy();
        return workoutSessionRepository
                .findCompletedByAcademySince(academy.getId(), Instant.now().minus(Duration.ofDays(180)))
                .stream()
                .filter(s -> s.getRating() != null)
                .sorted(Comparator.comparing(WorkoutSession::getCompletedAt).reversed())
                .limit(100)
                .map(s -> new RatingEntry(
                        s.getStudent().getId(),
                        s.getStudent().getName(),
                        s.getStudent().getInstructor() != null ? s.getStudent().getInstructor().getName() : null,
                        s.getRating().name(),
                        score(s.getRating()),
                        s.getComment(),
                        workoutLabel(s),
                        s.getCompletedAt()))
                .toList();
    }

    @Transactional(readOnly = true)
    public List<SuggestionEntry> suggestions(AuthUser authUser) {
        Academy academy = requireManager(authUser).getAcademy();
        return suggestionRepository.findByAcademyId(academy.getId()).stream().map(ManagerService::toEntry).toList();
    }

    @Transactional
    public SuggestionEntry respond(AuthUser authUser, UUID suggestionId, String response) {
        Academy academy = requireManager(authUser).getAcademy();
        Suggestion suggestion = suggestionRepository.findById(suggestionId)
                .filter(s -> s.getStudent().getAcademy() != null
                        && s.getStudent().getAcademy().getId().equals(academy.getId()))
                .orElseThrow(() -> new ApiException("Sugestão não encontrada"));
        suggestion.setResponse(response.trim());
        suggestion.setStatus(SuggestionStatus.RESPONDIDA);
        suggestion.setRespondedAt(Instant.now());
        return toEntry(suggestionRepository.save(suggestion));
    }

    // ---------------------------------------------------------------- equipe e alunos

    @Transactional
    public InstructorStats createInstructor(AuthUser authUser, CreatePersonRequest request) {
        Academy academy = requireManager(authUser).getAcademy();
        User instructor = newUser(request, UserRole.INSTRUTOR, academy);
        return new InstructorStats(instructor.getId(), instructor.getName(), instructor.getEmail(), true, 0, 0, null, 0);
    }

    @Transactional
    public StudentStats createStudent(AuthUser authUser, CreatePersonRequest request) {
        User manager = requireManager(authUser);
        Academy academy = manager.getAcademy();
        User instructor = request.instructorId() != null
                ? requireAcademyMember(academy, request.instructorId(), UserRole.INSTRUTOR)
                : (manager.getRole() == UserRole.INSTRUTOR ? manager : null);
        User student = newUser(request, UserRole.ALUNO, academy);
        student.setInstructor(instructor);
        userRepository.save(student);
        return studentStats(academy, List.of(student)).get(0);
    }

    @Transactional
    public StudentStats assignInstructor(AuthUser authUser, UUID studentId, UUID instructorId) {
        Academy academy = requireManager(authUser).getAcademy();
        User student = requireAcademyMember(academy, studentId, UserRole.ALUNO);
        student.setInstructor(requireAcademyMember(academy, instructorId, UserRole.INSTRUTOR));
        userRepository.save(student);
        return studentStats(academy, List.of(student)).get(0);
    }

    /** Desativa/reativa instrutor ou aluno da academia (a pessoa perde o acesso, o histórico fica). */
    @Transactional
    public void setActive(AuthUser authUser, UUID userId, boolean active) {
        User manager = requireManager(authUser);
        User member = userRepository.findById(userId)
                .filter(u -> u.getAcademy() != null && u.getAcademy().getId().equals(manager.getAcademy().getId()))
                .orElseThrow(() -> new ApiException("Pessoa não encontrada nesta academia"));
        if (member.getId().equals(manager.getId())) {
            throw new ApiException("Você não pode desativar a própria conta.");
        }
        if (member.getRole() != UserRole.ALUNO && member.getRole() != UserRole.INSTRUTOR) {
            throw new ApiException("Só instrutores e alunos podem ser desativados aqui.");
        }
        member.setActive(active);
        userRepository.save(member);
    }

    // ---------------------------------------------------------------- regras e contas

    /** Gestor da academia, ou instrutor autônomo (dono da própria academia). */
    public User requireManager(AuthUser authUser) {
        User user = userRepository.findByIdWithAcademy(authUser.getId())
                .orElseThrow(() -> new ApiException("Usuário não encontrado"));
        tenantService.requireActiveAcademy(user);
        if (isManager(user)) {
            return user;
        }
        throw new ApiException("Disponível só para o gestor da academia.", HttpStatus.FORBIDDEN);
    }

    private static boolean isManager(User user) {
        Academy academy = user.getAcademy();
        boolean owner = academy != null && academy.getOwner() != null && academy.getOwner().getId().equals(user.getId());
        return user.getRole() == UserRole.GESTOR || (user.getRole() == UserRole.INSTRUTOR && owner);
    }

    private List<User> instructorsOf(Academy academy) {
        return userRepository.findByAcademyIdAndRoleOrderByNameAsc(academy.getId(), UserRole.INSTRUTOR);
    }

    private User newUser(CreatePersonRequest request, UserRole role, Academy academy) {
        String email = request.email().trim().toLowerCase(Locale.ROOT);
        if (userRepository.existsByEmailIgnoreCase(email)) {
            throw new ApiException("Já existe uma conta com este e-mail.");
        }
        User user = new User();
        user.setEmail(email);
        user.setName(request.name().trim());
        user.setPasswordHash(passwordEncoder.encode(request.password()));
        user.setRole(role);
        user.setAcademy(academy);
        return userRepository.save(user);
    }

    private User requireAcademyMember(Academy academy, UUID userId, UserRole role) {
        return userRepository.findById(userId)
                .filter(u -> u.getRole() == role && u.getAcademy() != null && u.getAcademy().getId().equals(academy.getId()))
                .orElseThrow(() -> new ApiException(role == UserRole.INSTRUTOR
                        ? "Instrutor não encontrado nesta academia" : "Aluno não encontrado nesta academia"));
    }

    private List<Activity> academyActivity(UUID academyId, Instant since) {
        List<Activity> out = new ArrayList<>();
        for (WorkoutSession s : workoutSessionRepository.findCompletedByAcademySince(academyId, since)) {
            out.add(new Activity(s.getStudent().getId(), s.getCompletedAt(), s.getRating()));
        }
        for (CardioSession s : cardioSessionRepository.findCompletedByAcademySince(academyId, since)) {
            out.add(new Activity(s.getStudent().getId(), s.getCompletedAt(), null));
        }
        return out;
    }

    private List<StudentStats> studentStats(Academy academy, List<User> students) {
        if (academy == null || students.isEmpty()) return List.of();
        Instant last30 = Instant.now().minus(Duration.ofDays(30));
        Map<UUID, List<Activity>> byStudent = academyActivity(academy.getId(), Instant.now().minus(Duration.ofDays(190)))
                .stream().collect(Collectors.groupingBy(Activity::studentId));
        return students.stream().map(st -> {
            List<Activity> mine = byStudent.getOrDefault(st.getId(), List.of());
            List<Activity> recent = mine.stream().filter(a -> a.at().isAfter(last30)).toList();
            Instant last = mine.stream().map(Activity::at).max(Comparator.naturalOrder()).orElse(null);
            return new StudentStats(
                    st.getId(), st.getName(), st.getEmail(), st.isActive(),
                    st.getInstructor() != null ? st.getInstructor().getId() : null,
                    st.getInstructor() != null ? st.getInstructor().getName() : null,
                    last, recent.size(), averageScore(recent));
        }).toList();
    }

    private InstructorStats instructorStats(User instructor, List<User> students, List<Activity> activity,
                                            List<Suggestion> suggestions, Instant since) {
        Set<UUID> theirs = students.stream()
                .filter(s -> s.getInstructor() != null && s.getInstructor().getId().equals(instructor.getId()))
                .map(User::getId)
                .collect(Collectors.toSet());
        List<Activity> recent = activity.stream()
                .filter(a -> theirs.contains(a.studentId()) && a.at().isAfter(since))
                .toList();
        long pending = suggestions.stream()
                .filter(s -> s.getInstructor() != null && s.getInstructor().getId().equals(instructor.getId()))
                .filter(s -> s.getStatus() != SuggestionStatus.RESPONDIDA)
                .count();
        return new InstructorStats(instructor.getId(), instructor.getName(), instructor.getEmail(), instructor.isActive(),
                theirs.size(), recent.size(), averageScore(recent), pending);
    }

    private static List<MonthPoint> months(List<Activity> activity, Instant now) {
        YearMonth current = YearMonth.from(now.atZone(ZONE));
        Map<YearMonth, List<Activity>> byMonth = activity.stream()
                .collect(Collectors.groupingBy(a -> YearMonth.from(a.at().atZone(ZONE))));
        List<MonthPoint> points = new ArrayList<>();
        for (int i = 5; i >= 0; i--) {
            YearMonth month = current.minusMonths(i);
            List<Activity> list = byMonth.getOrDefault(month, List.of());
            points.add(new MonthPoint(month.format(MONTH), list.size(),
                    list.stream().map(Activity::studentId).distinct().count()));
        }
        return points;
    }

    /** Nota de 1 (muito ruim) a 5 (muito bom). */
    static int score(RatingLevel rating) {
        return switch (rating) {
            case MUITO_BOM -> 5;
            case BOM -> 4;
            case FACIL -> 3;
            case RUIM -> 2;
            case MUITO_RUIM -> 1;
        };
    }

    private static Double averageScore(List<Activity> activity) {
        OptionalDouble avg = activity.stream().filter(a -> a.rating() != null).mapToInt(a -> score(a.rating())).average();
        return avg.isPresent() ? Math.round(avg.getAsDouble() * 10) / 10.0 : null;
    }

    private static String workoutLabel(WorkoutSession session) {
        WorkoutDay day = session.getWorkoutDay();
        if (day == null) return null;
        return day.getMuscleGroup() != null ? day.getMuscleGroup() : day.getProgram().getTitle();
    }

    private static SuggestionEntry toEntry(Suggestion s) {
        return new SuggestionEntry(
                s.getId(),
                s.getStudent().getName(),
                s.getInstructor() != null ? s.getInstructor().getName() : null,
                s.getCategory(),
                s.getMessage(),
                s.getStatus().name(),
                s.getResponse(),
                s.getCreatedAt());
    }
}
