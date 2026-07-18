package br.com.focodev.academia.service;

import br.com.focodev.academia.domain.BodyMeasurement;
import br.com.focodev.academia.domain.StudentProfile;
import br.com.focodev.academia.domain.WorkoutIntensity;
import br.com.focodev.academia.repository.BodyMeasurementRepository;
import br.com.focodev.academia.repository.StudentProfileRepository;
import org.springframework.stereotype.Service;

/**
 * Estimativa de gasto calórico via MET (Metabolic Equivalent of Task).
 * Fórmula: kcal = MET × peso(kg) × tempo(horas).
 * Valores aproximados — sem frequência cardíaca ou sensores biométricos.
 *
 * Sem deslocamento real (parado com o treino aberto) → 0 kcal de exercício.
 */
@Service
public class CalorieEstimationService {

    public static final double DEFAULT_WEIGHT_KG = 70.0;
    public static final double STATIONARY_SPEED_KMH = 1.0;
    public static final double MIN_DISTANCE_METERS = 20.0;

    private static final double[][] WALK_MET = {
            {2.0, 2.0},
            {3.0, 2.5},
            {4.0, 3.0},
            {5.0, 3.8},
            {6.0, 4.8},
    };

    private static final double[][] RUN_MET = {
            {7.0, 7.0},
            {8.0, 8.3},
            {9.0, 9.0},
            {10.0, 9.8},
            {11.0, 10.5},
            {12.0, 11.8},
            {13.0, 12.8},
    };

    public double resolveWeightKg(Double profileWeightKg) {
        if (profileWeightKg == null || profileWeightKg < 20 || profileWeightKg > 500) {
            return DEFAULT_WEIGHT_KG;
        }
        return profileWeightKg;
    }

    /**
     * Peso do aluno: perfil → última pesagem → 70 kg padrão.
     */
    public double resolveStudentWeightKg(
            java.util.UUID studentId,
            StudentProfileRepository profileRepository,
            BodyMeasurementRepository measurementRepository
    ) {
        Double fromProfile = profileRepository.findByUserId(studentId)
                .map(StudentProfile::getCurrentWeightKg)
                .orElse(null);
        if (fromProfile != null && fromProfile >= 20 && fromProfile <= 500) {
            return fromProfile;
        }
        return measurementRepository.findByStudentIdOrderByRecordedAtDesc(studentId).stream()
                .findFirst()
                .map(BodyMeasurement::getWeightKg)
                .filter(w -> w >= 20 && w <= 500)
                .orElse(DEFAULT_WEIGHT_KG);
    }

    /** MET por velocidade média (km/h). Abaixo de 6,5 km/h usa tabela de caminhada. */
    public double metForSpeedKmh(double speedKmh) {
        if (speedKmh <= 0.3) {
            return 1.0;
        }
        if (speedKmh < 2.0) {
            double t = Math.max(0, Math.min(1.0, (speedKmh - 0.3) / (2.0 - 0.3)));
            return 1.0 + t;
        }
        if (speedKmh < 6.5) {
            return interpolate(WALK_MET, speedKmh, 2.0, 5.5);
        }
        return interpolate(RUN_MET, speedKmh, 6.5, 14.0);
    }

    public double metForIntensity(WorkoutIntensity intensity) {
        if (intensity == null) {
            return 5.0;
        }
        return switch (intensity) {
            case LEVE -> 3.5;
            case MODERADA -> 5.0;
            case PESADA -> 6.5;
            case MUITO_INTENSA -> 8.0;
        };
    }

    public int estimateCardioKcal(double weightKg, Double avgSpeedKmh, Long elapsedMs, Long pausedMs) {
        return estimateCardioKcal(weightKg, avgSpeedKmh, elapsedMs, pausedMs, null);
    }

    public int estimateCardioKcal(
            double weightKg,
            Double avgSpeedKmh,
            Long elapsedMs,
            Long pausedMs,
            Double distanceMeters
    ) {
        // elapsedMs = tempo em movimento (pausas já excluídas no cliente). pausedMs ignorado.
        long movementMs = elapsedMs != null ? Math.max(0, elapsedMs) : 0;
        if (movementMs <= 0) {
            return 0;
        }
        double hours = movementMs / 3_600_000.0;
        if (hours <= 0) {
            return 0;
        }

        double speed = avgSpeedKmh != null && avgSpeedKmh > 0 ? avgSpeedKmh : 0;
        if ((speed <= 0 || !Double.isFinite(speed))
                && distanceMeters != null
                && distanceMeters >= MIN_DISTANCE_METERS) {
            speed = (distanceMeters / 1000.0) / hours;
        }
        if (!Double.isFinite(speed) || speed < 0) {
            speed = 0;
        }
        speed = Math.min(22.0, speed);

        boolean moved = distanceMeters != null && distanceMeters >= MIN_DISTANCE_METERS;
        if (!moved && speed < STATIONARY_SPEED_KMH) {
            return 0;
        }
        if (moved && speed < 0.6) {
            double km = distanceMeters / 1000.0;
            return roundKcal(0.7 * weightKg * km);
        }

        double met = metForSpeedKmh(speed);
        double kcal = met * weightKg * hours;

        if (distanceMeters != null && distanceMeters > 0) {
            double km = distanceMeters / 1000.0;
            double perKgPerKm = speed >= 6.5 ? 1.15 : 0.85;
            double cap = perKgPerKm * weightKg * km * 1.2;
            double floor = 0.55 * weightKg * km;
            if (cap >= floor) {
                kcal = Math.max(floor, Math.min(cap, kcal));
            } else {
                kcal = Math.max(0, Math.min(cap, kcal));
            }
        }

        return roundKcal(kcal);
    }

    public int estimateStrengthKcal(double weightKg, long durationSeconds, WorkoutIntensity intensity) {
        if (durationSeconds <= 0) {
            return 0;
        }
        double met = metForIntensity(intensity);
        double hours = durationSeconds / 3600.0;
        return roundKcal(met * weightKg * hours);
    }

    private static double interpolate(double[][] table, double speed, double minFloor, double maxCeil) {
        if (speed <= table[0][0]) {
            if (speed < minFloor) {
                return Math.max(1.5, table[0][1] * (speed / table[0][0]));
            }
            return table[0][1];
        }
        for (int i = 1; i < table.length; i++) {
            if (speed <= table[i][0]) {
                double s0 = table[i - 1][0];
                double m0 = table[i - 1][1];
                double s1 = table[i][0];
                double m1 = table[i][1];
                double t = (speed - s0) / (s1 - s0);
                return m0 + t * (m1 - m0);
            }
        }
        double lastSpeed = table[table.length - 1][0];
        double lastMet = table[table.length - 1][1];
        if (speed > maxCeil) {
            return lastMet + (speed - lastSpeed) * 0.6;
        }
        return lastMet;
    }

    private static int roundKcal(double value) {
        if (value <= 0) {
            return 0;
        }
        return (int) Math.round(value);
    }
}
