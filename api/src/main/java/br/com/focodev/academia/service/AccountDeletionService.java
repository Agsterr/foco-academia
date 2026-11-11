package br.com.focodev.academia.service;

import br.com.focodev.academia.domain.User;
import br.com.focodev.academia.domain.UserRole;
import br.com.focodev.academia.exception.ApiException;
import br.com.focodev.academia.repository.UserRepository;
import br.com.focodev.academia.security.AuthUser;
import lombok.RequiredArgsConstructor;
import org.springframework.http.HttpStatus;
import org.springframework.jdbc.core.JdbcTemplate;
import org.springframework.security.crypto.password.PasswordEncoder;
import org.springframework.stereotype.Service;
import org.springframework.transaction.annotation.Transactional;

import java.util.UUID;

/**
 * Exclusão de conta pelo próprio aluno (exigência da Google Play e da LGPD).
 *
 * Apaga os dados pessoais do aluno (rotas de GPS, peso, perfil, aparelhos, assinatura, treinos feitos)
 * e anonimiza a linha de usuário. A linha é mantida só para não quebrar as chaves estrangeiras de
 * fichas criadas por instrutores; sem e-mail, nome, telefone e senha ela não identifica mais ninguém.
 */
@Service
@RequiredArgsConstructor
public class AccountDeletionService {

    private final UserRepository userRepository;
    private final PasswordEncoder passwordEncoder;
    private final JdbcTemplate jdbc;

    @Transactional
    public void deleteStudentAccount(AuthUser auth, String password) {
        User user = userRepository.findById(auth.getId())
                .orElseThrow(() -> new ApiException("Conta não encontrada", HttpStatus.NOT_FOUND));
        if (user.getRole() != UserRole.ALUNO) {
            throw new ApiException(
                    "Contas de instrutor e gestor são excluídas pela academia. Peça pelo e-mail de contato.",
                    HttpStatus.FORBIDDEN);
        }
        if (password == null || !passwordEncoder.matches(password, user.getPasswordHash())) {
            throw new ApiException("Senha incorreta", HttpStatus.FORBIDDEN);
        }
        purgePersonalData(user.getId());
        anonymize(user);
    }

    /** Ordem importa: filhos antes dos pais. */
    void purgePersonalData(UUID id) {
        jdbc.update("DELETE FROM gps_diagnostics WHERE student_id = ? OR session_id IN "
                + "(SELECT id FROM cardio_sessions WHERE student_id = ?)", id, id);
        jdbc.update("DELETE FROM route_points WHERE session_id IN "
                + "(SELECT id FROM cardio_sessions WHERE student_id = ?)", id);
        jdbc.update("DELETE FROM cardio_sessions WHERE student_id = ?", id);
        jdbc.update("DELETE FROM cardio_workouts WHERE student_id = ?", id);
        jdbc.update("UPDATE cardio_workouts SET instructor_id = NULL WHERE instructor_id = ?", id);

        jdbc.update("DELETE FROM set_logs WHERE session_id IN "
                + "(SELECT id FROM workout_sessions WHERE student_id = ?)", id);
        jdbc.update("DELETE FROM workout_feedbacks WHERE student_id = ?", id);
        jdbc.update("DELETE FROM workout_sessions WHERE student_id = ?", id);

        jdbc.update("DELETE FROM body_measurements WHERE student_id = ?", id);
        jdbc.update("DELETE FROM goal_check_ins WHERE student_id = ?", id);
        jdbc.update("DELETE FROM weight_check_schedules WHERE student_id = ?", id);
        jdbc.update("DELETE FROM suggestions WHERE student_id = ?", id);
        jdbc.update("DELETE FROM student_profiles WHERE user_id = ?", id);
        jdbc.update("DELETE FROM subscriptions WHERE user_id = ?", id);
        jdbc.update("DELETE FROM device_sessions WHERE user_id = ?", id);
        jdbc.update("UPDATE invites SET used_by_id = NULL WHERE used_by_id = ?", id);
    }

    private void anonymize(User user) {
        user.setEmail("excluido-" + user.getId() + "@conta-excluida.invalid");
        user.setName("Conta excluída");
        user.setPhone(null);
        user.setPasswordHash(passwordEncoder.encode(UUID.randomUUID().toString()));
        user.setActive(false);
        user.setInstructor(null);
        user.setSingleDevice(false);
        userRepository.save(user);
    }
}
