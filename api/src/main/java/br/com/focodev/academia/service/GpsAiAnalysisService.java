package br.com.focodev.academia.service;

import br.com.focodev.academia.domain.CardioSession;
import br.com.focodev.academia.domain.RoutePoint;
import br.com.focodev.academia.dto.GpsAiDtos;
import br.com.focodev.academia.exception.ApiException;
import br.com.focodev.academia.repository.CardioSessionRepository;
import br.com.focodev.academia.security.AuthUser;
import org.springframework.stereotype.Service;
import org.springframework.transaction.annotation.Transactional;

import java.time.Duration;
import java.util.ArrayList;
import java.util.Comparator;
import java.util.List;
import java.util.UUID;

/**
 * Análise inteligente baseada em regras/estatísticas sobre pontos brutos.
 * Não inventa trajetos — apenas detecta anomalias e sugere exclusão/revisão de trechos.
 */
@Service
public class GpsAiAnalysisService {

    private static final double RUN_MAX_KMH = 30;
    private static final double WALK_MAX_KMH = 12;
    private static final double CAR_SUSPECT_KMH = 45;
    private static final double JUMP_METERS = 90;

    private final CardioSessionRepository sessionRepository;

    public GpsAiAnalysisService(CardioSessionRepository sessionRepository) {
        this.sessionRepository = sessionRepository;
    }

