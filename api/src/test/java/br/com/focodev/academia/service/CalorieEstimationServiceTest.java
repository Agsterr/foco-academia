package br.com.focodev.academia.service;

import br.com.focodev.academia.domain.WorkoutIntensity;
import org.junit.jupiter.api.Test;

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
    void walkMetAt5Kmh() {
        assertEquals(3.8, service.metForSpeedKmh(5.0), 0.01);
    }

    @Test
    void strengthModerate() {
        // 5.0 × 70 × 1h = 350
        assertEquals(350, service.estimateStrengthKcal(70, 3600, WorkoutIntensity.MODERADA));
    }

    @Test
    void defaultWeight() {
        assertEquals(70.0, service.resolveWeightKg(null));
        assertEquals(82.5, service.resolveWeightKg(82.5));
    }
}
