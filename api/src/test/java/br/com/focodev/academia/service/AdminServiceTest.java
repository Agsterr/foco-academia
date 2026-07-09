package br.com.focodev.academia.service;

import br.com.focodev.academia.domain.*;
import br.com.focodev.academia.dto.*;
import br.com.focodev.academia.exception.ApiException;
import br.com.focodev.academia.repository.AcademyRepository;
import br.com.focodev.academia.repository.DeviceSessionRepository;
import br.com.focodev.academia.repository.UserRepository;
import org.junit.jupiter.api.BeforeEach;
import org.junit.jupiter.api.Test;
import org.junit.jupiter.api.extension.ExtendWith;
import org.mockito.ArgumentCaptor;
import org.mockito.InjectMocks;
import org.mockito.Mock;
import org.mockito.junit.jupiter.MockitoExtension;
import org.springframework.security.crypto.password.PasswordEncoder;

import java.time.Instant;
import java.util.List;
import java.util.Optional;
import java.util.UUID;

import static org.junit.jupiter.api.Assertions.*;
import static org.mockito.ArgumentMatchers.*;
import static org.mockito.Mockito.*;

@ExtendWith(MockitoExtension.class)
class AdminServiceTest {

    @Mock AcademyRepository academyRepository;
    @Mock UserRepository userRepository;
    @Mock DeviceSessionRepository deviceSessionRepository;
    @Mock PasswordEncoder passwordEncoder;

    @InjectMocks AdminService adminService;

    private UUID academyId;
    private Academy academy;

    @BeforeEach
    void setUp() {
        academyId = UUID.randomUUID();
        academy = new Academy();
        academy.setId(academyId);
        academy.setName("Academia Teste");
        academy.setSlug("academia-teste");
        academy.setDeviceLimitPerUser(3);
        academy.setCreatedAt(Instant.now());
    }

    @Test
    void dashboard_returnsCounts() {
        when(academyRepository.count()).thenReturn(2L);
        when(academyRepository.countByActiveTrue()).thenReturn(1L);
        when(userRepository.findByRoleAndActiveTrueOrderByNameAsc(UserRole.INSTRUTOR)).thenReturn(List.of(new User(), new User()));
        when(userRepository.findByRoleAndActiveTrueOrderByNameAsc(UserRole.ALUNO)).thenReturn(List.of(new User()));

        AdminDashboardResponse response = adminService.dashboard();

        assertEquals(2, response.totalAcademies());
        assertEquals(1, response.activeAcademies());
        assertEquals(2, response.totalInstructors());
        assertEquals(1, response.totalStudents());
    }

    @Test
    void createAcademy_generatesSlugFromNameWhenMissing() {
        when(userRepository.existsByEmailIgnoreCase("instrutor@test.com")).thenReturn(false);
        when(academyRepository.existsBySlugIgnoreCase(anyString())).thenReturn(false);
        when(academyRepository.save(any(Academy.class))).thenAnswer(inv -> {
            Academy saved = inv.getArgument(0);
            saved.setId(academyId);
            return saved;
        });
        when(passwordEncoder.encode("senha123")).thenReturn("hash");
        when(userRepository.countByAcademyIdAndRole(academyId, UserRole.INSTRUTOR)).thenReturn(1L);
        when(userRepository.countByAcademyIdAndRole(academyId, UserRole.ALUNO)).thenReturn(0L);

        CreateAcademyRequest request = new CreateAcademyRequest(
                "Academia Teste", null, 3,
                "Instrutor", "instrutor@test.com", "senha123", null
        );

        AcademyResponse response = adminService.createAcademy(request);

        assertEquals("academia-teste", response.slug());
        verify(userRepository).save(any(User.class));
    }

