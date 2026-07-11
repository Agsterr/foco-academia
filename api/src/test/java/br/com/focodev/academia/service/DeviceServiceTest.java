package br.com.focodev.academia.service;

import br.com.focodev.academia.domain.Academy;
import br.com.focodev.academia.domain.AppClientType;
import br.com.focodev.academia.domain.DeviceSession;
import br.com.focodev.academia.domain.User;
import br.com.focodev.academia.domain.UserRole;
import br.com.focodev.academia.exception.ApiException;
import br.com.focodev.academia.repository.DeviceSessionRepository;
import org.junit.jupiter.api.BeforeEach;
import org.junit.jupiter.api.Test;
import org.junit.jupiter.api.extension.ExtendWith;
import org.mockito.ArgumentCaptor;
import org.mockito.InjectMocks;
import org.mockito.Mock;
import org.mockito.junit.jupiter.MockitoExtension;

import java.util.Optional;
import java.util.UUID;

import static org.junit.jupiter.api.Assertions.*;
import static org.mockito.ArgumentMatchers.any;
import static org.mockito.Mockito.*;

@ExtendWith(MockitoExtension.class)
class DeviceServiceTest {

    @Mock DeviceSessionRepository deviceSessionRepository;

    @InjectMocks DeviceService deviceService;

    private User user;
    private Academy academy;

    @BeforeEach
    void setUp() {
        academy = new Academy();
        academy.setDeviceLimitPerUser(2);

        user = new User();
        user.setId(UUID.randomUUID());
        user.setRole(UserRole.INSTRUTOR);
        user.setAcademy(academy);
    }

    @Test
    void registerDevice_skipsAdmin() {
        user.setRole(UserRole.ADMIN);
        assertDoesNotThrow(() -> deviceService.registerDevice(user, "dev", "Chrome"));
        verifyNoInteractions(deviceSessionRepository);
    }

    @Test
    void registerDevice_requiresDeviceId() {
        assertThrows(ApiException.class, () -> deviceService.registerDevice(user, " ", null));
    }

    @Test
    void registerDevice_requiresAcademy() {
        user.setAcademy(null);
        assertThrows(ApiException.class, () -> deviceService.registerDevice(user, "dev", null));
    }

    @Test
    void registerDevice_updatesExistingSession() {
        DeviceSession existing = new DeviceSession();
        when(deviceSessionRepository.findByUserIdAndDeviceId(user.getId(), "dev-1")).thenReturn(Optional.of(existing));

        deviceService.registerDevice(user, "dev-1", "Novo label");

        verify(deviceSessionRepository).save(existing);
        assertEquals("Novo label", existing.getDeviceLabel());
    }

    @Test
    void registerDevice_reusesSameEquipmentByLabel() {
        DeviceSession existing = new DeviceSession();
        existing.setDeviceId("old-id");
        existing.setDeviceLabel("Chrome Windows");
        when(deviceSessionRepository.findByUserIdAndDeviceId(user.getId(), "new-id")).thenReturn(Optional.empty());
        when(deviceSessionRepository.findByUserIdAndDeviceLabel(user.getId(), "Chrome Windows"))
                .thenReturn(Optional.of(existing));

        deviceService.registerDevice(user, "new-id", "Chrome Windows");

        verify(deviceSessionRepository).save(existing);
        assertEquals("new-id", existing.getDeviceId());
        verify(deviceSessionRepository, never()).countByUserId(user.getId());
    }

    @Test
    void registerDevice_enforcesLimit() {
        when(deviceSessionRepository.findByUserIdAndDeviceId(user.getId(), "dev-3")).thenReturn(Optional.empty());
        when(deviceSessionRepository.findByUserIdAndDeviceLabel(user.getId(), "Chrome")).thenReturn(Optional.empty());
        when(deviceSessionRepository.countByUserId(user.getId())).thenReturn(2L);

        assertThrows(ApiException.class, () -> deviceService.registerDevice(user, "dev-3", "Chrome"));
    }

