package br.com.focodev.academia.service;

import br.com.focodev.academia.domain.*;
import br.com.focodev.academia.dto.CardioDtos;
import br.com.focodev.academia.dto.GpsAnalyticsDtos;
import br.com.focodev.academia.dto.StudentProfileDtos;
import br.com.focodev.academia.exception.ApiException;
import br.com.focodev.academia.repository.*;
import br.com.focodev.academia.security.AuthUser;
import com.fasterxml.jackson.core.JsonProcessingException;
import com.fasterxml.jackson.databind.ObjectMapper;
import lombok.RequiredArgsConstructor;
import org.springframework.stereotype.Service;
import org.springframework.transaction.annotation.Transactional;

import java.time.Instant;
import java.time.LocalDate;
import java.time.ZoneId;
import java.time.format.DateTimeFormatter;
import java.time.temporal.TemporalAdjusters;
import java.util.ArrayList;
import java.util.List;
import java.util.UUID;

@Service
@RequiredArgsConstructor
public class CardioService {

    private static final DateTimeFormatter ISO = DateTimeFormatter.ISO_INSTANT;
    private static final ZoneId ZONE = ZoneId.of("America/Sao_Paulo");

    private final CardioWorkoutRepository workoutRepository;
    private final CardioSessionRepository sessionRepository;
    private final BodyMeasurementRepository measurementRepository;
    private final WeightCheckScheduleRepository scheduleRepository;
    private final UserRepository userRepository;
    private final TenantService tenantService;
    private final ObjectMapper objectMapper;
    private final StudentProfileRepository profileRepository;
    private final CalorieEstimationService calorieEstimationService;
    private final GpsDiagnosticRepository gpsDiagnosticRepository;

    @Transactional
    public CardioDtos.CardioWorkoutResponse createWorkout(AuthUser instructor, CardioDtos.CreateCardioWorkoutRequest request) {
        User instructorUser = tenantService.requireInstructor(instructor);
        User student = userRepository.findById(request.studentId())
                .orElseThrow(() -> new ApiException("Aluno não encontrado"));
        tenantService.requireStudentInInstructorAcademy(instructorUser, student);

        workoutRepository.findByStudentIdAndActiveTrueOrderByCreatedAtDesc(student.getId())
                .forEach(w -> {
                    w.setActive(false);
                    workoutRepository.save(w);
                });

        CardioWorkout workout = new CardioWorkout();
        workout.setInstructor(instructorUser);
        workout.setStudent(student);
        workout.setTitle(request.title().trim());
        workout.setType(request.type());
        if (request.intervals() != null && !request.intervals().isEmpty()) {
            try {
                workout.setIntervalsJson(objectMapper.writeValueAsString(request.intervals()));
            } catch (JsonProcessingException e) {
                throw new ApiException("Intervalos inválidos");
            }
        }
        return toWorkoutResponse(workoutRepository.save(workout));
    }

    @Transactional
    public CardioDtos.CardioWorkoutResponse updateWorkout(
            AuthUser instructor,
            UUID workoutId,
            CardioDtos.UpdateCardioWorkoutRequest request
    ) {
        CardioWorkout workout = requireInstructorWorkout(instructor, workoutId);
        workout.setTitle(request.title().trim());
        workout.setType(request.type());
        if (request.intervals() != null) {
            try {
                workout.setIntervalsJson(
                        request.intervals().isEmpty()
                                ? null
                                : objectMapper.writeValueAsString(request.intervals())
                );
            } catch (JsonProcessingException e) {
                throw new ApiException("Intervalos inválidos");
            }
        }
        if (request.active() != null) {
            if (Boolean.TRUE.equals(request.active())) {
                deactivateOtherActiveWorkouts(workout.getStudent().getId(), workout.getId());
                workout.setActive(true);
            } else {
                workout.setActive(false);
            }
        }
        return toWorkoutResponse(workoutRepository.save(workout));
    }

    @Transactional
    public void deleteWorkout(AuthUser instructor, UUID workoutId) {
        CardioWorkout workout = requireInstructorWorkout(instructor, workoutId);
        // Mantém histórico das sessões; apenas desvincula o treino prescrito.
        for (CardioSession session : sessionRepository.findByWorkoutId(workoutId)) {
            session.setWorkout(null);
            sessionRepository.save(session);
        }
        workoutRepository.delete(workout);
    }

