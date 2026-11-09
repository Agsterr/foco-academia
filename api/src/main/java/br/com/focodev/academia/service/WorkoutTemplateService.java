package br.com.focodev.academia.service;

import br.com.focodev.academia.domain.CardioType;
import br.com.focodev.academia.dto.WorkoutTemplateDtos.Kind;
import br.com.focodev.academia.dto.WorkoutTemplateDtos.Level;
import br.com.focodev.academia.dto.WorkoutTemplateDtos.Modality;
import br.com.focodev.academia.dto.WorkoutTemplateDtos.StartTemplateResponse;
import br.com.focodev.academia.dto.WorkoutTemplateDtos.TemplateSummary;
import br.com.focodev.academia.exception.ApiException;
import br.com.focodev.academia.security.AuthUser;
import br.com.focodev.academia.service.templates.WorkoutTemplateCatalog;
import lombok.RequiredArgsConstructor;
import org.springframework.http.HttpStatus;
import org.springframework.stereotype.Service;
import org.springframework.transaction.annotation.Transactional;

import java.util.List;

/** Treinos prontos: o aluno escolhe um e ele vira uma ficha (ou treino outdoor) dele. */
@Service
@RequiredArgsConstructor
public class WorkoutTemplateService {

    private final WorkoutProgramService workoutProgramService;
    private final CardioService cardioService;

    public List<TemplateSummary> list(Modality modality, Level level) {
        return WorkoutTemplateCatalog.summaries(modality, level);
    }

    @Transactional
    public StartTemplateResponse start(AuthUser student, String key) {
        WorkoutTemplateCatalog.Template template = WorkoutTemplateCatalog.find(key)
                .orElseThrow(() -> new ApiException("Treino pronto não encontrado", HttpStatus.NOT_FOUND));

        if (template.summary().kind() == Kind.CARDIO) {
            var workout = cardioService.createOwnWorkout(
                    student,
                    template.summary().title(),
                    CardioType.valueOf(template.cardioType()),
                    template.intervals()
            );
            return new StartTemplateResponse(Kind.CARDIO, null, workout.id());
        }
        var program = workoutProgramService.createOwnProgram(student, template.program(), key);
        return new StartTemplateResponse(Kind.PROGRAM, program.id(), null);
    }
}
