package br.com.focodev.academia.service;

import br.com.focodev.academia.domain.*;
import br.com.focodev.academia.dto.*;
import br.com.focodev.academia.exception.ApiException;
import br.com.focodev.academia.repository.*;
import br.com.focodev.academia.security.AuthUser;
import lombok.RequiredArgsConstructor;
import org.springframework.stereotype.Service;
import org.springframework.transaction.annotation.Transactional;

import java.time.DayOfWeek;
import java.time.Instant;
import java.time.LocalDate;
import java.time.ZoneId;
import java.time.temporal.TemporalAdjusters;
import java.util.*;

@Service
@RequiredArgsConstructor
public class WorkoutProgramService {

    private final WorkoutProgramRepository programRepository;
    private final WorkoutDayRepository dayRepository;
    private final WorkoutSessionRepository sessionRepository;
    private final SetLogRepository setLogRepository;
    private final UserRepository userRepository;
    private final TenantService tenantService;

    @Transactional
    public WorkoutProgramResponse createProgram(AuthUser instructor, CreateWorkoutProgramRequest request) {
        User instructorUser = tenantService.requireInstructor(instructor);
        User student = userRepository.findById(request.studentId())
                .orElseThrow(() -> new ApiException("Aluno não encontrado"));
        tenantService.requireStudentInInstructorAcademy(instructorUser, student);

        programRepository.findFirstByStudentIdAndActiveTrueOrderByCreatedAtDesc(student.getId())
                .ifPresent(existing -> {
                    existing.setActive(false);
                    programRepository.save(existing);
                });

        WorkoutProgram program = new WorkoutProgram();
        program.setTitle(request.title().trim());
        program.setDescription(request.description());
        program.setInstructor(instructorUser);
        program.setStudent(student);

        for (WorkoutDayRequest dayRequest : request.days()) {
            WorkoutDay day = new WorkoutDay();
            day.setProgram(program);
            day.setWeekDay(dayRequest.weekDay());
            day.setMuscleGroup(dayRequest.muscleGroup());
            day.setNotes(dayRequest.notes());
            day.setRestDay(dayRequest.restDay());
            day.setSortOrder(dayRequest.sortOrder());

            if (!dayRequest.restDay() && dayRequest.exercises() != null) {
                for (ExerciseRequest exerciseRequest : dayRequest.exercises()) {
                    day.getExercises().add(mapExercise(day, exerciseRequest));
                }
            }
            program.getDays().add(day);
        }

        return WorkoutProgramResponse.from(programRepository.save(program));
    }

    @Transactional(readOnly = true)
    public List<WorkoutProgramResponse> listInstructorPrograms(AuthUser instructor) {
        tenantService.requireInstructor(instructor);
        return programRepository.findByInstructorIdOrderByCreatedAtDesc(instructor.getId()).stream()
                .map(WorkoutProgramResponse::from)
                .toList();
    }

    @Transactional(readOnly = true)
    public WorkoutProgramResponse getProgram(AuthUser user, UUID programId) {
        WorkoutProgram program = programRepository.findById(programId)
                .orElseThrow(() -> new ApiException("Ficha não encontrada"));
        requireProgramAccess(user, program);

        WorkoutProgram detailed = programRepository.findByIdWithDays(programId)
                .orElseThrow(() -> new ApiException("Ficha não encontrada"));
        return buildProgramResponse(detailed, user);
    }

    @Transactional(readOnly = true)
    public WorkoutProgramResponse getActiveStudentProgram(AuthUser student) {
        tenantService.requireActiveAcademy(userRepository.findById(student.getId())
                .orElseThrow(() -> new ApiException("Aluno não encontrado")));

        WorkoutProgram program = programRepository.findFirstByStudentIdAndActiveTrueOrderByCreatedAtDesc(student.getId())
                .orElseThrow(() -> new ApiException("Nenhuma ficha semanal ativa"));
        return buildProgramResponse(program, student);
    }

    @Transactional
    public WorkoutSessionResponse startOrResumeSession(AuthUser student, UUID dayId) {
        User studentUser = userRepository.findById(student.getId())
                .orElseThrow(() -> new ApiException("Aluno não encontrado"));
        tenantService.requireActiveAcademy(studentUser);

        WorkoutDay day = dayRepository.findByIdWithDetails(dayId)
                .orElseThrow(() -> new ApiException("Dia de treino não encontrado"));

        if (!day.getProgram().getStudent().getId().equals(student.getId())) {
            throw new ApiException("Acesso negado");
        }
        if (day.isRestDay()) {
            throw new ApiException("Este dia é de descanso");
        }

        WorkoutSession session = sessionRepository
                .findByWorkoutDayIdAndStudentIdAndCompletedAtIsNull(dayId, student.getId())
                .orElseGet(() -> {
                    WorkoutSession created = new WorkoutSession();
                    created.setWorkoutDay(day);
                    created.setStudent(studentUser);
                    return sessionRepository.save(created);
                });

        return WorkoutSessionResponse.from(sessionRepository.findByIdWithSetLogs(session.getId()).orElseThrow());
    }

