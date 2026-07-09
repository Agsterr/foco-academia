package br.com.focodev.academia.service;

import br.com.focodev.academia.domain.*;
import br.com.focodev.academia.dto.*;
import br.com.focodev.academia.exception.ApiException;
import br.com.focodev.academia.repository.*;
import br.com.focodev.academia.security.AuthUser;
import lombok.RequiredArgsConstructor;
import org.springframework.security.crypto.password.PasswordEncoder;
import org.springframework.stereotype.Service;
import org.springframework.transaction.annotation.Transactional;
import org.springframework.web.multipart.MultipartFile;

import java.io.IOException;
import java.time.Instant;
import java.util.List;
import java.util.UUID;

@Service
@RequiredArgsConstructor
public class AcademiaService {

    private final UserRepository userRepository;
    private final WorkoutRepository workoutRepository;
    private final WorkoutFeedbackRepository feedbackRepository;
    private final SuggestionRepository suggestionRepository;
    private final PasswordEncoder passwordEncoder;
    private final TenantService tenantService;
    private final MediaStorageService mediaStorageService;

    @Transactional
    public UserResponse createStudent(AuthUser instructor, CreateStudentRequest request) {
        User instructorUser = tenantService.requireInstructor(instructor);
        if (userRepository.existsByEmailIgnoreCase(request.email())) {
            throw new ApiException("E-mail já cadastrado");
        }

        User student = new User();
        student.setEmail(request.email().trim().toLowerCase());
        student.setPasswordHash(passwordEncoder.encode(request.password()));
        student.setName(request.name().trim());
        student.setPhone(request.phone());
        student.setRole(UserRole.ALUNO);
        student.setInstructor(instructorUser);
        student.setAcademy(instructorUser.getAcademy());
        userRepository.save(student);
        return UserResponse.from(student);
    }

    @Transactional(readOnly = true)
    public List<UserResponse> listStudents(AuthUser instructor) {
        tenantService.requireInstructor(instructor);
        return userRepository.findByInstructorIdAndRoleAndActiveTrueOrderByNameAsc(instructor.getId(), UserRole.ALUNO)
                .stream().map(UserResponse::from).toList();
    }

    @Transactional(readOnly = true)
    public DashboardResponse dashboard(AuthUser instructor) {
        tenantService.requireInstructor(instructor);
        long students = userRepository.findByInstructorIdAndRoleAndActiveTrueOrderByNameAsc(instructor.getId(), UserRole.ALUNO).size();
        long activeWorkouts = workoutRepository.findByInstructorIdOrderByCreatedAtDesc(instructor.getId()).stream()
                .filter(w -> w.getStatus() == WorkoutStatus.ATIVO).count();
        long pending = suggestionRepository.countByInstructorIdAndStatus(instructor.getId(), SuggestionStatus.PENDENTE);
        return new DashboardResponse(students, activeWorkouts, pending);
    }

    @Transactional
    public WorkoutResponse createWorkout(AuthUser instructor, CreateWorkoutRequest request) {
        User instructorUser = tenantService.requireInstructor(instructor);
        User student = userRepository.findById(request.studentId())
                .orElseThrow(() -> new ApiException("Aluno não encontrado"));

        tenantService.requireStudentInInstructorAcademy(instructorUser, student);

        Workout workout = new Workout();
        workout.setTitle(request.title().trim());
        workout.setDescription(request.description());
        workout.setInstructor(instructorUser);
        workout.setStudent(student);
        workout.setScheduledDate(request.scheduledDate());
        if (request.status() != null) {
            workout.setStatus(request.status());
        }

        if (request.exercises() != null) {
            for (ExerciseRequest exerciseRequest : request.exercises()) {
                Exercise exercise = new Exercise();
                exercise.setWorkout(workout);
                exercise.setName(exerciseRequest.name().trim());
                exercise.setDescription(exerciseRequest.description());
                exercise.setSets(exerciseRequest.sets());
                exercise.setReps(exerciseRequest.reps());
                exercise.setDuration(exerciseRequest.duration());
                exercise.setVideoUrl(exerciseRequest.videoUrl());
                exercise.setMediaType(exerciseRequest.mediaType() != null ? exerciseRequest.mediaType() : MediaType.NONE);
                exercise.setVariationNotes(exerciseRequest.variationNotes());
                exercise.setNotes(exerciseRequest.notes());
                exercise.setSortOrder(exerciseRequest.sortOrder());
                workout.getExercises().add(exercise);
            }
        }

        return WorkoutResponse.from(workoutRepository.save(workout));
    }

    @Transactional(readOnly = true)
    public List<WorkoutResponse> listInstructorWorkouts(AuthUser instructor) {
        tenantService.requireInstructor(instructor);
        return workoutRepository.findByInstructorIdWithDetails(instructor.getId())
                .stream().map(WorkoutResponse::from).toList();
    }

    @Transactional(readOnly = true)
    public List<WorkoutResponse> listStudentWorkouts(AuthUser student) {
        tenantService.requireActiveAcademy(userRepository.findById(student.getId())
                .orElseThrow(() -> new ApiException("Aluno não encontrado")));
        return workoutRepository.findByStudentIdWithExercises(student.getId())
                .stream().map(WorkoutResponse::from).toList();
    }

