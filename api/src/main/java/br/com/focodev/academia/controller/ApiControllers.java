package br.com.focodev.academia.controller;

import br.com.focodev.academia.dto.*;
import br.com.focodev.academia.security.AuthUser;
import br.com.focodev.academia.service.AcademiaService;
import br.com.focodev.academia.service.AuthService;
import br.com.focodev.academia.service.CardioService;
import br.com.focodev.academia.service.StudentProfileService;
import br.com.focodev.academia.service.TenantService;
import br.com.focodev.academia.service.WorkoutProgramService;
import jakarta.validation.Valid;
import lombok.RequiredArgsConstructor;
import org.springframework.http.ResponseEntity;
import org.springframework.security.core.annotation.AuthenticationPrincipal;
import org.springframework.web.bind.annotation.*;
import org.springframework.web.multipart.MultipartFile;

import java.io.IOException;
import java.util.List;
import java.util.Map;
import java.util.UUID;

@RestController
@RequestMapping("/api")
@RequiredArgsConstructor
public class ApiControllers {

    private final AuthService authService;
    private final AcademiaService academiaService;
    private final WorkoutProgramService workoutProgramService;
    private final TenantService tenantService;
    private final StudentProfileService studentProfileService;
    private final CardioService cardioService;

    @GetMapping("/health")
    public Map<String, String> health() {
        return Map.of("status", "ok");
    }

    @GetMapping("/tenants/{slug}")
    public TenantPublicResponse tenant(@PathVariable String slug) {
        return TenantPublicResponse.from(tenantService.requireActiveAcademyBySlug(slug));
    }

    @PostMapping("/auth/register")
    public AuthResponse register(@Valid @RequestBody RegisterRequest request) {
        return authService.register(request);
    }

    @PostMapping("/auth/login")
    public AuthResponse login(@Valid @RequestBody LoginRequest request) {
        return authService.login(request);
    }

    @GetMapping("/auth/me")
    public UserResponse me(@AuthenticationPrincipal AuthUser user) {
        return authService.me(user);
    }

    @PostMapping("/auth/heartbeat")
    public ResponseEntity<Void> heartbeat(
            @AuthenticationPrincipal AuthUser user,
            @RequestBody(required = false) HeartbeatRequest request
    ) {
        authService.heartbeat(user, request);
        return ResponseEntity.noContent().build();
    }

    @PostMapping("/instructor/students")
    public UserResponse createStudent(
            @AuthenticationPrincipal AuthUser user,
            @Valid @RequestBody CreateStudentRequest request
    ) {
        return academiaService.createStudent(user, request);
    }

    @GetMapping("/instructor/students")
    public List<UserResponse> listStudents(@AuthenticationPrincipal AuthUser user) {
        return academiaService.listStudents(user);
    }

    @GetMapping("/instructor/dashboard")
    public DashboardResponse dashboard(@AuthenticationPrincipal AuthUser user) {
        return academiaService.dashboard(user);
    }

    @PostMapping("/instructor/programs")
    public WorkoutProgramResponse createProgram(
            @AuthenticationPrincipal AuthUser user,
            @Valid @RequestBody CreateWorkoutProgramRequest request
    ) {
        return workoutProgramService.createProgram(user, request);
    }

    @GetMapping("/instructor/programs")
    public List<WorkoutProgramResponse> listInstructorPrograms(@AuthenticationPrincipal AuthUser user) {
        return workoutProgramService.listInstructorPrograms(user);
    }

    @GetMapping("/instructor/programs/{id}")
    public WorkoutProgramResponse getInstructorProgram(
            @AuthenticationPrincipal AuthUser user,
            @PathVariable UUID id
    ) {
        return workoutProgramService.getProgram(user, id);
    }

    @PostMapping("/instructor/workouts")
    public WorkoutResponse createWorkout(
            @AuthenticationPrincipal AuthUser user,
            @Valid @RequestBody CreateWorkoutRequest request
    ) {
        return academiaService.createWorkout(user, request);
    }

    @GetMapping("/instructor/workouts")
    public List<WorkoutResponse> listInstructorWorkouts(@AuthenticationPrincipal AuthUser user) {
        return academiaService.listInstructorWorkouts(user);
    }

    @GetMapping("/instructor/workouts/{id}")
    public WorkoutResponse getInstructorWorkout(
            @AuthenticationPrincipal AuthUser user,
            @PathVariable UUID id
    ) {
        return academiaService.getWorkout(user, id);
    }

    @GetMapping("/instructor/workouts/{id}/feedbacks")
    public List<FeedbackResponse> workoutFeedbacks(
            @AuthenticationPrincipal AuthUser user,
            @PathVariable UUID id
    ) {
        return academiaService.listWorkoutFeedbacks(user, id);
    }

    @GetMapping("/instructor/session-feedbacks")
    public List<SessionFeedbackResponse> instructorSessionFeedbacks(@AuthenticationPrincipal AuthUser user) {
        return workoutProgramService.listSessionFeedbacksForInstructor(user);
    }

