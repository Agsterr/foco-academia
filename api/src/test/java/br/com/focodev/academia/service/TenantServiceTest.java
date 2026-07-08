package br.com.focodev.academia.service;

import br.com.focodev.academia.domain.Academy;
import br.com.focodev.academia.domain.User;
import br.com.focodev.academia.domain.UserRole;
import br.com.focodev.academia.exception.ApiException;
import br.com.focodev.academia.repository.AcademyRepository;
import br.com.focodev.academia.repository.UserRepository;
import br.com.focodev.academia.security.AuthUser;
import org.junit.jupiter.api.BeforeEach;
import org.junit.jupiter.api.Test;
import org.junit.jupiter.api.extension.ExtendWith;
import org.mockito.InjectMocks;
import org.mockito.Mock;
import org.mockito.junit.jupiter.MockitoExtension;

import java.util.Optional;
import java.util.UUID;

import static org.junit.jupiter.api.Assertions.*;
import static org.mockito.Mockito.when;

@ExtendWith(MockitoExtension.class)
class TenantServiceTest {

    @Mock AcademyRepository academyRepository;
    @Mock UserRepository userRepository;

    @InjectMocks TenantService tenantService;

    private Academy academy;
    private User user;

    @BeforeEach
    void setUp() {
        academy = new Academy();
        academy.setId(UUID.randomUUID());
        academy.setSlug("academia-demo");
        academy.setActive(true);

        user = new User();
        user.setId(UUID.randomUUID());
        user.setRole(UserRole.INSTRUTOR);
        user.setAcademy(academy);
    }

    @Test
    void requireActiveAcademyBySlug_success() {
        when(academyRepository.findBySlugIgnoreCase("academia-demo")).thenReturn(Optional.of(academy));
        assertEquals(academy, tenantService.requireActiveAcademyBySlug("academia-demo"));
    }

    @Test
    void requireActiveAcademyBySlug_requiresCode() {
        assertThrows(ApiException.class, () -> tenantService.requireActiveAcademyBySlug(" "));
    }

    @Test
    void requireActiveAcademyBySlug_notFound() {
        when(academyRepository.findBySlugIgnoreCase("x")).thenReturn(Optional.empty());
        assertThrows(ApiException.class, () -> tenantService.requireActiveAcademyBySlug("x"));
    }

    @Test
    void requireActiveAcademyBySlug_inactive() {
        academy.setActive(false);
        when(academyRepository.findBySlugIgnoreCase("academia-demo")).thenReturn(Optional.of(academy));
        assertThrows(ApiException.class, () -> tenantService.requireActiveAcademyBySlug("academia-demo"));
    }

    @Test
    void requireActiveAcademyBySlug_rejectsNull() {
        assertThrows(ApiException.class, () -> tenantService.requireActiveAcademyBySlug(null));
    }

    @Test
    void requireUserBelongsToAcademy_nullAcademy() {
        user.setAcademy(null);
        assertThrows(ApiException.class, () -> tenantService.requireUserBelongsToAcademy(user, academy));
    }

    @Test
    void requireUserBelongsToAcademy_mismatch() {
        Academy other = new Academy();
        other.setId(UUID.randomUUID());
        user.setAcademy(other);
        assertThrows(ApiException.class, () -> tenantService.requireUserBelongsToAcademy(user, academy));
    }

    @Test
    void requireInstructor_success() {
        AuthUser authUser = new AuthUser(user);
        when(userRepository.findById(user.getId())).thenReturn(Optional.of(user));
        assertEquals(user, tenantService.requireInstructor(authUser));
    }

    @Test
    void requireInstructor_deniesStudent() {
        user.setRole(UserRole.ALUNO);
        when(userRepository.findById(user.getId())).thenReturn(Optional.of(user));
        assertThrows(ApiException.class, () -> tenantService.requireInstructor(new AuthUser(user)));
    }

    @Test
    void requireActiveAcademy_adminBypass() {
        user.setRole(UserRole.ADMIN);
        user.setAcademy(null);
        assertDoesNotThrow(() -> tenantService.requireActiveAcademy(user));
    }

