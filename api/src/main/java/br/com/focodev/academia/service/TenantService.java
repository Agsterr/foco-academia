package br.com.focodev.academia.service;

import br.com.focodev.academia.domain.Academy;
import br.com.focodev.academia.domain.User;
import br.com.focodev.academia.domain.UserRole;
import br.com.focodev.academia.exception.ApiException;
import br.com.focodev.academia.repository.AcademyRepository;
import br.com.focodev.academia.repository.UserRepository;
import br.com.focodev.academia.security.AuthUser;
import lombok.RequiredArgsConstructor;
import org.springframework.stereotype.Service;

import java.util.UUID;

@Service
@RequiredArgsConstructor
public class TenantService {

    private final AcademyRepository academyRepository;
    private final UserRepository userRepository;

    public Academy requireActiveAcademyBySlug(String slug) {
        if (slug == null || slug.isBlank()) {
            throw new ApiException("Código da academia é obrigatório");
        }
        Academy academy = academyRepository.findBySlugIgnoreCase(slug.trim())
                .orElseThrow(() -> new ApiException("Academia não encontrada"));
        if (!academy.isActive()) {
            throw new ApiException("Academia desativada. Contate o administrador.");
        }
        if (academy.isAppBlocked()) {
            throw new ApiException("Aplicativo bloqueado para esta academia. Contate o administrador.");
        }
        return academy;
    }

    public void requireUserBelongsToAcademy(User user, Academy academy) {
        if (user.getAcademy() == null || !user.getAcademy().getId().equals(academy.getId())) {
            throw new ApiException("Usuário não pertence a esta academia");
        }
    }

    public void requireSameAcademy(User first, User second) {
        if (first.getAcademy() == null || second.getAcademy() == null
                || !first.getAcademy().getId().equals(second.getAcademy().getId())) {
            throw new ApiException("Usuários de academias diferentes");
        }
    }

    public User requireInstructor(AuthUser authUser) {
        User instructor = userRepository.findById(authUser.getId())
                .orElseThrow(() -> new ApiException("Instrutor não encontrado"));
        if (instructor.getRole() != UserRole.INSTRUTOR) {
            throw new ApiException("Acesso negado");
        }
        requireActiveAcademy(instructor);
        return instructor;
    }

    public void requireActiveAcademy(User user) {
        if (user.getRole() == UserRole.ADMIN) {
            return;
        }
        if (user.getAcademy() == null) {
            throw new ApiException("Usuário sem academia vinculada");
        }
        if (!user.getAcademy().isActive()) {
            throw new ApiException("Academia desativada. Contate o administrador.");
        }
        if (user.getAcademy().isAppBlocked()) {
            throw new ApiException("Aplicativo bloqueado para esta academia. Contate o administrador.");
        }
    }

    public void requireStudentInInstructorAcademy(User instructor, User student) {
        if (student.getRole() != UserRole.ALUNO) {
            throw new ApiException("Usuário não é aluno");
        }
        requireSameAcademy(instructor, student);
        if (student.getInstructor() == null || !student.getInstructor().getId().equals(instructor.getId())) {
            throw new ApiException("Aluno não pertence a este instrutor");
        }
    }

    public Academy getAcademy(UUID academyId) {
        return academyRepository.findById(academyId)
                .orElseThrow(() -> new ApiException("Academia não encontrada"));
    }
}