    @GetMapping("/instructor/feedbacks")
    public List<FeedbackResponse> instructorFeedbacks(@AuthenticationPrincipal AuthUser user) {
        return academiaService.listInstructorFeedbacks(user);
    }

    @GetMapping("/instructor/suggestions")
    public List<SuggestionResponse> instructorSuggestions(@AuthenticationPrincipal AuthUser user) {
        return academiaService.listInstructorSuggestions(user);
    }

    @PostMapping("/instructor/suggestions/{id}/respond")
    public SuggestionResponse respondSuggestion(
            @AuthenticationPrincipal AuthUser user,
            @PathVariable UUID id,
            @Valid @RequestBody SuggestionResponseRequest request
    ) {
        return academiaService.respondSuggestion(user, id, request);
    }

    @PostMapping("/instructor/media")
    public Map<String, String> uploadMedia(
            @AuthenticationPrincipal AuthUser user,
            @RequestParam("file") MultipartFile file
    ) throws IOException {
        return Map.of("url", academiaService.uploadMedia(user, file));
    }

    @GetMapping("/student/programs/active")
    public WorkoutProgramResponse getActiveStudentProgram(@AuthenticationPrincipal AuthUser user) {
        return workoutProgramService.getActiveStudentProgram(user);
    }

    @GetMapping("/student/programs/{id}")
    public WorkoutProgramResponse getStudentProgram(
            @AuthenticationPrincipal AuthUser user,
            @PathVariable UUID id
    ) {
        return workoutProgramService.getProgram(user, id);
    }

    @GetMapping("/student/days/{dayId}")
    public WorkoutDayResponse getStudentDay(
            @AuthenticationPrincipal AuthUser user,
            @PathVariable UUID dayId
    ) {
        return workoutProgramService.getStudentDay(user, dayId);
    }

    @PostMapping("/student/days/{dayId}/sessions")
    public WorkoutSessionResponse startSession(
            @AuthenticationPrincipal AuthUser user,
            @PathVariable UUID dayId
    ) {
        return workoutProgramService.startOrResumeSession(user, dayId);
    }

    @PostMapping("/student/sessions/{sessionId}/sets")
    public WorkoutSessionResponse toggleSet(
            @AuthenticationPrincipal AuthUser user,
            @PathVariable UUID sessionId,
            @Valid @RequestBody LogSetRequest request
    ) {
        return workoutProgramService.toggleSet(user, sessionId, request);
    }

    @PostMapping("/student/sessions/{sessionId}/complete")
    public SessionCompleteResponse completeSession(
            @AuthenticationPrincipal AuthUser user,
            @PathVariable UUID sessionId,
            @Valid @RequestBody CompleteSessionRequest request
    ) {
        return workoutProgramService.completeSession(user, sessionId, request);
    }

    @GetMapping("/student/stats")
    public StudentStatsResponse getStudentStats(@AuthenticationPrincipal AuthUser user) {
        return workoutProgramService.getStudentStats(user);
    }

    @GetMapping("/student/workouts")
    public List<WorkoutResponse> listStudentWorkouts(@AuthenticationPrincipal AuthUser user) {
        return academiaService.listStudentWorkouts(user);
    }

    @GetMapping("/student/workouts/{id}")
    public WorkoutResponse getStudentWorkout(
            @AuthenticationPrincipal AuthUser user,
            @PathVariable UUID id
    ) {
        return academiaService.getWorkout(user, id);
    }

    @PostMapping("/student/workouts/{id}/feedback")
    public FeedbackResponse submitFeedback(
            @AuthenticationPrincipal AuthUser user,
            @PathVariable UUID id,
            @Valid @RequestBody FeedbackRequest request
    ) {
        return academiaService.submitFeedback(user, id, request);
    }

    @PostMapping("/student/suggestions")
    public SuggestionResponse createSuggestion(
            @AuthenticationPrincipal AuthUser user,
            @Valid @RequestBody SuggestionRequest request
    ) {
        return academiaService.createSuggestion(user, request);
    }

    @GetMapping("/student/suggestions")
    public List<SuggestionResponse> studentSuggestions(@AuthenticationPrincipal AuthUser user) {
        return academiaService.listStudentSuggestions(user);
    }

    @GetMapping("/student/profile/status")
    public StudentProfileDtos.ProfileStatusResponse profileStatus(@AuthenticationPrincipal AuthUser user) {
        return studentProfileService.getProfileStatus(user);
    }

    @GetMapping("/student/profile")
    public StudentProfileDtos.StudentProfileResponse studentProfile(@AuthenticationPrincipal AuthUser user) {
        return studentProfileService.getProfile(user);
    }

    @PostMapping("/student/profile/onboarding")
    public StudentProfileDtos.StudentProfileResponse completeOnboarding(
            @AuthenticationPrincipal AuthUser user,
            @Valid @RequestBody StudentProfileDtos.OnboardingRequest request
    ) {
        return studentProfileService.completeOnboarding(user, request);
    }

    @PostMapping("/student/measurements")
    public StudentProfileDtos.BodyMeasurementResponse addMeasurement(
            @AuthenticationPrincipal AuthUser user,
            @Valid @RequestBody StudentProfileDtos.BodyMeasurementRequest request
    ) {
        return studentProfileService.addMeasurement(user, request);
    }

