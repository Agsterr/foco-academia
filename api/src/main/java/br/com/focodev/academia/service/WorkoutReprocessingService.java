package br.com.focodev.academia.service;

import br.com.focodev.academia.domain.CardioSession;
import br.com.focodev.academia.domain.RoutePoint;
import br.com.focodev.academia.dto.CardioDtos;
import br.com.focodev.academia.exception.ApiException;
import br.com.focodev.academia.repository.BodyMeasurementRepository;
import br.com.focodev.academia.repository.CardioSessionRepository;
import br.com.focodev.academia.repository.StudentProfileRepository;
import br.com.focodev.academia.security.AuthUser;
import org.springframework.stereotype.Service;
import org.springframework.transaction.annotation.Transactional;

import java.util.Comparator;
import java.util.List;
import java.util.UUID;

/**
 * Reprocessa métricas de uma sessão a partir dos pontos brutos.
 * Não participa do path de gravação em tempo real.
 */
@Service
public class WorkoutReprocessingService {

    private static final String REPROCESS_ALGORITHM = "reprocess-v1";

    private final CardioSessionRepository sessionRepository;
    private final CalorieEstimationService calorieEstimationService;
    private final TenantService tenantService;
    private final StudentProfileRepository profileRepository;
    private final BodyMeasurementRepository measurementRepository;

    public WorkoutReprocessingService(
            CardioSessionRepository sessionRepository,
            CalorieEstimationService calorieEstimationService,
            TenantService tenantService,
            StudentProfileRepository profileRepository,
            BodyMeasurementRepository measurementRepository
    ) {
        this.sessionRepository = sessionRepository;
        this.calorieEstimationService = calorieEstimationService;
        this.tenantService = tenantService;
        this.profileRepository = profileRepository;
        this.measurementRepository = measurementRepository;
    }

    @Transactional
    public CardioDtos.CardioSessionResponse reprocess(AuthUser instructor, UUID sessionId) {
        tenantService.requireInstructor(instructor);
        CardioSession session = sessionRepository.findById(sessionId)
                .orElseThrow(() -> new ApiException("Sessão não encontrada"));
        if (session.getStudent().getInstructor() == null
                || !session.getStudent().getInstructor().getId().equals(instructor.getId())) {
            throw new ApiException("Acesso negado");
        }
        return applyReprocess(session);
    }

    @Transactional
    public CardioDtos.CardioSessionResponse reprocessAsOwner(AuthUser student, UUID sessionId) {
        CardioSession session = sessionRepository.findById(sessionId)
                .orElseThrow(() -> new ApiException("Sessão não encontrada"));
        if (!session.getStudent().getId().equals(student.getId())) {
            throw new ApiException("Acesso negado");
        }
        return applyReprocess(session);
    }

    private CardioDtos.CardioSessionResponse applyReprocess(CardioSession session) {
        List<RoutePoint> points = session.getRoutePoints().stream()
                .sorted(Comparator.comparingInt(RoutePoint::getSequenceNum))
                .toList();

        double distance = 0;
        int accepted = 0;
        double confSum = 0;
        double accSum = 0;
        int accN = 0;
        RoutePoint prev = null;
        for (RoutePoint p : points) {
            boolean filtered = Boolean.TRUE.equals(p.getFiltered());
            String reason = p.getFilterReason();
            if (filtered && reason != null && !"NONE".equalsIgnoreCase(reason)) {
                continue;
            }
            accepted++;
            if (p.getConfidenceScore() != null) {
                confSum += p.getConfidenceScore();
            }
            if (p.getAccuracyMeters() != null) {
                accSum += p.getAccuracyMeters();
                accN++;
            }
            if (prev != null) {
                double d = haversineMeters(
                        prev.getLatitude(), prev.getLongitude(),
                        p.getLatitude(), p.getLongitude()
                );
                Double conf = p.getConfidenceScore();
                double weight = conf != null ? (0.85 + 0.15 * conf) : 1.0;
                if (d >= 2.5 && d <= 90) {
                    distance += d * weight;
                }
            }
            prev = p;
        }

        long elapsedMs = session.getElapsedMs() != null ? session.getElapsedMs() : 0L;
        long pausedMs = session.getPausedMs() != null ? session.getPausedMs() : 0L;
        long movingMs = Math.max(0, elapsedMs - pausedMs);
        double avgSpeed = 0;
        if (movingMs > 0 && distance > 0) {
            avgSpeed = (distance / 1000.0) / (movingMs / 3_600_000.0);
        }

        int kcal = calorieEstimationService.estimateCardioKcal(
                calorieEstimationService.resolveStudentWeightKg(
                        session.getStudent().getId(), profileRepository, measurementRepository),
                avgSpeed,
                movingMs,
                pausedMs,
                distance
        );

        double avgConf = accepted > 0 ? confSum / Math.max(1, accepted) : 0.7;
        double avgAcc = accN > 0 ? accSum / accN : 25;
        double quality = Math.max(0, Math.min(100,
                (1.0 / (1.0 + avgAcc / 18.0)) * 50
                        + avgConf * 50));

        session.setDistanceMeters(distance);
        session.setAvgSpeedKmh(avgSpeed);
        session.setCaloriesKcal(kcal);
        session.setGpsQualityScore(quality);
        session.setGpsQualityLabel(qualityLabel(quality));
        session.setGpsAlgorithmVersion(REPROCESS_ALGORITHM);
        session.setDistanceVersion("reprocess-v1");
        session.setCaloriesVersion("reprocess-v1");

        CardioSession saved = sessionRepository.save(session);
        return toMinimalResponse(saved);
    }

    private static String qualityLabel(double score) {
        if (score >= 90) return "Excelente";
        if (score >= 75) return "Boa";
        if (score >= 55) return "Razoável";
        return "Baixa precisão";
    }

    private static double haversineMeters(double lat1, double lon1, double lat2, double lon2) {
        final double R = 6371000.0;
        double dLat = Math.toRadians(lat2 - lat1);
        double dLon = Math.toRadians(lon2 - lon1);
        double a = Math.sin(dLat / 2) * Math.sin(dLat / 2)
                + Math.cos(Math.toRadians(lat1)) * Math.cos(Math.toRadians(lat2))
                * Math.sin(dLon / 2) * Math.sin(dLon / 2);
        double c = 2 * Math.atan2(Math.sqrt(a), Math.sqrt(1 - a));
        return R * c;
    }

    private CardioDtos.CardioSessionResponse toMinimalResponse(CardioSession s) {
        return new CardioDtos.CardioSessionResponse(
                s.getId(),
                s.getWorkout() != null ? s.getWorkout().getId() : null,
                s.getWorkout() != null ? s.getWorkout().getTitle() : null,
                s.getStudent().getId(),
                s.getStudent().getName(),
                s.getStartedAt().toString(),
                s.getCompletedAt() != null ? s.getCompletedAt().toString() : null,
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
                List.of()
        );
    }
}
