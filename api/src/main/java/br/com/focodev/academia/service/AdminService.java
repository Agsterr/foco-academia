package br.com.focodev.academia.service;

import br.com.focodev.academia.domain.*;
import br.com.focodev.academia.dto.*;
import br.com.focodev.academia.exception.ApiException;
import br.com.focodev.academia.repository.AcademyRepository;
import br.com.focodev.academia.repository.DeviceSessionRepository;
import br.com.focodev.academia.repository.UserRepository;
import br.com.focodev.academia.security.AuthUser;
import br.com.focodev.academia.util.SlugHelper;
import lombok.RequiredArgsConstructor;
import org.springframework.security.crypto.password.PasswordEncoder;
import org.springframework.stereotype.Service;
import org.springframework.transaction.annotation.Transactional;

import java.util.List;
import java.util.UUID;

@Service
@RequiredArgsConstructor
public class AdminService {

    private final AcademyRepository academyRepository;
    private final UserRepository userRepository;
    private final DeviceSessionRepository deviceSessionRepository;
    private final PasswordEncoder passwordEncoder;

    public AdminDashboardResponse dashboard() {
        long academies = academyRepository.count();
        long active = academyRepository.countByActiveTrue();
        long instructors = userRepository.findByRoleAndActiveTrueOrderByNameAsc(UserRole.INSTRUTOR).size();
        long students = userRepository.findByRoleAndActiveTrueOrderByNameAsc(UserRole.ALUNO).size();
        return new AdminDashboardResponse(academies, active, instructors, students);
    }

    public List<AcademyResponse> listAcademies() {
        return academyRepository.findAllByOrderByNameAsc().stream()
                .map(this::toAcademyResponse)
                .toList();
    }

    public AcademyResponse getAcademy(UUID id) {
        Academy academy = getAcademyEntity(id);
        return toAcademyResponse(academy);
    }

    @Transactional
    public AcademyResponse createAcademy(CreateAcademyRequest request) {
        if (userRepository.existsByEmailIgnoreCase(request.instructorEmail())) {
            throw new ApiException("E-mail do instrutor já cadastrado");
        }

        Academy academy = new Academy();
        academy.setName(request.name().trim());
        String slugBase = request.slug() != null && !request.slug().isBlank()
                ? request.slug().trim()
                : request.name();
        academy.setSlug(SlugHelper.unique(slugBase, academyRepository::existsBySlugIgnoreCase));
        academy.setDeviceLimitPerUser(request.deviceLimitPerUser());
        academyRepository.save(academy);

        User instructor = new User();
        instructor.setEmail(request.instructorEmail().trim().toLowerCase());
        instructor.setPasswordHash(passwordEncoder.encode(request.instructorPassword()));
        instructor.setName(request.instructorName().trim());
        instructor.setPhone(request.instructorPhone());
        instructor.setRole(UserRole.INSTRUTOR);
        instructor.setAcademy(academy);
        userRepository.save(instructor);

        return toAcademyResponse(academy);
    }

    @Transactional
    public AcademyResponse updateAcademy(UUID id, UpdateAcademyRequest request) {
        Academy academy = getAcademyEntity(id);
        if (request.name() != null && !request.name().isBlank()) {
            academy.setName(request.name().trim());
        }
        if (request.deviceLimitPerUser() != null) {
            academy.setDeviceLimitPerUser(request.deviceLimitPerUser());
        }
        if (request.active() != null) {
            academy.setActive(request.active());
        }
        return toAcademyResponse(academyRepository.save(academy));
    }

    public List<AdminUserResponse> listAcademyUsers(UUID academyId) {
        getAcademyEntity(academyId);
        return userRepository.findByAcademyIdOrderByNameAsc(academyId).stream()
                .map(this::toAdminUser)
                .toList();
    }

    @Transactional
    public AdminUserResponse createInstructor(UUID academyId, CreateAcademyInstructorRequest request) {
        Academy academy = getAcademyEntity(academyId);
        if (userRepository.existsByEmailIgnoreCase(request.email())) {
            throw new ApiException("E-mail já cadastrado");
        }

        User instructor = new User();
        instructor.setEmail(request.email().trim().toLowerCase());
        instructor.setPasswordHash(passwordEncoder.encode(request.password()));
        instructor.setName(request.name().trim());
        instructor.setPhone(request.phone());
        instructor.setRole(UserRole.INSTRUTOR);
        instructor.setAcademy(academy);
        userRepository.save(instructor);
        return toAdminUser(instructor);
    }

    @Transactional
    public AdminUserResponse createStudent(UUID academyId, CreateAcademyStudentRequest request) {
        Academy academy = getAcademyEntity(academyId);
        if (userRepository.existsByEmailIgnoreCase(request.email())) {
            throw new ApiException("E-mail já cadastrado");
        }

        User instructor = userRepository.findById(request.instructorId())
                .orElseThrow(() -> new ApiException("Instrutor não encontrado"));
        if (instructor.getRole() != UserRole.INSTRUTOR
                || instructor.getAcademy() == null
                || !instructor.getAcademy().getId().equals(academyId)) {
            throw new ApiException("Instrutor não pertence a esta academia");
        }

        User student = new User();
        student.setEmail(request.email().trim().toLowerCase());
        student.setPasswordHash(passwordEncoder.encode(request.password()));
        student.setName(request.name().trim());
        student.setPhone(request.phone());
        student.setRole(UserRole.ALUNO);
        student.setAcademy(academy);
        student.setInstructor(instructor);
        userRepository.save(student);
        return toAdminUser(student);
    }

    public List<DeviceSessionResponse> listUserDevices(UUID userId) {
        User user = userRepository.findById(userId)
                .orElseThrow(() -> new ApiException("Usuário não encontrado"));
        return deviceSessionRepository.findByUserIdOrderByLastSeenAtDesc(user.getId()).stream()
                .map(s -> new DeviceSessionResponse(
                        s.getId(), s.getDeviceId(), s.getDeviceLabel(), s.getLastSeenAt()))
                .toList();
    }

    @Transactional
    public void removeUserDevice(UUID userId, String deviceId) {
        deviceSessionRepository.deleteByUserIdAndDeviceId(userId, deviceId);
    }

    private Academy getAcademyEntity(UUID id) {
        return academyRepository.findById(id)
                .orElseThrow(() -> new ApiException("Academia não encontrada"));
    }

    private AcademyResponse toAcademyResponse(Academy academy) {
        long instructors = userRepository.countByAcademyIdAndRole(academy.getId(), UserRole.INSTRUTOR);
        long students = userRepository.countByAcademyIdAndRole(academy.getId(), UserRole.ALUNO);
        return AcademyResponse.from(academy, instructors, students);
    }

    private AdminUserResponse toAdminUser(User user) {
        long devices = deviceSessionRepository.countByUserId(user.getId());
        return new AdminUserResponse(
                user.getId(),
                user.getEmail(),
                user.getName(),
                user.getPhone(),
                user.getRole(),
                user.getAcademy() != null ? user.getAcademy().getId() : null,
                user.getAcademy() != null ? user.getAcademy().getName() : null,
                user.getInstructor() != null ? user.getInstructor().getId() : null,
                user.getLastLoginAt(),
                devices,
                user.isActive()
        );
    }
}
