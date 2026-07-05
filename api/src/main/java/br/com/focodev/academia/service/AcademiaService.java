package br.com.focodev.academia.service;

import br.com.focodev.academia.domain.*;
import br.com.focodev.academia.dto.*;
import br.com.focodev.academia.exception.ApiException;
import br.com.focodev.academia.repository.*;
import br.com.focodev.academia.security.AuthUser;
import lombok.RequiredArgsConstructor;
import org.springframework.beans.factory.annotation.Value;
import org.springframework.security.crypto.password.PasswordEncoder;
import org.springframework.stereotype.Service;
import org.springframework.transaction.annotation.Transactional;
import org.springframework.web.multipart.MultipartFile;

import java.io.IOException;
import java.nio.file.Files;
import java.nio.file.Path;
import java.nio.file.Paths;
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

    @Value("${app.upload.dir}")
    private String uploadDir;

    @Transactional
    public UserResponse createStudent(AuthUser instructor, CreateStudentRequest request) {
        if (userRepository.existsByEmailIgnoreCase(request.email())) {
            throw new ApiException("E-mail já cadastrado");
        }

        User instructorUser = getInstructor(instructor);
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

    public List<UserResponse> listStudents(AuthUser instructor) {
        return userRepository.findByInstructorIdAndRoleAndActiveTrueOrderByNameAsc(instructor.getId(), UserRole.ALUNO)
                .stream().map(UserResponse::from).toList();
    }

    public DashboardResponse dashboard(AuthUser instructor) {
        long students = userRepository.findByInstructorIdAndRoleAndActiveTrueOrderByNameAsc(instructor.getId(), UserRole.ALUNO).size();
        long activeWorkouts = workoutRepository.findByInstructorIdOrderByCreatedAtDesc(instructor.getId()).stream()
                .filter(w -> w.getStatus() == WorkoutStatus.ATIVO).count();
        long pending = suggestionRepository.countByInstructorIdAndStatus(instructor.getId(), SuggestionStatus.PENDENTE);
        return new DashboardResponse(students, activeWorkouts, pending);
    }

    @Transactional
    public WorkoutResponse createWorkout(AuthUser instructor, CreateWorkoutRequest request) {
        User instructorUser = getInstructor(instructor);
        User student = userRepository.findById(request.studentId())
                .orElseThrow(() -> new ApiException("Aluno não encontrado"));

        if (student.getRole() != UserRole.ALUNO) {
            throw new ApiException("Usuário não é aluno");
        }
        if (student.getInstructor() == null || !student.getInstructor().getId().equals(instructor.getId())) {
            throw new ApiException("Aluno não pertence a este instrutor");
        }

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
                exercise.setNotes(exerciseRequest.notes());
                exercise.setSortOrder(exerciseRequest.sortOrder());
                workout.getExercises().add(exercise);
            }
        }

        return WorkoutResponse.from(workoutRepository.save(workout));
    }

    public List<WorkoutResponse> listInstructorWorkouts(AuthUser instructor) {
        return workoutRepository.findByInstructorIdOrderByCreatedAtDesc(instructor.getId())
                .stream().map(WorkoutResponse::from).toList();
    }

    public List<WorkoutResponse> listStudentWorkouts(AuthUser student) {
        return workoutRepository.findByStudentIdWithExercises(student.getId())
                .stream().map(WorkoutResponse::from).toList();
    }

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
        Workout workout = workoutRepository.findById(workoutId)
                .orElseThrow(() -> new ApiException("Treino não encontrado"));

        if (!workout.getStudent().getId().equals(student.getId())) {
            throw new ApiException("Treino não pertence a este aluno");
        }

        User studentUser = userRepository.findById(student.getId())
                .orElseThrow(() -> new ApiException("Aluno não encontrado"));

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

    public List<FeedbackResponse> listWorkoutFeedbacks(AuthUser instructor, UUID workoutId) {
        Workout workout = workoutRepository.findById(workoutId)
                .orElseThrow(() -> new ApiException("Treino não encontrado"));
        if (!workout.getInstructor().getId().equals(instructor.getId())) {
            throw new ApiException("Acesso negado");
        }
        return feedbackRepository.findByWorkoutIdOrderByCreatedAtDesc(workoutId)
                .stream().map(FeedbackResponse::from).toList();
    }

    public List<FeedbackResponse> listInstructorFeedbacks(AuthUser instructor) {
        return feedbackRepository.findByWorkoutInstructorIdOrderByCreatedAtDesc(instructor.getId())
                .stream().map(FeedbackResponse::from).toList();
    }

    @Transactional
    public SuggestionResponse createSuggestion(AuthUser student, SuggestionRequest request) {
        User studentUser = userRepository.findById(student.getId())
                .orElseThrow(() -> new ApiException("Aluno não encontrado"));

        Suggestion suggestion = new Suggestion();
        suggestion.setStudent(studentUser);
        suggestion.setInstructor(studentUser.getInstructor());
        suggestion.setMessage(request.message().trim());
        suggestion.setCategory(request.category());
        return SuggestionResponse.from(suggestionRepository.save(suggestion));
    }

    public List<SuggestionResponse> listStudentSuggestions(AuthUser student) {
        return suggestionRepository.findByStudentIdOrderByCreatedAtDesc(student.getId())
                .stream().map(SuggestionResponse::from).toList();
    }

    public List<SuggestionResponse> listInstructorSuggestions(AuthUser instructor) {
        return suggestionRepository.findByInstructorIdOrderByCreatedAtDesc(instructor.getId())
                .stream().map(SuggestionResponse::from).toList();
    }

    @Transactional
    public SuggestionResponse respondSuggestion(AuthUser instructor, UUID suggestionId, SuggestionResponseRequest request) {
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

    public String uploadMedia(MultipartFile file) throws IOException {
        if (file.isEmpty()) {
            throw new ApiException("Arquivo vazio");
        }

        String original = file.getOriginalFilename() != null ? file.getOriginalFilename() : "file";
        String extension = "";
        int dot = original.lastIndexOf('.');
        if (dot > 0) {
            extension = original.substring(dot);
        }

        String filename = UUID.randomUUID() + extension;
        Path directory = Paths.get(uploadDir).toAbsolutePath().normalize();
        Files.createDirectories(directory);
        Files.copy(file.getInputStream(), directory.resolve(filename));
        return "/api/media/" + filename;
    }

    private User getInstructor(AuthUser instructor) {
        return userRepository.findById(instructor.getId())
                .orElseThrow(() -> new ApiException("Instrutor não encontrado"));
    }
}
