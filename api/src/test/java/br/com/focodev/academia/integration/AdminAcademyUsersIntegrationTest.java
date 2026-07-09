package br.com.focodev.academia.integration;

import br.com.focodev.academia.domain.Academy;
import br.com.focodev.academia.domain.User;
import br.com.focodev.academia.domain.UserRole;
import br.com.focodev.academia.dto.AdminUserResponse;
import br.com.focodev.academia.repository.AcademyRepository;
import br.com.focodev.academia.repository.UserRepository;
import br.com.focodev.academia.service.AdminService;
import org.junit.jupiter.api.Test;
import org.springframework.beans.factory.annotation.Autowired;
import org.springframework.boot.test.context.SpringBootTest;
import org.springframework.security.crypto.password.PasswordEncoder;
import org.springframework.test.context.ActiveProfiles;
import org.springframework.transaction.annotation.Propagation;
import org.springframework.transaction.annotation.Transactional;

import java.util.List;

import static org.junit.jupiter.api.Assertions.assertEquals;
import static org.junit.jupiter.api.Assertions.assertNotNull;

/**
 * Regressão: listAcademyUsers acessa academy/instructor (LAZY) em toAdminUser.
 * Sem @Transactional(readOnly) no serviço, este teste falha com LazyInitializationException.
 */
@SpringBootTest
@ActiveProfiles("test")
class AdminAcademyUsersIntegrationTest {

    @Autowired AdminService adminService;
    @Autowired AcademyRepository academyRepository;
    @Autowired UserRepository userRepository;
    @Autowired PasswordEncoder passwordEncoder;

    @Test
    @Transactional(propagation = Propagation.NOT_SUPPORTED)
    void listAcademyUsers_resolvesLazyAcademyAndInstructor() {
        Academy academy = new Academy();
        academy.setName("Academia Lazy Test");
        academy.setSlug("academia-lazy-test");
        academy.setDeviceLimitPerUser(3);
        academyRepository.saveAndFlush(academy);

        User instructor = new User();
        instructor.setEmail("lazy-instructor@test.com");
        instructor.setName("Instrutor Lazy");
        instructor.setPasswordHash(passwordEncoder.encode("senha123"));
        instructor.setRole(UserRole.INSTRUTOR);
        instructor.setAcademy(academy);
        userRepository.saveAndFlush(instructor);

        User student = new User();
        student.setEmail("lazy-student@test.com");
        student.setName("Aluno Lazy");
        student.setPasswordHash(passwordEncoder.encode("senha123"));
        student.setRole(UserRole.ALUNO);
        student.setAcademy(academy);
        student.setInstructor(instructor);
        userRepository.saveAndFlush(student);

        List<AdminUserResponse> users = adminService.listAcademyUsers(academy.getId());

        assertEquals(2, users.size());

        AdminUserResponse instructorResponse = users.stream()
                .filter(u -> u.role() == UserRole.INSTRUTOR)
                .findFirst()
                .orElseThrow();
        assertEquals("Instrutor Lazy", instructorResponse.name());
        assertEquals(academy.getId(), instructorResponse.academyId());
        assertEquals("Academia Lazy Test", instructorResponse.academyName());

        AdminUserResponse studentResponse = users.stream()
                .filter(u -> u.role() == UserRole.ALUNO)
                .findFirst()
                .orElseThrow();
        assertEquals("Aluno Lazy", studentResponse.name());
        assertNotNull(studentResponse.instructorId());
        assertEquals(instructor.getId(), studentResponse.instructorId());
    }
}