    @Test
    void requireUserBelongsToAcademy_success() {
        assertDoesNotThrow(() -> tenantService.requireUserBelongsToAcademy(user, academy));
    }

    @Test
    void requireSameAcademy_mismatch() {
        User other = new User();
        other.setAcademy(academy);
        User outsider = new User();
        Academy otherAcademy = new Academy();
        otherAcademy.setId(UUID.randomUUID());
        outsider.setAcademy(otherAcademy);
        assertThrows(ApiException.class, () -> tenantService.requireSameAcademy(other, outsider));
    }

    @Test
    void requireStudentInInstructorAcademy_success() {
        User student = new User();
        student.setRole(UserRole.ALUNO);
        student.setAcademy(academy);
        student.setInstructor(user);
        assertDoesNotThrow(() -> tenantService.requireStudentInInstructorAcademy(user, student));
    }

    @Test
    void requireStudentInInstructorAcademy_notStudent() {
        User notStudent = new User();
        notStudent.setRole(UserRole.INSTRUTOR);
        notStudent.setAcademy(academy);
        assertThrows(ApiException.class, () -> tenantService.requireStudentInInstructorAcademy(user, notStudent));
    }

    @Test
    void getAcademy_notFound() {
        UUID id = UUID.randomUUID();
        when(academyRepository.findById(id)).thenReturn(Optional.empty());
        assertThrows(ApiException.class, () -> tenantService.getAcademy(id));
    }

    @Test
    void requireInstructor_notFound() {
        AuthUser authUser = new AuthUser(user);
        when(userRepository.findById(user.getId())).thenReturn(Optional.empty());
        assertThrows(ApiException.class, () -> tenantService.requireInstructor(authUser));
    }

    @Test
    void requireActiveAcademy_missingAcademy() {
        user.setAcademy(null);
        assertThrows(ApiException.class, () -> tenantService.requireActiveAcademy(user));
    }

    @Test
    void requireActiveAcademy_inactiveAcademy() {
        academy.setActive(false);
        user.setAcademy(academy);
        assertThrows(ApiException.class, () -> tenantService.requireActiveAcademy(user));
    }

    @Test
    void requireStudentInInstructorAcademy_wrongInstructor() {
        User student = new User();
        student.setRole(UserRole.ALUNO);
        student.setAcademy(academy);
        User otherInstructor = new User();
        otherInstructor.setId(UUID.randomUUID());
        student.setInstructor(otherInstructor);

        assertThrows(ApiException.class, () -> tenantService.requireStudentInInstructorAcademy(user, student));
    }

    @Test
    void getAcademy_success() {
        UUID id = academy.getId();
        when(academyRepository.findById(id)).thenReturn(Optional.of(academy));
        assertEquals(academy, tenantService.getAcademy(id));
    }

    @Test
    void requireSameAcademy_success() {
        User other = new User();
        other.setAcademy(academy);
        assertDoesNotThrow(() -> tenantService.requireSameAcademy(user, other));
    }

    @Test
    void requireStudentInInstructorAcademy_wrongAcademy() {
        User student = new User();
        student.setRole(UserRole.ALUNO);
        Academy otherAcademy = new Academy();
        otherAcademy.setId(UUID.randomUUID());
        student.setAcademy(otherAcademy);
        student.setInstructor(user);

        assertThrows(ApiException.class, () -> tenantService.requireStudentInInstructorAcademy(user, student));
    }

    @Test
    void requireStudentInInstructorAcademy_missingInstructor() {
        User student = new User();
        student.setRole(UserRole.ALUNO);
        student.setAcademy(academy);
        student.setInstructor(null);

        assertThrows(ApiException.class, () -> tenantService.requireStudentInInstructorAcademy(user, student));
    }

    @Test
    void requireSameAcademy_secondUserNullAcademy() {
        User other = new User();
        other.setAcademy(null);
        assertThrows(ApiException.class, () -> tenantService.requireSameAcademy(user, other));
    }

    @Test
    void requireSameAcademy_nullAcademy() {
        user.setAcademy(null);
        User other = new User();
        other.setAcademy(academy);
        assertThrows(ApiException.class, () -> tenantService.requireSameAcademy(user, other));
    }
}
