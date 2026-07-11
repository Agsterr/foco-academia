package br.com.focodev.academia.service;

import br.com.focodev.academia.domain.Academy;
import br.com.focodev.academia.domain.AppClientType;
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
        registerDevice(user, deviceId, deviceLabel, null, null);
    }

    @Transactional
    public void registerDevice(
            User user,
            String deviceId,
            String deviceLabel,
            AppClientType appClient,
            String appVersion
    ) {
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
        String normalizedVersion = normalizeAppVersion(appVersion);

        var existing = deviceSessionRepository.findByUserIdAndDeviceId(user.getId(), normalizedDeviceId);
        if (existing.isPresent()) {
            touchSession(existing.get(), deviceLabel, appClient, normalizedVersion);
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
                touchSession(session, normalizedLabel, appClient, normalizedVersion);
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
        session.setAppClient(appClient != null ? appClient : AppClientType.WEB);
        session.setAppVersion(normalizedVersion);
        session.setLastSeenAt(Instant.now());
        deviceSessionRepository.save(session);
    }

    @Transactional
    public void heartbeat(User user, String deviceId, String appVersion, AppClientType appClient) {
        if (user.getRole() == UserRole.ADMIN) {
            return;
        }
        if (deviceId == null || deviceId.isBlank()) {
            return;
        }

        String normalizedDeviceId = deviceId.trim();
        var existing = deviceSessionRepository.findByUserIdAndDeviceId(user.getId(), normalizedDeviceId);
        if (existing.isPresent()) {
            DeviceSession session = existing.get();
            session.setLastSeenAt(Instant.now());
            String normalizedVersion = normalizeAppVersion(appVersion);
            if (normalizedVersion != null) {
                session.setAppVersion(normalizedVersion);
            }
            if (appClient != null) {
                session.setAppClient(appClient);
            }
            deviceSessionRepository.save(session);
            return;
        }

        registerDevice(
                user,
                normalizedDeviceId,
                null,
                appClient != null ? appClient : AppClientType.MOBILE,
                appVersion
        );
    }

    private void touchSession(
            DeviceSession session,
            String deviceLabel,
            AppClientType appClient,
            String appVersion
    ) {
        session.setLastSeenAt(Instant.now());
        String normalizedLabel = normalizeDeviceLabel(deviceLabel);
        if (normalizedLabel != null) {
            session.setDeviceLabel(normalizedLabel);
        }
        if (appClient != null) {
            session.setAppClient(appClient);
        }
        if (appVersion != null) {
            session.setAppVersion(appVersion);
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

    private static String normalizeAppVersion(String appVersion) {
        if (appVersion == null) {
            return null;
        }
        String trimmed = appVersion.trim();
        if (trimmed.isEmpty()) {
            return null;
        }
        return trimmed.length() > 64 ? trimmed.substring(0, 64) : trimmed;
    }
}
