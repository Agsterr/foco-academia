package br.com.focodev.academia.service;

import br.com.focodev.academia.domain.CardioSession;
import br.com.focodev.academia.domain.RoutePoint;
import br.com.focodev.academia.domain.User;
import br.com.focodev.academia.dto.GpsAiDtos;
import br.com.focodev.academia.repository.CardioSessionRepository;
import br.com.focodev.academia.repository.UserRepository;
import br.com.focodev.academia.security.AuthUser;
import br.com.focodev.academia.security.JwtService;
import org.junit.jupiter.api.BeforeEach;
import org.junit.jupiter.api.Test;
import org.springframework.beans.factory.annotation.Autowired;
import org.springframework.boot.test.context.SpringBootTest;
import org.springframework.security.crypto.password.PasswordEncoder;
import org.springframework.test.context.ActiveProfiles;
import org.springframework.transaction.annotation.Transactional;

import java.time.Instant;
import java.util.UUID;

import static org.assertj.core.api.Assertions.assertThat;

@SpringBootTest
@ActiveProfiles("test")
@Transactional
class GpsAiAnalysisServiceTest {

    @Autowired GpsAiAnalysisService aiAnalysisService;
    @Autowired CardioSessionRepository sessionRepository;
    @Autowired UserRepository userRepository;
    @Autowired PasswordEncoder passwordEncoder;
    @Autowired JwtService jwtService;
    @Autowired br.com.focodev.academia.repository.AcademyRepository academyRepository;

    private AuthUser studentAuth;
    private CardioSession session;

    @BeforeEach
    void setUp() {
        var fixture = br.com.focodev.academia.integration.support.AcademyFixture.create(
                academyRepository, userRepository, passwordEncoder, jwtService);
        User student = fixture.student();
        studentAuth = new AuthUser(student);

        session = new CardioSession();
        session.setStudent(student);
        session.setStartedAt(Instant.parse("2026-01-01T12:00:00Z"));
        session.setCompletedAt(Instant.parse("2026-01-01T12:30:00Z"));
        session.setElapsedMs(1_800_000L);
        session.setPausedMs(0L);
        session.setDistanceMeters(4000.0);
        session.setAvgSpeedKmh(8.0);
        session.setClientSessionId("ai-test-" + UUID.randomUUID());

        // ponto normal
        session.getRoutePoints().add(point(session, 0, -23.5500, -46.6300, 8, Instant.parse("2026-01-01T12:00:00Z"), 0.95));
        session.getRoutePoints().add(point(session, 1, -23.5503, -46.6300, 9, Instant.parse("2026-01-01T12:00:10Z"), 0.9));
        // salto absurdo
        session.getRoutePoints().add(point(session, 2, -23.5600, -46.6400, 80, Instant.parse("2026-01-01T12:00:12Z"), 0.2));
        // velocidade de carro
        session.getRoutePoints().add(point(session, 3, -23.5700, -46.6500, 90, Instant.parse("2026-01-01T12:00:20Z"), 0.2));

        session = sessionRepository.save(session);
    }

    private static RoutePoint point(
            CardioSession s, int seq, double lat, double lng, double speed,
            Instant at, double conf
    ) {
        RoutePoint p = new RoutePoint();
        p.setSession(s);
        p.setSequenceNum(seq);
        p.setLatitude(lat);
        p.setLongitude(lng);
        p.setSpeedKmh(speed);
        p.setRecordedAt(at);
        p.setConfidenceScore(conf);
        p.setAccuracyMeters(conf > 0.5 ? 8.0 : 40.0);
        p.setFiltered(false);
        p.setFilterReason("NONE");
        return p;
    }

    @Test
    void detectaSaltoEVelocidadeSuspeita() {
        GpsAiDtos.SessionAiInsightsResponse r =
                aiAnalysisService.analyzeSession(studentAuth, session.getId());
        assertThat(r.suspiciousActivity()).isTrue();
        assertThat(r.findings()).anyMatch(f -> "GPS_JUMP".equals(f.code()) || "SUSPICIOUS_VEHICLE_SPEED".equals(f.code()));
        assertThat(r.segmentSuggestions()).isNotEmpty();
        assertThat(r.overallRiskScore()).isGreaterThan(10);
    }

    @Test
    void recommendationsComHistorico() {
        GpsAiDtos.AthleteRecommendationsResponse r =
                aiAnalysisService.recommendations(studentAuth);
        assertThat(r.evolutionSummary()).isNotBlank();
        assertThat(r.recommendations()).isNotEmpty();
    }
}
