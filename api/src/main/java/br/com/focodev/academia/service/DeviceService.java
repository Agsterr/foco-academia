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

        String normalizedDeviceId = deviceId.trim();
        var existing = deviceSessionRepository.findByUserIdAndDeviceId(user.getId(), normalizedDeviceId);
        if (existing.isPresent()) {
            touchSession(existing.get(), deviceLabel);
            return;
        }

        String normalizedLabel = normalizeDeviceLabel(deviceLabel);
        if (normalizedLabel != null) {
            var sameEquipment = deviceSessionRepository.findByUserIdAndDeviceLabel(user.getId(), normalizedLabel);
            if (sameEquipment.isPresent()) {
                DeviceSession session = sameEquipment.get();
                if (!session.getDeviceId().equals(normalizedDeviceId)) {
                    deviceSessionRepository
                            .findByUserIdAndDeviceId(user.getId(), normalizedDeviceId)
                            .ifPresent(deviceSessionRepository::delete);
                    session.setDeviceId(normalizedDeviceId);
                }
                touchSession(session, normalizedLabel);
                return;
            }
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
        session.setDeviceId(normalizedDeviceId);
        session.setDeviceLabel(normalizedLabel);
        deviceSessionRepository.save(session);
    }

    private void touchSession(DeviceSession session, String deviceLabel) {
        session.setLastSeenAt(Instant.now());
        String normalizedLabel = normalizeDeviceLabel(deviceLabel);
        if (normalizedLabel != null) {
            session.setDeviceLabel(normalizedLabel);
        }
        deviceSessionRepository.save(session);
    }

    private static String normalizeDeviceLabel(String deviceLabel) {
        if (deviceLabel == null) {
            return null;
        }
        String trimmed = deviceLabel.trim();
        if (trimmed.isEmpty()) {
            return null;
        }
        return trimmed.length() > 80 ? trimmed.substring(0, 80) : trimmed;
    }
}