    @Transactional(readOnly = true)
    public List<CardioDtos.CardioWorkoutResponse> listInstructorWorkouts(AuthUser instructor) {
        tenantService.requireInstructor(instructor);
        return workoutRepository.findByInstructorIdOrderByCreatedAtDesc(instructor.getId()).stream()
                .map(this::toWorkoutResponse)
                .toList();
    }

    @Transactional(readOnly = true)
    public CardioDtos.CardioWorkoutResponse getActiveStudentWorkout(AuthUser student) {
        User user = requireStudent(student);
        CardioWorkout workout = workoutRepository.findFirstByStudentIdAndActiveTrueOrderByCreatedAtDesc(user.getId())
                .orElseThrow(() -> new ApiException("Nenhum treino outdoor ativo"));
        return toWorkoutResponse(workout);
    }

    @Transactional
    public CardioDtos.CardioSessionResponse startSession(AuthUser student, CardioDtos.StartCardioSessionRequest request) {
        User user = requireStudent(student);
        sessionRepository.findByStudentIdAndCompletedAtIsNull(user.getId())
                .ifPresent(s -> {
                    throw new ApiException("Já existe uma sessão em andamento");
                });

        CardioWorkout workout = null;
        if (request.workoutId() != null) {
            workout = workoutRepository.findById(request.workoutId())
                    .orElseThrow(() -> new ApiException("Treino não encontrado"));
            if (!workout.getStudent().getId().equals(user.getId())) {
                throw new ApiException("Acesso negado");
            }
        }

        CardioSession session = new CardioSession();
        session.setStudent(user);
        session.setWorkout(workout);
        session.setClientSessionId(request.clientSessionId());
        session.setStartedAt(Instant.now());
        return toSessionResponse(sessionRepository.save(session));
    }

    @Transactional
    public CardioDtos.CardioSessionResponse addRoutePoints(
            AuthUser student,
            UUID sessionId,
            CardioDtos.AddRoutePointsRequest request
    ) {
        CardioSession session = requireStudentSession(student, sessionId);
        for (CardioDtos.RoutePointRequest point : request.points()) {
            session.getRoutePoints().add(toRoutePoint(session, point));
        }
        return toSessionResponse(sessionRepository.save(session));
    }

    @Transactional
    public CardioDtos.CardioSessionResponse completeSession(
            AuthUser student,
            UUID sessionId,
            CardioDtos.CompleteCardioSessionRequest request
    ) {
        CardioSession session = requireStudentSession(student, sessionId);
        session.setCompletedAt(Instant.now());
        session.setDistanceMeters(request.distanceMeters());
        session.setAvgSpeedKmh(request.avgSpeedKmh());
        session.setElapsedMs(request.elapsedMs());
        session.setPausedMs(request.pausedMs() != null ? request.pausedMs() : 0L);
        session.setPauseCount(request.pauseCount() != null ? request.pauseCount() : 0);
        session.setCaloriesKcal(resolveCardioCalories(student.getId(), request.distanceMeters(),
                request.avgSpeedKmh(), request.elapsedMs(), request.pausedMs(), request.caloriesKcal()));
        session.setGpsQualityScore(request.gpsQualityScore());
        session.setGpsQualityLabel(request.gpsQualityLabel());
        session.setGpsAlgorithmVersion(request.gpsAlgorithmVersion());
        session.setFilterVersion(request.filterVersion());
        session.setKalmanVersion(request.kalmanVersion());
        session.setDistanceVersion(request.distanceVersion());
        session.setCaloriesVersion(request.caloriesVersion());
        session.setGpsConfigSnapshot(request.gpsConfigSnapshot());
        if (request.points() != null && !request.points().isEmpty()) {
            session.getRoutePoints().clear();
            for (CardioDtos.RoutePointRequest point : request.points()) {
                session.getRoutePoints().add(toRoutePoint(session, point));
            }
        }
        return toSessionResponse(sessionRepository.save(session));
    }

    @Transactional(readOnly = true)
    public List<CardioDtos.CardioSessionResponse> listStudentSessions(AuthUser student) {
        User user = requireStudent(student);
        return sessionRepository.findByStudentIdOrderByStartedAtDesc(user.getId()).stream()
                .map(this::toSessionResponse)
                .toList();
    }

