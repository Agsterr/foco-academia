package br.com.focodev.academia.service;

import br.com.focodev.academia.domain.Academy;
import br.com.focodev.academia.domain.DeviceSession;
import br.com.focodev.academia.domain.User;
import br.com.focodev.academia.domain.UserRole;
import br.com.focodev.academia.exception.ApiException;
import br.com.focodev.academia.repository.DeviceSessionRepository;
import org.junit.jupiter.api.BeforeEach;
import org.junit.jupiter.api.Test;
import org.junit.jupiter.api.extension.ExtendWith;
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
    void registerDevice_enforcesLimit() {
        when(deviceSessionRepository.findByUserIdAndDeviceId(user.getId(), "dev-3")).thenReturn(Optional.empty());
        when(deviceSessionRepository.countByUserId(user.getId())).thenReturn(2L);

        assertThrows(ApiException.class, () -> deviceService.registerDevice(user, "dev-3", null));
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
        when(deviceSessionRepository.countByUserId(user.getId())).thenReturn(0L);

        deviceService.registerDevice(user, "dev-1", "Chrome");

        verify(deviceSessionRepository).save(any(DeviceSession.class));
    }
}