    @Test
    void registerDevice_updatesExistingSessionWithoutLabelChange() {
        DeviceSession existing = new DeviceSession();
        existing.setDeviceLabel("Chrome");
        when(deviceSessionRepository.findByUserIdAndDeviceId(user.getId(), "dev-1")).thenReturn(Optional.of(existing));

        deviceService.registerDevice(user, "dev-1", null);

        verify(deviceSessionRepository).save(existing);
        assertEquals("Chrome", existing.getDeviceLabel());
    }

    @Test
    void registerDevice_updatesExistingSessionIgnoresBlankLabel() {
        DeviceSession existing = new DeviceSession();
        existing.setDeviceLabel("Chrome");
        when(deviceSessionRepository.findByUserIdAndDeviceId(user.getId(), "dev-1")).thenReturn(Optional.of(existing));

        deviceService.registerDevice(user, "dev-1", "   ");

        verify(deviceSessionRepository).save(existing);
        assertEquals("Chrome", existing.getDeviceLabel());
    }

    @Test
    void registerDevice_createsNewSession() {
        when(deviceSessionRepository.findByUserIdAndDeviceId(user.getId(), "dev-1")).thenReturn(Optional.empty());
        when(deviceSessionRepository.findByUserIdAndDeviceLabel(user.getId(), "Chrome")).thenReturn(Optional.empty());
        when(deviceSessionRepository.countByUserId(user.getId())).thenReturn(0L);

        deviceService.registerDevice(user, "dev-1", "Chrome");

        verify(deviceSessionRepository).save(any(DeviceSession.class));
    }

    @Test
    void registerDevice_persistsMobileClientAndVersion() {
        when(deviceSessionRepository.findByUserIdAndDeviceId(user.getId(), "phone-1")).thenReturn(Optional.empty());
        when(deviceSessionRepository.findByUserIdAndDeviceLabel(user.getId(), "Flutter Android"))
                .thenReturn(Optional.empty());
        when(deviceSessionRepository.countByUserId(user.getId())).thenReturn(0L);

        ArgumentCaptor<DeviceSession> captor = ArgumentCaptor.forClass(DeviceSession.class);
        deviceService.registerDevice(user, "phone-1", "Flutter Android", AppClientType.MOBILE, "1.0.1+16");

        verify(deviceSessionRepository).save(captor.capture());
        DeviceSession saved = captor.getValue();
        assertEquals(AppClientType.MOBILE, saved.getAppClient());
        assertEquals("1.0.1+16", saved.getAppVersion());
        assertEquals("Flutter Android", saved.getDeviceLabel());
    }

    @Test
    void registerDevice_updatesExistingWithVersion() {
        DeviceSession existing = new DeviceSession();
        existing.setAppClient(AppClientType.WEB);
        when(deviceSessionRepository.findByUserIdAndDeviceId(user.getId(), "dev-1")).thenReturn(Optional.of(existing));

        deviceService.registerDevice(user, "dev-1", "Flutter Android", AppClientType.MOBILE, "1.0.0+10");

        verify(deviceSessionRepository).save(existing);
        assertEquals(AppClientType.MOBILE, existing.getAppClient());
        assertEquals("1.0.0+10", existing.getAppVersion());
    }

    @Test
    void heartbeat_updatesExistingSession() {
        DeviceSession existing = new DeviceSession();
        existing.setAppVersion("1.0.0+1");
        when(deviceSessionRepository.findByUserIdAndDeviceId(user.getId(), "dev-1")).thenReturn(Optional.of(existing));

        deviceService.heartbeat(user, "dev-1", "1.0.1+16", AppClientType.MOBILE);

        verify(deviceSessionRepository).save(existing);
        assertEquals("1.0.1+16", existing.getAppVersion());
        assertEquals(AppClientType.MOBILE, existing.getAppClient());
        assertNotNull(existing.getLastSeenAt());
    }
}
