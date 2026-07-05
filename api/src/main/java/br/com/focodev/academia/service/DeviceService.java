package br.com.focodev.academia.service;

import br.com.focodev.academia.domain.Academy;
import br.com.focodev.academia.domain.DeviceSession;
import br.com.focodev.academia.domain.User;
import br.com.focodev.academia.domain.UserRole;
import br.com.focodev.academia.exception.ApiException;
import br.com.focodev.academia.repository.DeviceSessionRepository;
import lombok.RequiredArgsConstructor;
import org.springframework.stereotype.Service;
import org.springframework.transaction.annotation.Transactional;

import java.time.Instant;

@Service
@RequiredArgsConstructor
public class DeviceService {

    private final DeviceSessionRepository deviceSessionRepository;

    @Transactional
    public void registerDevice(User user, String deviceId, String deviceLabel) {
        if (user.getRole() == UserRole.ADMIN) {
            return;
        }
        if (deviceId == null || deviceId.isBlank()) {
            throw new ApiException("Identificador do dispositivo é obrigatório");
        }

        Academy academy = user.getAcademy();
        if (academy == null) {
            throw new ApiException("Usuário sem academia vinculada");
        }

        var existing = deviceSessionRepository.findByUserIdAndDeviceId(user.getId(), deviceId);
        if (existing.isPresent()) {
            DeviceSession session = existing.get();
            session.setLastSeenAt(Instant.now());
            if (deviceLabel != null && !deviceLabel.isBlank()) {
                session.setDeviceLabel(deviceLabel);
            }
            deviceSessionRepository.save(session);
            return;
        }

        long count = deviceSessionRepository.countByUserId(user.getId());
        if (count >= academy.getDeviceLimitPerUser()) {
            throw new ApiException(
                    "Limite de " + academy.getDeviceLimitPerUser() + " dispositivos atingido. "
                            + "Remova um dispositivo antigo ou peça ao administrador para aumentar o limite."
            );
        }

        DeviceSession session = new DeviceSession();
        session.setUser(user);
        session.setDeviceId(deviceId.trim());
        session.setDeviceLabel(deviceLabel);
        deviceSessionRepository.save(session);
    }
}
