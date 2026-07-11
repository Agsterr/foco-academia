package br.com.focodev.academia.service;

import br.com.focodev.academia.domain.*;
import br.com.focodev.academia.dto.*;
import br.com.focodev.academia.exception.ApiException;
import br.com.focodev.academia.repository.*;
import br.com.focodev.academia.security.AuthUser;
import lombok.RequiredArgsConstructor;
import org.springframework.stereotype.Service;
import org.springframework.transaction.annotation.Transactional;

import java.time.Instant;
import java.time.LocalDate;
import java.time.format.DateTimeFormatter;
import java.util.ArrayList;
import java.util.List;
import java.util.UUID;

@Service
@RequiredArgsConstructor
public class StudentProfileService {

    private static final DateTimeFormatter ISO = DateTimeFormatter.ISO_INSTANT;

    private final StudentProfileRepository profileRepository;
    private final BodyMeasurementRepository measurementRepository;
    private final WeightCheckScheduleRepository scheduleRepository;
    private final GoalCheckInRepository goalCheckInRepository;
    private final UserRepository userRepository;
    private final TenantService tenantService;
    private final WorkoutProgramService workoutProgramService;

    @Transactional(readOnly = true)
    public StudentProfileDtos.ProfileStatusResponse getProfileStatus(AuthUser student) {
        User user = requireStudent(student);
        boolean onboardingCompleted = profileRepository.findByUserId(user.getId())
                .map(p -> p.getOnboardingCompletedAt() != null)
                .orElse(false);

        var pendingSchedule = scheduleRepository
                .findFirstByStudentIdAndCompletedFalseOrderByDueDateAsc(user.getId());

        boolean pendingWeight = pendingSchedule
                .map(s -> !s.isCompleted() && !LocalDate.now().isBefore(s.getDueDate()))
                .orElse(false);

        return new StudentProfileDtos.ProfileStatusResponse(
                onboardingCompleted,
                pendingWeight,
                pendingSchedule.map(this::toScheduleResponse).orElse(null),
                onboardingCompleted
        );
    }

    @Transactional(readOnly = true)
    public StudentProfileDtos.StudentProfileResponse getProfile(AuthUser student) {
        User user = requireStudent(student);
        StudentProfile profile = profileRepository.findByUserId(user.getId())
                .orElseThrow(() -> new ApiException("Perfil não encontrado"));
        return toProfileResponse(user, profile);
    }

    @Transactional(readOnly = true)
    public StudentProfileDtos.StudentProfileResponse getStudentProfile(AuthUser instructor, UUID studentId) {
        User instructorUser = tenantService.requireInstructor(instructor);
        User student = userRepository.findById(studentId)
                .orElseThrow(() -> new ApiException("Aluno não encontrado"));
        tenantService.requireStudentInInstructorAcademy(instructorUser, student);

        StudentProfile profile = profileRepository.findByUserId(studentId)
                .orElse(null);
        if (profile == null) {
            return new StudentProfileDtos.StudentProfileResponse(
                    student.getId(), student.getName(), null, null, null, false
            );
        }
        return toProfileResponse(student, profile);
    }

    @Transactional
    public StudentProfileDtos.StudentProfileResponse completeOnboarding(
            AuthUser student,
            StudentProfileDtos.OnboardingRequest request
    ) {
        User user = requireStudent(student);
        StudentProfile profile = profileRepository.findByUserId(user.getId()).orElse(new StudentProfile());
        profile.setUser(user);
        profile.setHeightCm(request.heightCm());
        profile.setCurrentWeightKg(request.weightKg());
        profile.setGoal(request.goal());
        profile.setOnboardingCompletedAt(Instant.now());
        profile.setUpdatedAt(Instant.now());
        profileRepository.save(profile);

        BodyMeasurement measurement = new BodyMeasurement();
        measurement.setStudent(user);
        measurement.setWeightKg(request.weightKg());
        measurement.setSource(MeasurementSource.STUDENT);
        measurementRepository.save(measurement);

        return toProfileResponse(user, profile);
    }

    @Transactional
    public StudentProfileDtos.BodyMeasurementResponse addMeasurement(
            AuthUser student,
            StudentProfileDtos.BodyMeasurementRequest request
    ) {
        User user = requireStudent(student);
        BodyMeasurement m = new BodyMeasurement();
        m.setStudent(user);
        m.setWeightKg(request.weightKg());
        m.setWaistCm(request.waistCm());
        m.setHipsCm(request.hipsCm());
        m.setChestCm(request.chestCm());
        m.setNotes(request.notes());
        m.setSource(MeasurementSource.STUDENT);
        measurementRepository.save(m);

        profileRepository.findByUserId(user.getId()).ifPresent(profile -> {
            profile.setCurrentWeightKg(request.weightKg());
            profile.setUpdatedAt(Instant.now());
            profileRepository.save(profile);
        });

        scheduleRepository.findFirstByStudentIdAndCompletedFalseOrderByDueDateAsc(user.getId())
                .ifPresent(schedule -> {
                    if (!LocalDate.now().isBefore(schedule.getDueDate())) {
                        schedule.setCompleted(true);
                        scheduleRepository.save(schedule);
                    }
                });

        return toMeasurementResponse(m);
    }