    @Test
    void createAcademy_usesCustomSlugWhenProvided() {
        when(userRepository.existsByEmailIgnoreCase("instrutor@test.com")).thenReturn(false);
        when(academyRepository.existsBySlugIgnoreCase("codigo-custom")).thenReturn(false);
        when(academyRepository.save(any(Academy.class))).thenAnswer(inv -> {
            Academy saved = inv.getArgument(0);
            saved.setId(academyId);
            saved.setSlug("codigo-custom");
            return saved;
        });
        when(passwordEncoder.encode(anyString())).thenReturn("hash");
        when(userRepository.countByAcademyIdAndRole(academyId, UserRole.INSTRUTOR)).thenReturn(1L);
        when(userRepository.countByAcademyIdAndRole(academyId, UserRole.ALUNO)).thenReturn(0L);

        AcademyResponse response = adminService.createAcademy(new CreateAcademyRequest(
                "Academia Teste", "codigo-custom", 3,
                "Instrutor", "instrutor@test.com", "senha123", "11999999999"
        ));

        assertEquals("codigo-custom", response.slug());
    }

    @Test
    void createAcademy_rejectsDuplicateInstructorEmail() {
        when(userRepository.existsByEmailIgnoreCase("dup@test.com")).thenReturn(true);

        assertThrows(ApiException.class, () -> adminService.createAcademy(new CreateAcademyRequest(
                "Academia", null, 3, "Nome", "dup@test.com", "senha123", null
        )));
    }

    @Test
    void getAcademy_notFound() {
        when(academyRepository.findById(academyId)).thenReturn(Optional.empty());
        assertThrows(ApiException.class, () -> adminService.getAcademy(academyId));
    }

    @Test
    void updateAcademy_updatesFields() {
        when(academyRepository.findById(academyId)).thenReturn(Optional.of(academy));
        when(academyRepository.save(academy)).thenReturn(academy);
        when(userRepository.countByAcademyIdAndRole(academyId, UserRole.INSTRUTOR)).thenReturn(1L);
        when(userRepository.countByAcademyIdAndRole(academyId, UserRole.ALUNO)).thenReturn(2L);

        AcademyResponse response = adminService.updateAcademy(academyId,
                new UpdateAcademyRequest("Novo Nome", 5, false));

        assertEquals("Novo Nome", response.name());
        assertEquals(5, response.deviceLimitPerUser());
        assertFalse(response.active());
    }

    @Test
    void createInstructor_success() {
        when(academyRepository.findById(academyId)).thenReturn(Optional.of(academy));
        when(userRepository.existsByEmailIgnoreCase("novo@test.com")).thenReturn(false);
        when(passwordEncoder.encode("senha123")).thenReturn("hash");
        when(deviceSessionRepository.countByUserId(any())).thenReturn(0L);
        when(userRepository.save(any(User.class))).thenAnswer(inv -> {
            User user = inv.getArgument(0);
            user.setId(UUID.randomUUID());
            return user;
        });

        AdminUserResponse response = adminService.createInstructor(academyId,
                new CreateAcademyInstructorRequest("Novo", "novo@test.com", "senha123", null));

        assertEquals("novo@test.com", response.email());
        assertEquals(UserRole.INSTRUTOR, response.role());
    }

    @Test
    void createStudent_instructorNotFound() {
        UUID instructorId = UUID.randomUUID();
        when(academyRepository.findById(academyId)).thenReturn(Optional.of(academy));
        when(userRepository.existsByEmailIgnoreCase("aluno@test.com")).thenReturn(false);
        when(userRepository.findById(instructorId)).thenReturn(Optional.empty());

        assertThrows(ApiException.class, () -> adminService.createStudent(academyId,
                new CreateAcademyStudentRequest("Aluno", "aluno@test.com", "senha123", null, instructorId)));
    }

    @Test
    void createStudent_instructorWrongRole() {
        UUID instructorId = UUID.randomUUID();
        User wrong = new User();
        wrong.setId(instructorId);
        wrong.setRole(UserRole.ALUNO);
        wrong.setAcademy(academy);

        when(academyRepository.findById(academyId)).thenReturn(Optional.of(academy));
        when(userRepository.existsByEmailIgnoreCase("aluno@test.com")).thenReturn(false);
        when(userRepository.findById(instructorId)).thenReturn(Optional.of(wrong));

        assertThrows(ApiException.class, () -> adminService.createStudent(academyId,
                new CreateAcademyStudentRequest("Aluno", "aluno@test.com", "senha123", null, instructorId)));
    }