    @Transactional(readOnly = true)
    public WorkoutResponse getWorkout(AuthUser user, UUID workoutId) {
        Workout workout = workoutRepository.findByIdWithExercises(workoutId)
                .orElseThrow(() -> new ApiException("Treino não encontrado"));

        if (user.getRole() == UserRole.ALUNO && !workout.getStudent().getId().equals(user.getId())) {
            throw new ApiException("Acesso negado");
        }
        if (user.getRole() == UserRole.INSTRUTOR && !workout.getInstructor().getId().equals(user.getId())) {
            throw new ApiException("Acesso negado");
        }

        return WorkoutResponse.from(workout);
    }

    @Transactional
    public FeedbackResponse submitFeedback(AuthUser student, UUID workoutId, FeedbackRequest request) {
        User studentUser = userRepository.findById(student.getId())
                .orElseThrow(() -> new ApiException("Aluno não encontrado"));
        tenantService.requireActiveAcademy(studentUser);

        Workout workout = workoutRepository.findById(workoutId)
                .orElseThrow(() -> new ApiException("Treino não encontrado"));

        if (!workout.getStudent().getId().equals(student.getId())) {
            throw new ApiException("Treino não pertence a este aluno");
        }

        WorkoutFeedback feedback = feedbackRepository.findByWorkoutIdAndStudentId(workoutId, student.getId())
                .orElseGet(WorkoutFeedback::new);
        feedback.setWorkout(workout);
        feedback.setStudent(studentUser);
        feedback.setRating(request.rating());
        feedback.setCompleted(request.completed());
        feedback.setComment(request.comment());

        if (request.completed()) {
            workout.setStatus(WorkoutStatus.CONCLUIDO);
        }

        return FeedbackResponse.from(feedbackRepository.save(feedback));
    }

    @Transactional(readOnly = true)
    public List<FeedbackResponse> listWorkoutFeedbacks(AuthUser instructor, UUID workoutId) {
        tenantService.requireInstructor(instructor);
        Workout workout = workoutRepository.findById(workoutId)
                .orElseThrow(() -> new ApiException("Treino não encontrado"));
        if (!workout.getInstructor().getId().equals(instructor.getId())) {
            throw new ApiException("Acesso negado");
        }
        return feedbackRepository.findByWorkoutIdOrderByCreatedAtDesc(workoutId)
                .stream().map(FeedbackResponse::from).toList();
    }

    @Transactional(readOnly = true)
    public List<FeedbackResponse> listInstructorFeedbacks(AuthUser instructor) {
        tenantService.requireInstructor(instructor);
        return feedbackRepository.findByWorkoutInstructorIdOrderByCreatedAtDesc(instructor.getId())
                .stream().map(FeedbackResponse::from).toList();
    }

    @Transactional
    public SuggestionResponse createSuggestion(AuthUser student, SuggestionRequest request) {
        User studentUser = userRepository.findById(student.getId())
                .orElseThrow(() -> new ApiException("Aluno não encontrado"));
        tenantService.requireActiveAcademy(studentUser);

        Suggestion suggestion = new Suggestion();
        suggestion.setStudent(studentUser);
        suggestion.setInstructor(studentUser.getInstructor());
        suggestion.setMessage(request.message().trim());
        suggestion.setCategory(request.category());
        return SuggestionResponse.from(suggestionRepository.save(suggestion));
    }

    @Transactional(readOnly = true)
    public List<SuggestionResponse> listStudentSuggestions(AuthUser student) {
        return suggestionRepository.findByStudentIdOrderByCreatedAtDesc(student.getId())
                .stream().map(SuggestionResponse::from).toList();
    }

    @Transactional(readOnly = true)
    public List<SuggestionResponse> listInstructorSuggestions(AuthUser instructor) {
        tenantService.requireInstructor(instructor);
        return suggestionRepository.findByInstructorIdOrderByCreatedAtDesc(instructor.getId())
                .stream().map(SuggestionResponse::from).toList();
    }

    @Transactional
    public SuggestionResponse respondSuggestion(AuthUser instructor, UUID suggestionId, SuggestionResponseRequest request) {
        tenantService.requireInstructor(instructor);
        Suggestion suggestion = suggestionRepository.findById(suggestionId)
                .orElseThrow(() -> new ApiException("Sugestão não encontrada"));

        if (suggestion.getInstructor() == null || !suggestion.getInstructor().getId().equals(instructor.getId())) {
            throw new ApiException("Acesso negado");
        }

        suggestion.setResponse(request.response().trim());
        suggestion.setStatus(SuggestionStatus.RESPONDIDA);
        suggestion.setRespondedAt(Instant.now());
        return SuggestionResponse.from(suggestionRepository.save(suggestion));
    }

    public String uploadMedia(AuthUser instructor, MultipartFile file) throws IOException {
        tenantService.requireInstructor(instructor);
        if (file.isEmpty()) {
            throw new ApiException("Arquivo vazio");
        }

        return mediaStorageService.store(file);
    }
}
