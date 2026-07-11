package br.com.focodev.academia.service;

import org.junit.jupiter.api.Test;

import static org.junit.jupiter.api.Assertions.*;

class QuickWorkoutTemplatesTest {

    @Test
    void build_emagrecer_hasSevenDays() {
        var request = QuickWorkoutTemplates.build(
                br.com.focodev.academia.domain.FitnessGoal.EMAGRECER,
                java.util.UUID.randomUUID()
        );
        assertEquals("Treino rápido — Emagrecimento", request.title());
        assertEquals(7, request.days().size());
        assertTrue(request.days().stream().anyMatch(d -> "Full body + cardio".equals(d.muscleGroup())));
    }

    @Test
    void build_corrida_usesCondicionamentoTemplate() {
        var request = QuickWorkoutTemplates.build(
                br.com.focodev.academia.domain.FitnessGoal.CORRIDA,
                java.util.UUID.randomUUID()
        );
        assertTrue(request.title().contains("Condicionamento"));
    }
}