    @Transactional(readOnly = true)
    public List<CardioDtos.CardioSessionResponse> listInstructorSessions(AuthUser instructor) {
        tenantService.requireInstructor(instructor);
        return sessionRepository.findByInstructorStudents(instructor.getId()).stream()
                .map(this::toSessionResponse)
                .toList();
    }

    @Transactional(readOnly = true)
    public CardioDtos.InstructorCardioStatsResponse instructorStats(AuthUser instructor) {
        User instructorUser = tenantService.requireInstructor(instructor);
        Instant weekStart = LocalDate.now(ZONE).with(TemporalAdjusters.previousOrSame(java.time.DayOfWeek.MONDAY))
                .atStartOfDay(ZONE).toInstant();

        List<CardioSession> sessions = sessionRepository.findByInstructorStudents(instructorUser.getId()).stream()
                .filter(s -> s.getCompletedAt() != null && s.getCompletedAt().isAfter(weekStart))
                .toList();

        double totalKm = sessions.stream()
                .mapToDouble(s -> s.getDistanceMeters() != null ? s.getDistanceMeters() / 1000.0 : 0)
                .sum();
        double avgSpeed = sessions.stream()
                .filter(s -> s.getAvgSpeedKmh() != null)
                .mapToDouble(CardioSession::getAvgSpeedKmh)
                .average()
                .orElse(0);

        List<StudentProfileDtos.WeightCheckScheduleResponse> overdue = new ArrayList<>();
        for (User student : userRepository.findByInstructorIdAndRoleAndActiveTrueOrderByNameAsc(
                instructorUser.getId(), UserRole.ALUNO)) {
            scheduleRepository.findFirstByStudentIdAndCompletedFalseOrderByDueDateAsc(student.getId())
                    .filter(s -> LocalDate.now().isAfter(s.getDueDate()))
                    .ifPresent(s -> overdue.add(new StudentProfileDtos.WeightCheckScheduleResponse(
                            s.getId(), s.getStudent().getId(), s.getStudent().getName(),
                            s.getDueDate(), s.isCompleted(), true
                    )));
        }

        List<CardioDtos.CardioSessionResponse> recent = sessionRepository
                .findByInstructorStudents(instructorUser.getId()).stream()
                .limit(10)
                .map(this::toSessionResponse)
                .toList();

        return new CardioDtos.InstructorCardioStatsResponse(
                sessions.size(), totalKm, avgSpeed, recent, overdue
        );
    }

    @Transactional
    public CardioDtos.StudentSyncResponse sync(AuthUser student, CardioDtos.StudentSyncRequest request) {
        User user = requireStudent(student);
        int measurementsSynced = 0;
        int sessionsSynced = 0;

        if (request.measurements() != null) {
            for (CardioDtos.SyncMeasurementDto m : request.measurements()) {
                BodyMeasurement bm = new BodyMeasurement();
                bm.setStudent(user);
                bm.setWeightKg(m.weightKg());
                bm.setWaistCm(m.waistCm());
                bm.setRecordedAt(parseInstant(m.recordedAt()));
                bm.setSource(MeasurementSource.STUDENT);
                measurementRepository.save(bm);
                measurementsSynced++;
            }
        }

        if (request.cardioSessions() != null) {
            for (CardioDtos.SyncCardioSessionDto dto : request.cardioSessions()) {
                CardioSession session = sessionRepository.findByClientSessionId(dto.clientSessionId())
                        .orElseGet(CardioSession::new);
                session.setStudent(user);
                session.setClientSessionId(dto.clientSessionId());
                session.setStartedAt(parseInstant(dto.startedAt()));
                session.setCompletedAt(dto.completedAt() != null ? parseInstant(dto.completedAt()) : null);
                session.setDistanceMeters(dto.distanceMeters());
                session.setAvgSpeedKmh(dto.avgSpeedKmh());
                session.setElapsedMs(dto.elapsedMs());
                session.setPausedMs(dto.pausedMs() != null ? dto.pausedMs() : 0L);
                session.setPauseCount(dto.pauseCount() != null ? dto.pauseCount() : 0);
                session.setCaloriesKcal(resolveCardioCalories(user.getId(), dto.distanceMeters(),
                        dto.avgSpeedKmh(), dto.elapsedMs(), dto.pausedMs(), dto.caloriesKcal()));
                session.setGpsQualityScore(dto.gpsQualityScore());
                session.setGpsQualityLabel(dto.gpsQualityLabel());
                session.setGpsAlgorithmVersion(dto.gpsAlgorithmVersion());
                session.setFilterVersion(dto.filterVersion());
                session.setKalmanVersion(dto.kalmanVersion());
                session.setDistanceVersion(dto.distanceVersion());
                session.setCaloriesVersion(dto.caloriesVersion());
                session.setGpsConfigSnapshot(dto.gpsConfigSnapshot());
                session.setSynced(true);
                if (dto.workoutId() != null) {
                    workoutRepository.findById(dto.workoutId()).ifPresent(session::setWorkout);
                }
                session.getRoutePoints().clear();
                if (dto.points() != null) {
                    for (CardioDtos.RoutePointRequest point : dto.points()) {
                        session.getRoutePoints().add(toRoutePoint(session, point));
                    }
                }
                sessionRepository.save(session);
                sessionsSynced++;
            }
        }

        if (request.diagnostics() != null) {
            for (GpsAnalyticsDtos.GpsDiagnosticRequest ev : request.diagnostics()) {
                saveDiagnostic(user, ev);
            }
        }

        return new CardioDtos.StudentSyncResponse(measurementsSynced, sessionsSynced);
    }