    @Transactional(readOnly = true)
    public GpsAiDtos.SessionAiInsightsResponse analyzeSession(AuthUser user, UUID sessionId) {
        CardioSession session = requireAccessibleSession(user, sessionId);
        List<RoutePoint> points = session.getRoutePoints().stream()
                .sorted(Comparator.comparingInt(RoutePoint::getSequenceNum))
                .toList();

        List<GpsAiDtos.Finding> findings = new ArrayList<>();
        List<GpsAiDtos.SegmentSuggestion> suggestions = new ArrayList<>();
        boolean suspicious = false;
        double risk = 0;

        RoutePoint prev = null;
        int lowConfStreak = 0;
        int jumpCount = 0;
        int impossibleCount = 0;
        double distance = 0;

        for (RoutePoint p : points) {
            Boolean filtered = p.getFiltered();
            String reason = p.getFilterReason();
            if (Boolean.TRUE.equals(filtered) && reason != null && !"NONE".equalsIgnoreCase(reason)) {
                // já filtrado no app — informa
                if ("GPS_JUMP".equalsIgnoreCase(reason)) jumpCount++;
                if ("IMPOSSIBLE_SPEED".equalsIgnoreCase(reason)) impossibleCount++;
            }

            double conf = p.getConfidenceScore() != null ? p.getConfidenceScore() : 0.7;
            if (conf < 0.35) {
                lowConfStreak++;
            } else {
                if (lowConfStreak >= 5) {
                    findings.add(new GpsAiDtos.Finding(
                            "LOW_CONFIDENCE_CLUSTER",
                            "WARN",
                            "Trecho com baixa confiança GPS",
                            lowConfStreak + " pontos seguidos com confidence < 0.35",
                            Math.max(0, p.getSequenceNum() - lowConfStreak),
                            p.getSequenceNum()
                    ));
                    suggestions.add(new GpsAiDtos.SegmentSuggestion(
                            Math.max(0, p.getSequenceNum() - lowConfStreak),
                            p.getSequenceNum(),
                            "EXCLUDE_FROM_DISTANCE",
                            "Baixa confiança — não inventar rota; apenas excluir do km oficial"
                    ));
                    risk += 8;
                }
                lowConfStreak = 0;
            }

            if (prev != null) {
                double d = haversine(prev.getLatitude(), prev.getLongitude(), p.getLatitude(), p.getLongitude());
                long dtMs = Duration.between(prev.getRecordedAt(), p.getRecordedAt()).toMillis();
                double dtSec = Math.max(0.001, dtMs / 1000.0);
                double implied = (d / dtSec) * 3.6;

                if (dtSec < 12 && d > JUMP_METERS) {
                    jumpCount++;
                    findings.add(new GpsAiDtos.Finding(
                            "GPS_JUMP",
                            "ERROR",
                            "Salto GPS detectado",
                            String.format("%.0f m em %.1fs", d, dtSec),
                            prev.getSequenceNum(),
                            p.getSequenceNum()
                    ));
                    suggestions.add(new GpsAiDtos.SegmentSuggestion(
                            prev.getSequenceNum(),
                            p.getSequenceNum(),
                            "EXCLUDE_FROM_DISTANCE",
                            "Salto espacial — manter pontos brutos, não interpolar"
                    ));
                    risk += 12;
                    if (implied > CAR_SUSPECT_KMH) {
                        suspicious = true;
                        findings.add(new GpsAiDtos.Finding(
                                "SUSPICIOUS_VEHICLE_SPEED",
                                "CRITICAL",
                                "Velocidade compatível com veículo",
                                String.format("%.1f km/h implícitos — possível deslocamento de carro", implied),
                                prev.getSequenceNum(),
                                p.getSequenceNum()
                        ));
                        suggestions.add(new GpsAiDtos.SegmentSuggestion(
                                prev.getSequenceNum(),
                                p.getSequenceNum(),
                                "FLAG_SUSPICIOUS",
                                "Revisar manualmente; não contar como corrida"
                        ));
                        risk += 25;
                    }
                } else if (implied > CAR_SUSPECT_KMH && dtSec < 30) {
                    suspicious = true;
                    findings.add(new GpsAiDtos.Finding(
                            "SUSPICIOUS_VEHICLE_SPEED",
                            "CRITICAL",
                            "Velocidade compatível com veículo",
                            String.format("%.1f km/h implícitos — possível deslocamento de carro", implied),
                            prev.getSequenceNum(),
                            p.getSequenceNum()
                    ));
                    suggestions.add(new GpsAiDtos.SegmentSuggestion(
                            prev.getSequenceNum(),
                            p.getSequenceNum(),
                            "FLAG_SUSPICIOUS",
                            "Revisar manualmente; não contar como corrida"
                    ));
                    risk += 25;
                } else if (implied > RUN_MAX_KMH && dtSec < 20) {
                    impossibleCount++;
                    findings.add(new GpsAiDtos.Finding(
                            "IMPOSSIBLE_SPEED",
                            "WARN",
                            "Velocidade improvável para corrida",
                            String.format("%.1f km/h (limite ~%.0f)", implied, RUN_MAX_KMH),
                            prev.getSequenceNum(),
                            p.getSequenceNum()
                    ));
                    risk += 6;
                } else if (d >= 2.5 && d <= JUMP_METERS) {
                    distance += d;
                }
            }

            Double acc = p.getAccuracyMeters();
            if (acc != null && acc > 50) {
                risk += 0.3;
            }

            prev = p;
        }

        if (jumpCount >= 3) {
            findings.add(new GpsAiDtos.Finding(
                    "MANY_JUMPS",
                    "WARN",
                    "Muitos saltos GPS",
                    jumpCount + " saltos na sessão — ambiente urbano/túneis ou sinal fraco",
                    null,
                    null
            ));
            risk += 10;
        }
        if (impossibleCount >= 3) {
            findings.add(new GpsAiDtos.Finding(
                    "MANY_IMPOSSIBLE_SPEEDS",
                    "WARN",
                    "Várias velocidades impossíveis",
                    impossibleCount + " ocorrências",
                    null,
                    null
            ));
        }

        long movingSec = 0;
        if (session.getElapsedMs() != null) {
            long paused = session.getPausedMs() != null ? session.getPausedMs() : 0;
            movingSec = Math.max(0, (session.getElapsedMs() - paused) / 1000);
        }
        Double distOfficial = session.getDistanceMeters() != null ? session.getDistanceMeters() : distance;
        Double avgPace = null;
        if (distOfficial != null && distOfficial > 30 && movingSec > 10) {
            avgPace = movingSec / (distOfficial / 1000.0);
        }
        Double avgSpeed = session.getAvgSpeedKmh();
        if (avgSpeed == null && distOfficial != null && movingSec > 0) {
            avgSpeed = (distOfficial / 1000.0) / (movingSec / 3600.0);
        }

        String trend = "ESTÁVEL";
        if (avgSpeed != null && avgSpeed > WALK_MAX_KMH && avgSpeed <= RUN_MAX_KMH) {
            trend = "CORRIDA";
        } else if (avgSpeed != null && avgSpeed <= WALK_MAX_KMH) {
            trend = "CAMINHADA";
        }

        risk = Math.min(100, risk);
        String summary;
        if (suspicious) {
            summary = "Atividade suspeita detectada — revise trechos de alta velocidade.";
        } else if (risk >= 40) {
            summary = "Qualidade GPS comprometida em trechos; sugestões de exclusão disponíveis.";
        } else if (risk >= 15) {
            summary = "Alguns anomalias leves; métricas geralmente confiáveis.";
        } else {
            summary = "Sessão consistente — poucos indícios de erro de GPS.";
        }

        if (findings.isEmpty()) {
            findings.add(new GpsAiDtos.Finding(
                    "OK",
                    "INFO",
                    "Sem anomalias relevantes",
                    "Nenhum padrão crítico de erro ou fraude detectado",
                    null,
                    null
            ));
        }

        return new GpsAiDtos.SessionAiInsightsResponse(
                session.getId(),
                risk,
                summary,
                findings,
                suggestions,
                new GpsAiDtos.PerformanceSnapshot(
                        avgPace,
                        null,
                        avgSpeed,
                        distOfficial,
                        (int) movingSec,
                        trend
                ),
                suspicious
        );
    }