    @Test
    void createStudent_rejectsForeignInstructor() {
        UUID instructorId = UUID.randomUUID();
        User instructor = new User();
        instructor.setId(instructorId);
        instructor.setRole(UserRole.INSTRUTOR);
        Academy other = new Academy();
        other.setId(UUID.randomUUID());
        instructor.setAcademy(other);

        when(academyRepository.findById(academyId)).thenReturn(Optional.of(academy));
        when(userRepository.existsByEmailIgnoreCase("aluno@test.com")).thenReturn(false);
        when(userRepository.findById(instructorId)).thenReturn(Optional.of(instructor));

        assertThrows(ApiException.class, () -> adminService.createStudent(academyId,
                new CreateAcademyStudentRequest("Aluno", "aluno@test.com", "senha123", null, instructorId)));
    }

    @Test
    void listAcademies_andGetAcademy() {
        when(academyRepository.findAllByOrderByNameAsc()).thenReturn(List.of(academy));
        when(userRepository.countByAcademyIdAndRole(academyId, UserRole.INSTRUTOR)).thenReturn(1L);
        when(userRepository.countByAcademyIdAndRole(academyId, UserRole.ALUNO)).thenReturn(1L);
        when(academyRepository.findById(academyId)).thenReturn(Optional.of(academy));

        assertEquals(1, adminService.listAcademies().size());
        assertEquals("Academia Teste", adminService.getAcademy(academyId).name());
    }

    @Test
    void listAcademyUsers_returnsUsers() {
        User instructor = new User();
        instructor.setId(UUID.randomUUID());
        instructor.setEmail("i@test.com");
        instructor.setName("Instrutor");
        instructor.setRole(UserRole.INSTRUTOR);
        instructor.setAcademy(academy);

        when(academyRepository.findById(academyId)).thenReturn(Optional.of(academy));
        when(userRepository.findByAcademyIdOrderByNameAsc(academyId)).thenReturn(List.of(instructor));
        when(deviceSessionRepository.countByUserId(instructor.getId())).thenReturn(0L);

        AdminUserResponse response = adminService.listAcademyUsers(academyId).get(0);

        assertEquals(1, adminService.listAcademyUsers(academyId).size());
        assertEquals("Instrutor", response.name());
        assertEquals(academyId, response.academyId());
        assertEquals("Academia Teste", response.academyName());
        assertEquals(0, response.deviceCount());
    }

    @Test
    void createInstructor_rejectsDuplicateEmail() {
        when(academyRepository.findById(academyId)).thenReturn(Optional.of(academy));
        when(userRepository.existsByEmailIgnoreCase("dup@test.com")).thenReturn(true);

        assertThrows(ApiException.class, () -> adminService.createInstructor(academyId,
                new CreateAcademyInstructorRequest("Nome", "dup@test.com", "senha123", null)));
    }

    @Test
    void createStudent_success() {
        UUID instructorId = UUID.randomUUID();
        User instructor = new User();
        instructor.setId(instructorId);
        instructor.setRole(UserRole.INSTRUTOR);
        instructor.setAcademy(academy);

        when(academyRepository.findById(academyId)).thenReturn(Optional.of(academy));
        when(userRepository.existsByEmailIgnoreCase("aluno@test.com")).thenReturn(false);
        when(userRepository.findById(instructorId)).thenReturn(Optional.of(instructor));
        when(passwordEncoder.encode("senha123")).thenReturn("hash");
        when(deviceSessionRepository.countByUserId(any())).thenReturn(0L);
        when(userRepository.save(any(User.class))).thenAnswer(inv -> {
            User saved = inv.getArgument(0);
            saved.setId(UUID.randomUUID());
            return saved;
        });

        AdminUserResponse response = adminService.createStudent(academyId,
                new CreateAcademyStudentRequest("Aluno", "aluno@test.com", "senha123", null, instructorId));

        assertEquals(UserRole.ALUNO, response.role());
    }

