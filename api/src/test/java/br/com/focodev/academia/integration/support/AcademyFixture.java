package br.com.focodev.academia.integration.support;

import br.com.focodev.academia.domain.Academy;
import br.com.focodev.academia.domain.User;
import br.com.focodev.academia.domain.UserRole;
import br.com.focodev.academia.repository.AcademyRepository;
import br.com.focodev.academia.repository.UserRepository;
import br.com.focodev.academia.security.AuthUser;
import br.com.focodev.academia.security.JwtService;
import org.springframework.security.crypto.password.PasswordEncoder;

import java.util.UUID;

public record AcademyFixture(
        Academy academy,
        User instructor,
        User student,
        String instructorToken,
        String studentToken
) {
    public static AcademyFixture create(
            AcademyRepository academyRepository,
            UserRepository userRepository,
            PasswordEncoder passwordEncoder,
            JwtService jwtService
    ) {
        String suffix = UUID.randomUUID().toString().substring(0, 8);

        Academy academy = new Academy();
        academy.setName("Academia Teste " + suffix);
        academy.setSlug("academia-teste-" + suffix);
        academy.setDeviceLimitPerUser(3);
        academyRepository.saveAndFlush(academy);

        User instructor = new User();
        instructor.setEmail("instrutor-" + suffix + "@test.com");
        instructor.setName("Instrutor " + suffix);
        instructor.setPasswordHash(passwordEncoder.encode("senha123"));
        instructor.setRole(UserRole.INSTRUTOR);
        instructor.setAcademy(academy);
        userRepository.saveAndFlush(instructor);

        User student = new User();
        student.setEmail("aluno-" + suffix + "@test.com");
        student.setName("Aluno " + suffix);
        student.setPasswordHash(passwordEncoder.encode("senha123"));
        student.setRole(UserRole.ALUNO);
        student.setAcademy(academy);
        student.setInstructor(instructor);
        userRepository.saveAndFlush(student);

        String instructorToken = jwtService.generateToken(new AuthUser(instructor));
        String studentToken = jwtService.generateToken(new AuthUser(student));

        return new AcademyFixture(academy, instructor, student, instructorToken, studentToken);
    }
}
