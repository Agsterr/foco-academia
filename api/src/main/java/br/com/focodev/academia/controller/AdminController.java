package br.com.focodev.academia.controller;

import br.com.focodev.academia.domain.AppRelease;
import br.com.focodev.academia.dto.*;
import br.com.focodev.academia.service.AdminService;
import br.com.focodev.academia.service.AppReleaseService;
import jakarta.validation.Valid;
import lombok.RequiredArgsConstructor;
import org.springframework.core.io.Resource;
import org.springframework.http.HttpHeaders;
import org.springframework.http.MediaType;
import org.springframework.http.ResponseEntity;
import org.springframework.web.bind.annotation.*;
import org.springframework.web.multipart.MultipartFile;

import java.util.List;
import java.util.UUID;

@RestController
@RequestMapping("/api/admin")
@RequiredArgsConstructor
public class AdminController {

    private final AdminService adminService;
    private final AppReleaseService appReleaseService;
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

    @GetMapping("/users")
    public List<AdminUserResponse> listAllUsers() {
        return adminService.listAllUsers();
    }

    @PatchMapping("/users/{userId}")
    public AdminUserResponse updateUser(
            @PathVariable UUID userId,
            @Valid @RequestBody UpdateUserRequest request
    ) {
        return adminService.updateUser(userId, request);
    }

    @GetMapping("/releases")
    public List<AppReleaseDtos.AdminAppReleaseResponse> listReleases() {
        return appReleaseService.listActiveReleases();
    }

    @GetMapping("/releases/connected-devices")
    public List<AppReleaseDtos.AdminConnectedDeviceResponse> listConnectedDevices() {
        return appReleaseService.listConnectedDevices();
    }

    @PatchMapping("/releases/{id}/force-update")
    public AppReleaseDtos.AdminAppReleaseResponse updateForceUpdate(
            @PathVariable UUID id,
            @Valid @RequestBody AppReleaseDtos.UpdateForceReleaseRequest request
    ) {
        return appReleaseService.updateForceUpdate(id, request.forceUpdate());
    }

    @GetMapping("/releases/{id}/download")
    public ResponseEntity<Resource> downloadRelease(@PathVariable UUID id) {
        AppRelease release = appReleaseService.getReleaseEntity(id);
        Resource resource = appReleaseService.loadApkResource(release);
        return ResponseEntity.ok()
                .header(HttpHeaders.CONTENT_DISPOSITION, "attachment; filename=\"" + release.getFileName() + "\"")
                .contentType(MediaType.APPLICATION_OCTET_STREAM)
                .contentLength(release.getFileSizeBytes())
                .body(resource);
    }

    @PostMapping(value = "/releases", consumes = MediaType.MULTIPART_FORM_DATA_VALUE)
    public AppReleaseDtos.AdminAppReleaseResponse uploadRelease(
            @RequestPart("file") MultipartFile file,
            @RequestPart("versionName") String versionName,
            @RequestPart("versionCode") String versionCodeRaw,
            @RequestParam(required = false) String releaseNotes,
            @RequestParam(defaultValue = "false") boolean forceUpdate
    ) {
        return appReleaseService.publishRelease(
                file,
                versionName,
                Integer.parseInt(versionCodeRaw.trim()),
                releaseNotes,
                forceUpdate
        );
    }
}