package br.com.focodev.academia.service;

import br.com.focodev.academia.domain.Academy;
import br.com.focodev.academia.domain.AppClientType;
import br.com.focodev.academia.domain.DeviceSession;
import br.com.focodev.academia.domain.User;
import br.com.focodev.academia.domain.UserRole;
import br.com.focodev.academia.exception.ApiException;
import br.com.focodev.academia.repository.DeviceSessionRepository;
import lombok.RequiredArgsConstructor;
import org.springframework.http.HttpStatus;
import org.springframework.stereotype.Service;
import org.springframework.transaction.annotation.Transactional;

import java.time.Duration;
import java.time.Instant;

@Service
@RequiredArgsConstructor
public class DeviceService {

    static final int INDEPENDENT_STUDENT_DEVICE_LIMIT = 3;

    /** Conta de um aparelho só: o aparelho antigo parado há tanto tempo libera a vaga sozinho. */
    static final Duration SINGLE_DEVICE_IDLE_RELEASE = Duration.ofDays(7);

    static final String DEVICE_IN_USE_MESSAGE = "Esta conta já está em uso em outro aparelho. "
            + "Trocou de celular? Peça ao seu instrutor ou à academia para liberar o aparelho "
            + "(ou ele libera sozinho depois de 7 dias sem uso no aparelho antigo).";

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
        if (academy == null && user.getRole() != UserRole.ALUNO) {
            throw new ApiException("Usuário sem academia vinculada");
        }
        // Aluno avulso não tem academia que defina o limite de aparelhos.
        int deviceLimit = academy != null ? academy.getDeviceLimitPerUser() : INDEPENDENT_STUDENT_DEVICE_LIMIT;

        String normalizedDeviceId = deviceId.trim();
        String normalizedVersion = normalizeAppVersion(appVersion);

        var existing = deviceSessionRepository.findByUserIdAndDeviceId(user.getId(), normalizedDeviceId);
        if (existing.isPresent()) {
            touchSession(existing.get(), deviceLabel, appClient, normalizedVersion);
            return;
        }

        String normalizedLabel = normalizeDeviceLabel(deviceLabel);
        if (user.isSingleDevice()) {
            // Sem atalho por nome do aparelho ("Flutter Android" é igual em todo celular).
            registerSingleDevice(user, normalizedDeviceId, normalizedLabel, appClient, normalizedVersion);
            return;
        }
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
        if (count >= deviceLimit) {
            throw new ApiException(
                    "Limite de " + deviceLimit + " dispositivos atingido. "
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

    private void registerSingleDevice(
            User user,
            String deviceId,
            String deviceLabel,
            AppClientType appClient,
            String appVersion
    ) {
        Instant idleLimit = Instant.now().minus(SINGLE_DEVICE_IDLE_RELEASE);
        for (DeviceSession other : deviceSessionRepository.findByUserIdOrderByLastSeenAtDesc(user.getId())) {
            if (other.getLastSeenAt() == null || other.getLastSeenAt().isBefore(idleLimit)) {
                deviceSessionRepository.delete(other);
            } else {
                throw new ApiException(DEVICE_IN_USE_MESSAGE, HttpStatus.FORBIDDEN);
            }
        }
        DeviceSession session = new DeviceSession();
        session.setUser(user);
        session.setDeviceId(deviceId);
        session.setDeviceLabel(deviceLabel);
        session.setAppClient(appClient != null ? appClient : AppClientType.WEB);
        session.setAppVersion(appVersion);
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