    @Transactional
    public int addDiagnostics(AuthUser student, GpsAnalyticsDtos.AddGpsDiagnosticsRequest request) {
        User user = requireStudent(student);
        int n = 0;
        if (request.events() != null) {
            for (GpsAnalyticsDtos.GpsDiagnosticRequest ev : request.events()) {
                saveDiagnostic(user, ev);
                n++;
            }
        }
        return n;
    }

    private void saveDiagnostic(User user, GpsAnalyticsDtos.GpsDiagnosticRequest ev) {
        GpsDiagnostic d = new GpsDiagnostic();
        d.setStudent(user);
        d.setEventType(ev.eventType() != null ? ev.eventType() : "UNKNOWN");
        d.setRecordedAt(parseInstant(ev.timestamp()));
        d.setMessage(ev.message());
        d.setLatitude(ev.latitude());
        d.setLongitude(ev.longitude());
        d.setAccuracy(ev.accuracy());
        if (ev.sessionId() != null) {
            sessionRepository.findById(ev.sessionId()).ifPresent(d::setSession);
        } else if (ev.clientSessionId() != null) {
            sessionRepository.findByClientSessionId(ev.clientSessionId()).ifPresent(d::setSession);
        }
        gpsDiagnosticRepository.save(d);
    }

    private CardioSession requireStudentSession(AuthUser student, UUID sessionId) {
        CardioSession session = sessionRepository.findById(sessionId)
                .orElseThrow(() -> new ApiException("Sessão não encontrada"));
        if (!session.getStudent().getId().equals(student.getId())) {
            throw new ApiException("Acesso negado");
        }
        if (session.getCompletedAt() != null) {
            throw new ApiException("Sessão já finalizada");
        }
        return session;
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

    private CardioWorkout requireInstructorWorkout(AuthUser instructor, UUID workoutId) {
        User instructorUser = tenantService.requireInstructor(instructor);
        CardioWorkout workout = workoutRepository.findById(workoutId)
                .orElseThrow(() -> new ApiException("Treino outdoor não encontrado"));
        if (!workout.getInstructor().getId().equals(instructorUser.getId())) {
            throw new ApiException("Acesso negado");
        }
        return workout;
    }

    private void deactivateOtherActiveWorkouts(UUID studentId, UUID keepWorkoutId) {
        workoutRepository.findByStudentIdAndActiveTrueOrderByCreatedAtDesc(studentId)
                .forEach(w -> {
                    if (!w.getId().equals(keepWorkoutId)) {
                        w.setActive(false);
                        workoutRepository.save(w);
                    }
                });
    }

    private Instant parseInstant(String value) {
        if (value == null || value.isBlank()) {
            return Instant.now();
        }
        return Instant.parse(value);
    }

    private CardioDtos.CardioWorkoutResponse toWorkoutResponse(CardioWorkout w) {
        return new CardioDtos.CardioWorkoutResponse(
                w.getId(),
                w.getStudent().getId(),
                w.getStudent().getName(),
                w.getTitle(),
                w.getType(),
                w.getIntervalsJson(),
                w.isActive(),
                ISO.format(w.getCreatedAt())
        );
    }

    private CardioDtos.CardioSessionResponse toSessionResponse(CardioSession s) {
        List<CardioDtos.RoutePointResponse> points = s.getRoutePoints().stream()
                .map(p -> new CardioDtos.RoutePointResponse(
                        p.getLatitude(),
                        p.getLongitude(),
                        p.getSpeedKmh(),
                        ISO.format(p.getRecordedAt()),
                        p.getSequenceNum(),
                        p.getAccuracyMeters(),
                        p.getHeading(),
                        p.getAltitudeMeters(),
                        p.getProvider(),
                        p.getFiltered(),
                        p.getBatteryLevel(),
                        p.getVerticalAccuracy(),
                        p.getBearingAccuracy(),
                        p.getSpeedAccuracy(),
                        p.getFilterReason(),
                        p.getConfidenceScore()
                ))
                .toList();
        return new CardioDtos.CardioSessionResponse(
                s.getId(),
                s.getWorkout() != null ? s.getWorkout().getId() : null,
                s.getWorkout() != null ? s.getWorkout().getTitle() : null,
                s.getStudent().getId(),
                s.getStudent().getName(),
                ISO.format(s.getStartedAt()),
                s.getCompletedAt() != null ? ISO.format(s.getCompletedAt()) : null,
                s.getDistanceMeters(),
                s.getAvgSpeedKmh(),
                s.getElapsedMs(),
                s.getPausedMs() != null ? s.getPausedMs() : 0L,
                s.getPauseCount() != null ? s.getPauseCount() : 0,
                s.getCaloriesKcal(),
                s.getGpsQualityScore(),
                s.getGpsQualityLabel(),
                s.getGpsAlgorithmVersion(),
                s.getFilterVersion(),
                s.getKalmanVersion(),
                s.getDistanceVersion(),
                s.getCaloriesVersion(),
                points
        );
    }

    private int resolveCardioCalories(
            UUID studentId,
            Double distanceMeters,
            Double avgSpeedKmh,
            Long elapsedMs,
            Long pausedMs,
            Integer clientCalories
    ) {
        if (clientCalories != null && clientCalories >= 0) {
            return clientCalories;
        }
        Double weight = profileRepository.findByUserId(studentId)
                .map(StudentProfile::getCurrentWeightKg)
                .orElse(null);
        double speed = avgSpeedKmh != null ? avgSpeedKmh : 0;
        if (speed <= 0 && distanceMeters != null && elapsedMs != null && elapsedMs > 0) {
            speed = (distanceMeters / 1000.0) / (elapsedMs / 3_600_000.0);
        }
        return calorieEstimationService.estimateCardioKcal(
                calorieEstimationService.resolveWeightKg(weight),
                speed,
                elapsedMs,
                pausedMs
        );
    }

    private RoutePoint toRoutePoint(CardioSession session, CardioDtos.RoutePointRequest point) {
        RoutePoint rp = new RoutePoint();
        rp.setSession(session);
        rp.setLatitude(point.latitude());
        rp.setLongitude(point.longitude());
        rp.setSpeedKmh(point.speedKmh());
        rp.setRecordedAt(parseInstant(point.recordedAt()));
        rp.setSequenceNum(point.sequenceNum());
        rp.setAccuracyMeters(point.accuracyMeters());
        rp.setHeading(point.heading());
        rp.setAltitudeMeters(point.altitudeMeters());
        rp.setProvider(point.provider());
        rp.setFiltered(point.filtered());
        rp.setBatteryLevel(point.batteryLevel());
        rp.setVerticalAccuracy(point.verticalAccuracy());
        rp.setBearingAccuracy(point.bearingAccuracy());
        rp.setSpeedAccuracy(point.speedAccuracy());
        rp.setFilterReason(point.filterReason());
        rp.setConfidenceScore(point.confidenceScore());
        return rp;
    }
}
