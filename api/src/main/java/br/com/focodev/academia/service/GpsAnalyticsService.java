package br.com.focodev.academia.service;

import br.com.focodev.academia.domain.CardioSession;
import br.com.focodev.academia.domain.GpsDiagnostic;
import br.com.focodev.academia.domain.RoutePoint;
import br.com.focodev.academia.dto.GpsAnalyticsDtos;
import br.com.focodev.academia.repository.CardioSessionRepository;
import br.com.focodev.academia.repository.GpsDiagnosticRepository;
import br.com.focodev.academia.security.AuthUser;
import org.springframework.stereotype.Service;
import org.springframework.transaction.annotation.Transactional;

import java.util.HashMap;
import java.util.List;
import java.util.Map;

@Service
public class GpsAnalyticsService {

    private final CardioSessionRepository sessionRepository;
    private final GpsDiagnosticRepository diagnosticRepository;
    private final TenantService tenantService;

    public GpsAnalyticsService(
            CardioSessionRepository sessionRepository,
            GpsDiagnosticRepository diagnosticRepository,
            TenantService tenantService
    ) {
        this.sessionRepository = sessionRepository;
        this.diagnosticRepository = diagnosticRepository;
        this.tenantService = tenantService;
    }

    @Transactional(readOnly = true)
    public GpsAnalyticsDtos.InstructorGpsAnalyticsResponse instructorAnalytics(AuthUser instructor) {
        var instructorUser = tenantService.requireInstructor(instructor);
        List<CardioSession> sessions = sessionRepository.findByInstructorStudents(instructorUser.getId());

        long completed = 0;
        double qualitySum = 0;
        int qualityN = 0;
        Map<String, Long> qualityBuckets = new HashMap<>();
        Map<String, Long> filterReasons = new HashMap<>();
        Map<String, Long> algorithmVersions = new HashMap<>();

        for (CardioSession s : sessions) {
            if (s.getCompletedAt() == null) continue;
            completed++;
            if (s.getGpsQualityScore() != null) {
                qualitySum += s.getGpsQualityScore();
                qualityN++;
                String label = s.getGpsQualityLabel() != null ? s.getGpsQualityLabel() : "N/A";
                qualityBuckets.merge(label, 1L, Long::sum);
            }
            if (s.getGpsAlgorithmVersion() != null) {
                algorithmVersions.merge(s.getGpsAlgorithmVersion(), 1L, Long::sum);
            }
            for (RoutePoint p : s.getRoutePoints()) {
                if (p.getFilterReason() != null && !"NONE".equalsIgnoreCase(p.getFilterReason())) {
                    filterReasons.merge(p.getFilterReason(), 1L, Long::sum);
                }
            }
        }

        Map<String, Long> diagnosticEvents = new HashMap<>();
        for (Object[] row : diagnosticRepository.countByEventTypeForInstructor(instructorUser.getId())) {
            diagnosticEvents.put(String.valueOf(row[0]), (Long) row[1]);
        }

        return new GpsAnalyticsDtos.InstructorGpsAnalyticsResponse(
                completed,
                qualityN > 0 ? qualitySum / qualityN : null,
                qualityBuckets,
                filterReasons,
                diagnosticEvents,
                algorithmVersions
        );
    }

    @Transactional(readOnly = true)
    public List<GpsAnalyticsDtos.GpsDiagnosticResponse> sessionDiagnostics(AuthUser user, java.util.UUID sessionId) {
        CardioSession session = sessionRepository.findById(sessionId)
                .orElseThrow(() -> new br.com.focodev.academia.exception.ApiException("Sessão não encontrada"));
        boolean allowed = session.getStudent().getId().equals(user.getId())
                || (session.getStudent().getInstructor() != null
                && session.getStudent().getInstructor().getId().equals(user.getId()));
        if (!allowed) {
            throw new br.com.focodev.academia.exception.ApiException("Acesso negado");
        }
        return diagnosticRepository.findBySessionIdOrderByRecordedAtAsc(sessionId).stream()
                .map(this::toDiag)
                .toList();
    }

    private GpsAnalyticsDtos.GpsDiagnosticResponse toDiag(GpsDiagnostic d) {
        return new GpsAnalyticsDtos.GpsDiagnosticResponse(
                d.getId(),
                d.getEventType(),
                d.getRecordedAt().toString(),
                d.getMessage(),
                d.getLatitude(),
                d.getLongitude(),
                d.getAccuracy()
        );
    }
}