    @Transactional
    public WorkoutSessionResponse toggleSet(AuthUser student, UUID sessionId, LogSetRequest request) {
        WorkoutSession session = loadStudentSession(student, sessionId);
        if (session.getCompletedAt() != null) {
            throw new ApiException("Treino já finalizado");
        }

        Exercise exercise = session.getWorkoutDay().getExercises().stream()
                .filter(e -> e.getId().equals(request.exerciseId()))
                .findFirst()
                .orElseThrow(() -> new ApiException("Exercício não encontrado"));

        int maxSets = exercise.getSets() != null ? exercise.getSets() : 1;
        if (request.setNumber() < 1 || request.setNumber() > maxSets) {
            throw new ApiException("Série inválida");
        }

        Optional<SetLog> existing = setLogRepository.findBySessionIdAndExerciseIdAndSetNumber(
                sessionId, request.exerciseId(), request.setNumber());

        if (existing.isPresent()) {
            session.getSetLogs().remove(existing.get());
            setLogRepository.delete(existing.get());
        } else {
            Instant now = Instant.now();
            Long elapsedMs = session.getSetLogs().stream()
                    .max(Comparator.comparing(SetLog::getCompletedAt))
                    .map(last -> now.toEpochMilli() - last.getCompletedAt().toEpochMilli())
                    .orElse(now.toEpochMilli() - session.getStartedAt().toEpochMilli());

            SetLog log = new SetLog();
            log.setSession(session);
            log.setExercise(exercise);
            log.setSetNumber(request.setNumber());
            log.setCompletedAt(now);
            log.setElapsedMs(elapsedMs);
            session.getSetLogs().add(log);
            setLogRepository.save(log);
        }

        return WorkoutSessionResponse.from(sessionRepository.findByIdWithSetLogs(sessionId).orElseThrow());
    }

    @Transactional
    public SessionCompleteResponse completeSession(AuthUser student, UUID sessionId, CompleteSessionRequest request) {
        WorkoutSession session = loadStudentSession(student, sessionId);
        if (session.getCompletedAt() != null) {
            throw new ApiException("Treino já finalizado");
        }

        Instant now = Instant.now();
        session.setCompletedAt(now);
        session.setTotalDurationSeconds(now.getEpochSecond() - session.getStartedAt().getEpochSecond());
        session.setRating(request.rating());
        session.setComment(request.comment());
        sessionRepository.save(session);

        StudentStatsResponse stats = buildStats(student.getId());
        String message = buildCompletionMessage(stats);

        return new SessionCompleteResponse(
                WorkoutSessionResponse.from(sessionRepository.findByIdWithSetLogs(sessionId).orElseThrow()),
                stats,
                message
        );
    }

    @Transactional(readOnly = true)
    public StudentStatsResponse getStudentStats(AuthUser student) {
        tenantService.requireActiveAcademy(userRepository.findById(student.getId())
                .orElseThrow(() -> new ApiException("Aluno não encontrado")));
        return buildStats(student.getId());
    }

    @Transactional(readOnly = true)
    public WorkoutDayResponse getStudentDay(AuthUser student, UUID dayId) {
        WorkoutDay day = dayRepository.findByIdWithDetails(dayId)
                .orElseThrow(() -> new ApiException("Dia de treino não encontrado"));
        if (!day.getProgram().getStudent().getId().equals(student.getId())) {
            throw new ApiException("Acesso negado");
        }

        UUID activeSessionId = sessionRepository
                .findByWorkoutDayIdAndStudentIdAndCompletedAtIsNull(dayId, student.getId())
                .map(WorkoutSession::getId)
                .orElse(null);
        boolean completedThisWeek = isDayCompletedThisWeek(student.getId(), day.getWeekDay());

        return WorkoutDayResponse.from(day, activeSessionId, completedThisWeek);
    }

    private WorkoutProgramResponse buildProgramResponse(WorkoutProgram program, AuthUser user) {
        UUID studentId = user.getRole() == UserRole.ALUNO ? user.getId() : program.getStudent().getId();
        Set<WeekDay> completedDays = completedWeekDays(studentId);

        List<WorkoutDayResponse> days = program.getDays().stream()
                .map(day -> {
                    UUID activeSessionId = sessionRepository
                            .findByWorkoutDayIdAndStudentIdAndCompletedAtIsNull(day.getId(), studentId)
                            .map(WorkoutSession::getId)
                            .orElse(null);
                    return WorkoutDayResponse.from(day, activeSessionId, completedDays.contains(day.getWeekDay()));
                })
                .toList();

        return WorkoutProgramResponse.from(program, days);
    }