    @Transactional(readOnly = true)
    public GpsAiDtos.AthleteRecommendationsResponse recommendations(AuthUser student) {
        UUID studentId = student.getId();
        List<CardioSession> sessions = sessionRepository.findCompletedByStudentId(studentId);
        List<String> recs = new ArrayList<>();
        List<String> warnings = new ArrayList<>();

        if (sessions.isEmpty()) {
            return new GpsAiDtos.AthleteRecommendationsResponse(
                    "Ainda sem histórico outdoor suficiente.",
                    null,
                    List.of("Complete 3–5 corridas/caminhadas para liberar recomendações personalizadas."),
                    List.of()
            );
        }

        List<Double> paces = new ArrayList<>();
        List<Double> qualities = new ArrayList<>();
        double totalKm = 0;
        int suspiciousSessions = 0;

        for (CardioSession s : sessions) {
            if (s.getDistanceMeters() != null) totalKm += s.getDistanceMeters() / 1000.0;
            if (s.getGpsQualityScore() != null) qualities.add(s.getGpsQualityScore());
            if (s.getDistanceMeters() != null && s.getDistanceMeters() > 200
                    && s.getElapsedMs() != null && s.getElapsedMs() > 60_000) {
                long moving = s.getElapsedMs() - (s.getPausedMs() != null ? s.getPausedMs() : 0);
                if (moving > 0) {
                    double pace = (moving / 1000.0) / (s.getDistanceMeters() / 1000.0);
                    if (pace > 150 && pace < 1200) paces.add(pace);
                }
            }
            // heurística: avgSpeed muito alta
            if (s.getAvgSpeedKmh() != null && s.getAvgSpeedKmh() > CAR_SUSPECT_KMH) {
                suspiciousSessions++;
            }
        }

        Double predictedPace = null;
        String evolution;
        if (paces.size() >= 2) {
            double recent = average(paces.subList(Math.max(0, paces.size() - 3), paces.size()));
            double older = average(paces.subList(0, Math.min(3, paces.size())));
            predictedPace = recent * 0.7 + older * 0.3;
            if (recent < older * 0.97) {
                evolution = "Tendência de melhora no ritmo nas últimas sessões.";
                recs.add("Mantenha 1 sessão intervalada por semana para consolidar o ritmo.");
            } else if (recent > older * 1.03) {
                evolution = "Ritmo um pouco mais lento recentemente — pode ser volume ou recuperação.";
                recs.add("Inclua 1 caminhada leve de recuperação e revise o sono/hidratação.");
            } else {
                evolution = "Ritmo estável ao longo do histórico.";
                recs.add("Experimente progressão de 5–10% na distância semanal.");
            }
        } else {
            evolution = "Histórico curto — continue registrando para prever evolução.";
            recs.add("Faça pelo menos 3 atividades similares (ex.: 3–5 km) para calibrar o ritmo.");
        }

        if (!qualities.isEmpty() && average(qualities) < 60) {
            warnings.add("Qualidade GPS média baixa — use localização \"sempre\" e ignore otimização de bateria.");
            recs.add("Antes da próxima corrida, abra o Debug GPS e confira accuracy < 20 m em área aberta.");
        }
        if (suspiciousSessions > 0) {
            warnings.add(suspiciousSessions + " sessão(ões) com velocidade muito alta — revise possíveis trechos de veículo.");
        }
        if (totalKm < 10) {
            recs.add("Meta sugerida: acumular 10 km na próxima semana em 2–3 sessões.");
        } else if (totalKm < 40) {
            recs.add("Volume bom para base. Alternar dias de ritmo confortável e um dia mais forte.");
        } else {
            recs.add("Bom volume acumulado. Considere um longão semanal (+20% vs. distância média).");
        }

        if (recs.size() > 4) {
            recs = recs.subList(0, 4);
        }

        return new GpsAiDtos.AthleteRecommendationsResponse(
                evolution,
                predictedPace,
                recs,
                warnings
        );
    }

    private CardioSession requireAccessibleSession(AuthUser user, UUID sessionId) {
        CardioSession session = sessionRepository.findById(sessionId)
                .orElseThrow(() -> new ApiException("Sessão não encontrada"));
        boolean owner = session.getStudent().getId().equals(user.getId());
        boolean instructor = session.getStudent().getInstructor() != null
                && session.getStudent().getInstructor().getId().equals(user.getId());
        if (!owner && !instructor) {
            throw new ApiException("Acesso negado");
        }
        return session;
    }

    private static double average(List<Double> values) {
        return values.stream().mapToDouble(Double::doubleValue).average().orElse(0);
    }

    private static double haversine(double lat1, double lon1, double lat2, double lon2) {
        final double R = 6371000.0;
        double dLat = Math.toRadians(lat2 - lat1);
        double dLon = Math.toRadians(lon2 - lon1);
        double a = Math.sin(dLat / 2) * Math.sin(dLat / 2)
                + Math.cos(Math.toRadians(lat1)) * Math.cos(Math.toRadians(lat2))
                * Math.sin(dLon / 2) * Math.sin(dLon / 2);
        return R * 2 * Math.atan2(Math.sqrt(a), Math.sqrt(1 - a));
    }
}