    @GetMapping("/student/measurements")
    public List<StudentProfileDtos.BodyMeasurementResponse> listMeasurements(@AuthenticationPrincipal AuthUser user) {
        return studentProfileService.listMeasurements(user);
    }

    @PostMapping("/student/goal-checkins")
    public StudentProfileDtos.GoalCheckInResponse submitGoalCheckIn(
            @AuthenticationPrincipal AuthUser user,
            @Valid @RequestBody StudentProfileDtos.GoalCheckInRequest request
    ) {
        return studentProfileService.submitGoalCheckIn(user, request);
    }

    @GetMapping("/student/cardio-workouts/active")
    public CardioDtos.CardioWorkoutResponse activeCardioWorkout(@AuthenticationPrincipal AuthUser user) {
        return cardioService.getActiveStudentWorkout(user);
    }

    @PostMapping("/student/cardio-sessions/start")
    public CardioDtos.CardioSessionResponse startCardioSession(
            @AuthenticationPrincipal AuthUser user,
            @Valid @RequestBody CardioDtos.StartCardioSessionRequest request
    ) {
        return cardioService.startSession(user, request);
    }

    @PostMapping("/student/cardio-sessions/{sessionId}/points")
    public CardioDtos.CardioSessionResponse addCardioPoints(
            @AuthenticationPrincipal AuthUser user,
            @PathVariable UUID sessionId,
            @Valid @RequestBody CardioDtos.AddRoutePointsRequest request
    ) {
        return cardioService.addRoutePoints(user, sessionId, request);
    }

    @PostMapping("/student/cardio-sessions/{sessionId}/complete")
    public CardioDtos.CardioSessionResponse completeCardioSession(
            @AuthenticationPrincipal AuthUser user,
            @PathVariable UUID sessionId,
            @Valid @RequestBody CardioDtos.CompleteCardioSessionRequest request
    ) {
        return cardioService.completeSession(user, sessionId, request);
    }

    @GetMapping("/student/cardio-sessions")
    public List<CardioDtos.CardioSessionResponse> listStudentCardioSessions(@AuthenticationPrincipal AuthUser user) {
        return cardioService.listStudentSessions(user);
    }

    @PostMapping("/student/sync")
    public CardioDtos.StudentSyncResponse syncStudentData(
            @AuthenticationPrincipal AuthUser user,
            @Valid @RequestBody CardioDtos.StudentSyncRequest request
    ) {
        return cardioService.sync(user, request);
    }

    @GetMapping("/instructor/students/{studentId}/profile")
    public StudentProfileDtos.StudentProfileResponse instructorStudentProfile(
            @AuthenticationPrincipal AuthUser user,
            @PathVariable UUID studentId
    ) {
        return studentProfileService.getStudentProfile(user, studentId);
    }

    @PostMapping("/instructor/students/{studentId}/weight-schedule")
    public StudentProfileDtos.WeightCheckScheduleResponse scheduleWeightCheck(
            @AuthenticationPrincipal AuthUser user,
            @PathVariable UUID studentId,
            @Valid @RequestBody StudentProfileDtos.WeightCheckScheduleRequest request
    ) {
        return studentProfileService.scheduleWeightCheck(user, studentId, request);
    }

    @GetMapping("/instructor/students/{studentId}/goal-checkins")
    public List<StudentProfileDtos.GoalCheckInResponse> listGoalCheckIns(
            @AuthenticationPrincipal AuthUser user,
            @PathVariable UUID studentId
    ) {
        return studentProfileService.listGoalCheckIns(user, studentId);
    }

    @PostMapping("/instructor/programs/quick")
    public WorkoutProgramResponse createQuickProgram(
            @AuthenticationPrincipal AuthUser user,
            @Valid @RequestBody StudentProfileDtos.QuickProgramRequest request
    ) {
        return studentProfileService.createQuickProgram(user, request);
    }

    @PostMapping("/instructor/cardio-workouts")
    public CardioDtos.CardioWorkoutResponse createCardioWorkout(
            @AuthenticationPrincipal AuthUser user,
            @Valid @RequestBody CardioDtos.CreateCardioWorkoutRequest request
    ) {
        return cardioService.createWorkout(user, request);
    }

    @GetMapping("/instructor/cardio-workouts")
    public List<CardioDtos.CardioWorkoutResponse> listInstructorCardioWorkouts(@AuthenticationPrincipal AuthUser user) {
        return cardioService.listInstructorWorkouts(user);
    }

    @GetMapping("/instructor/cardio-sessions")
    public List<CardioDtos.CardioSessionResponse> listInstructorCardioSessions(@AuthenticationPrincipal AuthUser user) {
        return cardioService.listInstructorSessions(user);
    }

    @GetMapping("/instructor/cardio-stats")
    public CardioDtos.InstructorCardioStatsResponse instructorCardioStats(@AuthenticationPrincipal AuthUser user) {
        return cardioService.instructorStats(user);
    }
}
