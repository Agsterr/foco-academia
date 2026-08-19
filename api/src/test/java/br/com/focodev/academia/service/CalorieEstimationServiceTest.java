package br.com.focodev.academia.service;

import br.com.focodev.academia.domain.WorkoutIntensity;
import org.junit.jupiter.api.Test;

import java.time.Instant;
import java.util.List;

import static org.junit.jupiter.api.Assertions.*;

class CalorieEstimationServiceTest {

    private final CalorieEstimationService service = new CalorieEstimationService();

    @Test
    void cardioExampleFromPlan() {
        // 9.8 MET × 80 kg × 0.75 h ≈ 588
        int kcal = service.estimateCardioKcal(80, 10.0, 45 * 60_000L, 0L);
        assertEquals(588, kcal);
    }

    @Test
    void stationaryWithoutDistance_isZero() {
        assertEquals(0, service.estimateCardioKcal(70, 0.0, 5 * 60_000L, 0L, 0.0));
        assertEquals(0, service.estimateCardioKcal(70, 0.0, 10 * 60_000L, 0L, null));
    }

    @Test
    void walkMetAt5Kmh() {
        assertEquals(3.8, service.metForSpeedKmh(5.0), 0.01);
    }

    @Test
    void strengthModerate() {
        // 5.0 × 70 × 1h = 350
        assertEquals(350, service.estimateStrengthKcal(70, 3600, WorkoutIntensity.MODERADA));
    }

    @Test
    void strengthOpenForDays_isCappedAtThreeHours() {
        long threeDays = 3L * 24 * 3600;
        int kcal = service.estimateStrengthKcal(70, threeDays, WorkoutIntensity.MODERADA);
        // 5.0 × 70 × 3h = 1050 — não 25.200
        assertEquals(1050, kcal);
    }

    @Test
    void strengthActiveDurationIgnoresDaysBetweenSets() {
        Instant first = Instant.parse("2026-08-01T10:00:00Z");
        Instant last = Instant.parse("2026-08-04T10:00:00Z");
        long seconds = service.activeStrengthDurationSeconds(List.of(first, last));
        assertEquals(15 * 60 + 90, seconds);
    }

    @Test
    void defaultWeight() {
        assertEquals(70.0, service.resolveWeightKg(null));
        assertEquals(82.5, service.resolveWeightKg(82.5));
    }
}