    @Transactional(readOnly = true)
    public List<SessionFeedbackResponse> listSessionFeedbacksForInstructor(AuthUser instructor) {
        tenantService.requireInstructor(instructor);
        return sessionRepository.findCompletedByInstructorId(instructor.getId()).stream()
                .map(SessionFeedbackResponse::from)
                .toList();
    }

    private StudentStatsResponse buildStats(UUID studentId) {
        Instant weekStart = LocalDate.now(ZoneId.of("America/Sao_Paulo"))
                .with(TemporalAdjusters.previousOrSame(DayOfWeek.MONDAY))
                .atStartOfDay(ZoneId.of("America/Sao_Paulo"))
                .toInstant();

        List<WorkoutSession> weekSessions = sessionRepository.findCompletedSince(studentId, weekStart);
        Set<WeekDay> completedWeekDays = new HashSet<>();
        for (WorkoutSession session : weekSessions) {
            completedWeekDays.add(session.getWorkoutDay().getWeekDay());
        }

        return new StudentStatsResponse(
                completedWeekDays.size(),
                (int) sessionRepository.countByStudentIdAndCompletedAtIsNotNull(studentId),
                calculateStreak(studentId),
                completedWeekDays.stream().map(Enum::name).sorted().toList()
        );
    }

    private Set<WeekDay> completedWeekDays(UUID studentId) {
        Instant weekStart = LocalDate.now(ZoneId.of("America/Sao_Paulo"))
                .with(TemporalAdjusters.previousOrSame(DayOfWeek.MONDAY))
                .atStartOfDay(ZoneId.of("America/Sao_Paulo"))
                .toInstant();

        Set<WeekDay> completed = new HashSet<>();
        for (WorkoutSession session : sessionRepository.findCompletedSince(studentId, weekStart)) {
            completed.add(session.getWorkoutDay().getWeekDay());
        }
        return completed;
    }

    private boolean isDayCompletedThisWeek(UUID studentId, WeekDay weekDay) {
        return completedWeekDays(studentId).contains(weekDay);
    }

    private int calculateStreak(UUID studentId) {
        LocalDate today = LocalDate.now(ZoneId.of("America/Sao_Paulo"));
        int streak = 0;
        for (int i = 0; i < 30; i++) {
            LocalDate date = today.minusDays(i);
            Instant start = date.atStartOfDay(ZoneId.of("America/Sao_Paulo")).toInstant();
            Instant end = date.plusDays(1).atStartOfDay(ZoneId.of("America/Sao_Paulo")).toInstant();
            boolean trained = sessionRepository.findCompletedSince(studentId, start).stream()
                    .anyMatch(s -> s.getCompletedAt() != null
                            && !s.getCompletedAt().isBefore(start)
                            && s.getCompletedAt().isBefore(end));
            if (trained) {
                streak++;
            } else if (i > 0) {
                break;
            }
        }
        return streak;
    }

    private String buildCompletionMessage(StudentStatsResponse stats) {
        if (stats.daysCompletedThisWeek() >= 5) {
            return "Incrível! Você treinou " + stats.daysCompletedThisWeek() + " dias esta semana. Continue assim!";
        }
        if (stats.currentStreak() >= 3) {
            return "Parabéns! Sequência de " + stats.currentStreak() + " dias. Você está voando!";
        }
        return "Parabéns! Treino finalizado com sucesso. Continue firme na sua ficha semanal!";
    }

    private WorkoutSession loadStudentSession(AuthUser student, UUID sessionId) {
        WorkoutSession session = sessionRepository.findByIdWithSetLogs(sessionId)
                .orElseThrow(() -> new ApiException("Sessão não encontrada"));
        if (!session.getStudent().getId().equals(student.getId())) {
            throw new ApiException("Acesso negado");
        }
        return session;
    }

    private void requireProgramAccess(AuthUser user, WorkoutProgram program) {
        if (user.getRole() == UserRole.ALUNO && !program.getStudent().getId().equals(user.getId())) {
            throw new ApiException("Acesso negado");
        }
        if (user.getRole() == UserRole.INSTRUTOR && !program.getInstructor().getId().equals(user.getId())) {
            throw new ApiException("Acesso negado");
        }
    }

    private static Exercise mapExercise(WorkoutDay day, ExerciseRequest request) {
        Exercise exercise = new Exercise();
        exercise.setWorkoutDay(day);
        exercise.setName(request.name().trim());
        exercise.setDescription(request.description());
        exercise.setSets(request.sets());
        exercise.setReps(request.reps());
        exercise.setDuration(request.duration());
        exercise.setVideoUrl(request.videoUrl());
        exercise.setMediaType(request.mediaType() != null ? request.mediaType() : MediaType.NONE);
        exercise.setVariationNotes(request.variationNotes());
        exercise.setNotes(request.notes());
        exercise.setSortOrder(request.sortOrder());
        return exercise;
    }
}