    @Test
    void createStudent_rejectsDuplicateEmail() {
        when(academyRepository.findById(academyId)).thenReturn(Optional.of(academy));
        when(userRepository.existsByEmailIgnoreCase("dup@test.com")).thenReturn(true);

        assertThrows(ApiException.class, () -> adminService.createStudent(academyId,
                new CreateAcademyStudentRequest("Aluno", "dup@test.com", "senha123", null, UUID.randomUUID())));
    }

    @Test
    void createStudent_instructorWithoutAcademy() {
        UUID instructorId = UUID.randomUUID();
        User instructor = new User();
        instructor.setId(instructorId);
        instructor.setRole(UserRole.INSTRUTOR);
        instructor.setAcademy(null);

        when(academyRepository.findById(academyId)).thenReturn(Optional.of(academy));
        when(userRepository.existsByEmailIgnoreCase("aluno@test.com")).thenReturn(false);
        when(userRepository.findById(instructorId)).thenReturn(Optional.of(instructor));

        assertThrows(ApiException.class, () -> adminService.createStudent(academyId,
                new CreateAcademyStudentRequest("Aluno", "aluno@test.com", "senha123", null, instructorId)));
    }

    @Test
    void updateAcademy_ignoresNullFields() {
        when(academyRepository.findById(academyId)).thenReturn(Optional.of(academy));
        when(academyRepository.save(academy)).thenReturn(academy);
        when(userRepository.countByAcademyIdAndRole(academyId, UserRole.INSTRUTOR)).thenReturn(0L);
        when(userRepository.countByAcademyIdAndRole(academyId, UserRole.ALUNO)).thenReturn(0L);

        AcademyResponse response = adminService.updateAcademy(academyId,
                new UpdateAcademyRequest(null, null, null));

        assertEquals("Academia Teste", response.name());
    }

    @Test
    void toAdminUser_includesInstructorAndAcademyInfo() {
        UUID instructorId = UUID.randomUUID();
        User instructor = new User();
        instructor.setId(instructorId);
        instructor.setRole(UserRole.INSTRUTOR);
        instructor.setAcademy(academy);

        User student = new User();
        student.setId(UUID.randomUUID());
        student.setEmail("aluno@test.com");
        student.setName("Aluno");
        student.setRole(UserRole.ALUNO);
        student.setAcademy(academy);
        student.setInstructor(instructor);
        student.setLastLoginAt(Instant.now());

        when(academyRepository.findById(academyId)).thenReturn(Optional.of(academy));
        when(userRepository.findByAcademyIdOrderByNameAsc(academyId)).thenReturn(List.of(student));
        when(deviceSessionRepository.countByUserId(student.getId())).thenReturn(2L);

        AdminUserResponse response = adminService.listAcademyUsers(academyId).get(0);

        assertEquals(instructorId, response.instructorId());
        assertEquals(academyId, response.academyId());
        assertEquals(2, response.deviceCount());
    }

    @Test
    void listUserDevices_userNotFound() {
        UUID userId = UUID.randomUUID();
        when(userRepository.findById(userId)).thenReturn(Optional.empty());
        assertThrows(ApiException.class, () -> adminService.listUserDevices(userId));
    }

    @Test
    void listUserDevices_andRemoveDevice() {
        UUID userId = UUID.randomUUID();
        User user = new User();
        user.setId(userId);
        DeviceSession session = new DeviceSession();
        session.setId(UUID.randomUUID());
        session.setDeviceId("dev-1");
        session.setLastSeenAt(Instant.now());

        when(userRepository.findById(userId)).thenReturn(Optional.of(user));
        when(deviceSessionRepository.findByUserIdOrderByLastSeenAtDesc(userId)).thenReturn(List.of(session));

        assertEquals(1, adminService.listUserDevices(userId).size());

        adminService.removeUserDevice(userId, "dev-1");
        verify(deviceSessionRepository).deleteByUserIdAndDeviceId(userId, "dev-1");
    }
}