    @Transactional(readOnly = true)
    public List<StudentProfileDtos.BodyMeasurementResponse> listMeasurements(AuthUser student) {
        User user = requireStudent(student);
        return measurementRepository.findByStudentIdOrderByRecordedAtDesc(user.getId()).stream()
                .map(this::toMeasurementResponse)
                .toList();
    }

    @Transactional
    public StudentProfileDtos.WeightCheckScheduleResponse scheduleWeightCheck(
            AuthUser instructor,
            UUID studentId,
            StudentProfileDtos.WeightCheckScheduleRequest request
    ) {
        User instructorUser = tenantService.requireInstructor(instructor);
        User student = userRepository.findById(studentId)
                .orElseThrow(() -> new ApiException("Aluno não encontrado"));
        tenantService.requireStudentInInstructorAcademy(instructorUser, student);

        WeightCheckSchedule schedule = new WeightCheckSchedule();
        schedule.setStudent(student);
        schedule.setInstructor(instructorUser);
        schedule.setDueDate(request.dueDate());
        scheduleRepository.save(schedule);
        return toScheduleResponse(schedule);
    }

    @Transactional
    public StudentProfileDtos.GoalCheckInResponse submitGoalCheckIn(
            AuthUser student,
            StudentProfileDtos.GoalCheckInRequest request
    ) {
        User user = requireStudent(student);
        GoalCheckIn checkIn = new GoalCheckIn();
        checkIn.setStudent(user);
        checkIn.setAchievingGoal(request.achievingGoal());
        checkIn.setProgressRating(request.progressRating());
        checkIn.setComment(request.comment());
        goalCheckInRepository.save(checkIn);
        return toGoalCheckInResponse(checkIn);
    }

    @Transactional(readOnly = true)
    public List<StudentProfileDtos.GoalCheckInResponse> listGoalCheckIns(AuthUser instructor, UUID studentId) {
        User instructorUser = tenantService.requireInstructor(instructor);
        User student = userRepository.findById(studentId)
                .orElseThrow(() -> new ApiException("Aluno não encontrado"));
        tenantService.requireStudentInInstructorAcademy(instructorUser, student);
        return goalCheckInRepository.findByStudentIdOrderByCreatedAtDesc(studentId).stream()
                .map(this::toGoalCheckInResponse)
                .toList();
    }

    @Transactional
    public WorkoutProgramResponse createQuickProgram(
            AuthUser instructor,
            StudentProfileDtos.QuickProgramRequest request
    ) {
        User instructorUser = tenantService.requireInstructor(instructor);
        User student = userRepository.findById(request.studentId())
                .orElseThrow(() -> new ApiException("Aluno não encontrado"));
        tenantService.requireStudentInInstructorAcademy(instructorUser, student);

        FitnessGoal goal = profileRepository.findByUserId(student.getId())
                .map(StudentProfile::getGoal)
                .orElse(FitnessGoal.MANUTENCAO);

        CreateWorkoutProgramRequest programRequest = QuickWorkoutTemplates.build(goal, student.getId());
        return workoutProgramService.createProgram(instructor, programRequest);
    }

    private User requireStudent(AuthUser student) {
        User user = userRepository.findById(student.getId())
                .orElseThrow(() -> new ApiException("Aluno não encontrado"));
        tenantService.requireActiveAcademy(user);
        if (user.getRole() != UserRole.ALUNO) {
            throw new ApiException("Acesso negado");
        }
        return user;
    }

    private StudentProfileDtos.StudentProfileResponse toProfileResponse(User user, StudentProfile profile) {
        return new StudentProfileDtos.StudentProfileResponse(
                user.getId(),
                user.getName(),
                profile.getHeightCm(),
                profile.getCurrentWeightKg(),
                profile.getGoal(),
                profile.getOnboardingCompletedAt() != null
        );
    }

    private StudentProfileDtos.BodyMeasurementResponse toMeasurementResponse(BodyMeasurement m) {
        return new StudentProfileDtos.BodyMeasurementResponse(
                m.getId(),
                m.getWeightKg(),
                m.getWaistCm(),
                m.getHipsCm(),
                m.getChestCm(),
                ISO.format(m.getRecordedAt()),
                m.getSource().name(),
                m.getNotes()
        );
    }

    private StudentProfileDtos.WeightCheckScheduleResponse toScheduleResponse(WeightCheckSchedule s) {
        return new StudentProfileDtos.WeightCheckScheduleResponse(
                s.getId(),
                s.getStudent().getId(),
                s.getStudent().getName(),
                s.getDueDate(),
                s.isCompleted(),
                !s.isCompleted() && LocalDate.now().isAfter(s.getDueDate())
        );
    }

    private StudentProfileDtos.GoalCheckInResponse toGoalCheckInResponse(GoalCheckIn c) {
        return new StudentProfileDtos.GoalCheckInResponse(
                c.getId(),
                c.isAchievingGoal(),
                c.getProgressRating(),
                c.getComment(),
                ISO.format(c.getCreatedAt())
        );
    }
}
