package br.com.focodev.academia.billing;

import br.com.focodev.academia.domain.Academy;
import br.com.focodev.academia.domain.UserRole;
import br.com.focodev.academia.exception.ApiException;
import br.com.focodev.academia.repository.UserRepository;
import lombok.RequiredArgsConstructor;
import org.springframework.stereotype.Component;

/** Quem paga por fora (academia ou personal) cadastra alunos só até o limite do plano. */
@Component
@RequiredArgsConstructor
public class StudentLimit {

    private final BillingProperties properties;
    private final UserRepository userRepository;

    /** Chamar antes de colocar mais um aluno na academia. */
    public void requireRoom(Academy academy) {
        if (!properties.enforce() || academy == null) {
            return;
        }
        int limit = properties.planIncludedStudents(academy);
        if (userRepository.countByAcademyIdAndRoleAndActiveTrue(academy.getId(), UserRole.ALUNO) >= limit) {
            throw new ApiException("O plano permite até " + limit + " alunos. Fale com a FocoDev para ampliar.");
        }
    }
}
