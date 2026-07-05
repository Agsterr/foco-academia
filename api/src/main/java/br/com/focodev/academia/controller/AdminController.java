package br.com.focodev.academia.controller;

import br.com.focodev.academia.dto.*;
import br.com.focodev.academia.service.AdminService;
import jakarta.validation.Valid;
import lombok.RequiredArgsConstructor;
import org.springframework.web.bind.annotation.*;

import java.util.List;
import java.util.UUID;

@RestController
@RequestMapping("/api/admin")
@RequiredArgsConstructor
public class AdminController {

    private final AdminService adminService;

    @GetMapping("/dashboard")
    public AdminDashboardResponse dashboard() {
        return adminService.dashboard();
    }

    @GetMapping("/academies")
    public List<AcademyResponse> listAcademies() {
        return adminService.listAcademies();
    }

    @GetMapping("/academies/{id}")
    public AcademyResponse getAcademy(@PathVariable UUID id) {
        return adminService.getAcademy(id);
    }

    @PostMapping("/academies")
    public AcademyResponse createAcademy(@Valid @RequestBody CreateAcademyRequest request) {
        return adminService.createAcademy(request);
    }

    @PatchMapping("/academies/{id}")
    public AcademyResponse updateAcademy(
            @PathVariable UUID id,
            @Valid @RequestBody UpdateAcademyRequest request
    ) {
        return adminService.updateAcademy(id, request);
    }

    @GetMapping("/academies/{id}/users")
    public List<AdminUserResponse> listUsers(@PathVariable UUID id) {
        return adminService.listAcademyUsers(id);
    }

    @PostMapping("/academies/{id}/instructors")
    public AdminUserResponse createInstructor(
            @PathVariable UUID id,
            @Valid @RequestBody CreateAcademyInstructorRequest request
    ) {
        return adminService.createInstructor(id, request);
    }

    @PostMapping("/academies/{id}/students")
    public AdminUserResponse createStudent(
            @PathVariable UUID id,
            @Valid @RequestBody CreateAcademyStudentRequest request
    ) {
        return adminService.createStudent(id, request);
    }

    @GetMapping("/users/{userId}/devices")
    public List<DeviceSessionResponse> listDevices(@PathVariable UUID userId) {
        return adminService.listUserDevices(userId);
    }

    @DeleteMapping("/users/{userId}/devices/{deviceId}")
    public void removeDevice(@PathVariable UUID userId, @PathVariable String deviceId) {
        adminService.removeUserDevice(userId, deviceId);
    }
}
