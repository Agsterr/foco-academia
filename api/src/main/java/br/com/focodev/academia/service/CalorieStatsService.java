package br.com.focodev.academia.service;

import br.com.focodev.academia.domain.CardioSession;
import br.com.focodev.academia.domain.User;
import br.com.focodev.academia.domain.UserRole;
import br.com.focodev.academia.domain.WorkoutSession;
import br.com.focodev.academia.dto.CalorieStatsResponse;
import br.com.focodev.academia.exception.ApiException;
import br.com.focodev.academia.repository.CardioSessionRepository;
import br.com.focodev.academia.repository.UserRepository;
import br.com.focodev.academia.repository.WorkoutSessionRepository;
import br.com.focodev.academia.security.AuthUser;
import lombok.RequiredArgsConstructor;
import org.springframework.stereotype.Service;
import org.springframework.transaction.annotation.Transactional;

import java.time.Instant;
import java.time.LocalDate;
import java.time.YearMonth;
import java.time.ZoneId;
import java.time.format.DateTimeFormatter;
import java.util.*;

@Service
@RequiredArgsConstructor
public class CalorieStatsService {

    private static final ZoneId ZONE = ZoneId.of("America/Sao_Paulo");
    private static final DateTimeFormatter ISO = DateTimeFormatter.ISO_INSTANT;
    private static final String DISCLAIMER =
            "Valores estimados com base em MET, peso e duração do treino. Não substituem medição com frequência cardíaca.";

    private final CardioSessionRepository cardioSessionRepository;
    private final WorkoutSessionRepository workoutSessionRepository;
    private final UserRepository userRepository;
    private final TenantService tenantService;

    @Transactional(readOnly = true)
    public CalorieStatsResponse getStudentStats(AuthUser student) {
        User user = requireStudent(student);
        return build(user.getId());
    }

    public int sumCaloriesSince(UUID studentId, Instant since) {
        int cardio = cardioSessionRepository.findCompletedSince(studentId, since).stream()
                .mapToInt(s -> s.getCaloriesKcal() != null ? s.getCaloriesKcal() : 0)
                .sum();
        int strength = workoutSessionRepository.findCompletedSince(studentId, since).stream()
                .mapToInt(s -> s.getCaloriesKcal() != null ? s.getCaloriesKcal() : 0)
                .sum();
        return cardio + strength;
    }

    private CalorieStatsResponse build(UUID studentId) {
        LocalDate today = LocalDate.now(ZONE);
        Instant startToday = today.atStartOfDay(ZONE).toInstant();
        Instant start7 = today.minusDays(6).atStartOfDay(ZONE).toInstant();
        Instant start30 = today.minusDays(29).atStartOfDay(ZONE).toInstant();
        Instant start12m = today.minusMonths(11).withDayOfMonth(1).atStartOfDay(ZONE).toInstant();

        List<CardioSession> cardioAll = cardioSessionRepository.findCompletedByStudentId(studentId);
        List<WorkoutSession> strengthAll = workoutSessionRepository.findCompletedByStudentId(studentId);

        List<SessionPoint> points = new ArrayList<>();
        for (CardioSession s : cardioAll) {
            if (s.getCompletedAt() == null) continue;
            points.add(new SessionPoint(
                    s.getCompletedAt(),
                    s.getCaloriesKcal() != null ? s.getCaloriesKcal() : 0,
                    s.getDistanceMeters() != null ? s.getDistanceMeters() : 0,
                    s.getElapsedMs() != null ? s.getElapsedMs() : 0
            ));
        }
        for (WorkoutSession s : strengthAll) {
            if (s.getCompletedAt() == null) continue;
            long ms = s.getTotalDurationSeconds() != null ? s.getTotalDurationSeconds() * 1000L : 0;
            points.add(new SessionPoint(
                    s.getCompletedAt(),
                    s.getCaloriesKcal() != null ? s.getCaloriesKcal() : 0,
                    0,
                    ms
            ));
        }

        int caloriesToday = sumCalories(points, startToday);
        double kmToday = sumKm(points, startToday);
        int minutesToday = (int) Math.round(points.stream()
                .filter(p -> !p.at.isBefore(startToday))
                .mapToDouble(p -> p.durationMs / 60_000.0)
                .sum());

        double totalKm = points.stream().mapToDouble(p -> p.distanceMeters / 1000.0).sum();
        double totalHours = points.stream().mapToDouble(p -> p.durationMs / 3_600_000.0).sum();
        int totalSessions = points.size();
        int cardioSessions = (int) cardioAll.stream().filter(s -> s.getCompletedAt() != null).count();
        double avg = totalSessions > 0
                ? points.stream().mapToInt(p -> p.calories).average().orElse(0)
                : 0;
        int maxCal = points.stream().mapToInt(p -> p.calories).max().orElse(0);
        double maxKm = points.stream().mapToDouble(p -> p.distanceMeters / 1000.0).max().orElse(0);
        int maxMin = points.stream()
                .mapToInt(p -> (int) Math.round(p.durationMs / 60_000.0))
                .max()
                .orElse(0);

        List<CalorieStatsResponse.DistanceSession> recentDistances = cardioAll.stream()
                .filter(s -> s.getCompletedAt() != null)
                .filter(s -> s.getDistanceMeters() != null && s.getDistanceMeters() > 0)
                .limit(30)
                .map(s -> new CalorieStatsResponse.DistanceSession(
                        s.getId().toString(),
                        ISO.format(s.getCompletedAt()),
                        s.getWorkout() != null ? s.getWorkout().getTitle() : "Outdoor",
                        round2((s.getDistanceMeters() != null ? s.getDistanceMeters() : 0) / 1000.0),
                        s.getCaloriesKcal(),
                        s.getElapsedMs(),
                        s.getAvgSpeedKmh()
                ))
                .toList();

        return new CalorieStatsResponse(
                caloriesToday,
                round1(kmToday),
                minutesToday,
                sumCalories(points, start7),
                round1(sumKm(points, start7)),
                sumCalories(points, start30),
                round1(sumKm(points, start30)),
                sumCalories(points, start12m),
                round1(sumKm(points, start12m)),
                round1(totalKm),
                round1(totalHours),
                totalSessions,
                cardioSessions,
                round1(avg),
                maxCal,
                round1(maxKm),
                maxMin,
                calculateStreak(points, today),
                buildWeekly(points, today),
                buildMonthly(points, today),
                buildYearly(points, today),
                recentDistances,
                DISCLAIMER
        );
    }

    private List<CalorieStatsResponse.PeriodBucket> buildWeekly(List<SessionPoint> points, LocalDate today) {
        DateTimeFormatter fmt = DateTimeFormatter.ofPattern("dd/MM");
        List<CalorieStatsResponse.PeriodBucket> buckets = new ArrayList<>();
        for (int i = 6; i >= 0; i--) {
            LocalDate day = today.minusDays(i);
            Instant start = day.atStartOfDay(ZONE).toInstant();
            Instant end = day.plusDays(1).atStartOfDay(ZONE).toInstant();
            buckets.add(bucket(fmt.format(day), points, start, end));
        }
        return buckets;
    }

    private List<CalorieStatsResponse.PeriodBucket> buildMonthly(List<SessionPoint> points, LocalDate today) {
        DateTimeFormatter fmt = DateTimeFormatter.ofPattern("MMM/yy", Locale.forLanguageTag("pt-BR"));
        List<CalorieStatsResponse.PeriodBucket> buckets = new ArrayList<>();
        for (int i = 11; i >= 0; i--) {
            YearMonth ym = YearMonth.from(today).minusMonths(i);
            Instant start = ym.atDay(1).atStartOfDay(ZONE).toInstant();
            Instant end = ym.plusMonths(1).atDay(1).atStartOfDay(ZONE).toInstant();
            buckets.add(bucket(fmt.format(ym.atDay(1)), points, start, end));
        }
        return buckets;
    }

    private List<CalorieStatsResponse.PeriodBucket> buildYearly(List<SessionPoint> points, LocalDate today) {
        List<CalorieStatsResponse.PeriodBucket> buckets = new ArrayList<>();
        int currentYear = today.getYear();
        for (int y = currentYear - 4; y <= currentYear; y++) {
            Instant start = LocalDate.of(y, 1, 1).atStartOfDay(ZONE).toInstant();
            Instant end = LocalDate.of(y + 1, 1, 1).atStartOfDay(ZONE).toInstant();
            buckets.add(bucket(String.valueOf(y), points, start, end));
        }
        return buckets;
    }

    private static CalorieStatsResponse.PeriodBucket bucket(
            String label, List<SessionPoint> points, Instant start, Instant end
    ) {
        int cal = 0;
        double meters = 0;
        int sessions = 0;
        for (SessionPoint p : points) {
            if (!p.at.isBefore(start) && p.at.isBefore(end)) {
                cal += p.calories;
                meters += p.distanceMeters;
                sessions++;
            }
        }
        return new CalorieStatsResponse.PeriodBucket(label, cal, round1(meters / 1000.0), sessions);
    }

    private static int sumCalories(List<SessionPoint> points, Instant since) {
        return points.stream()
                .filter(p -> !p.at.isBefore(since))
                .mapToInt(p -> p.calories)
                .sum();
    }

    private static double sumKm(List<SessionPoint> points, Instant since) {
        return points.stream()
                .filter(p -> !p.at.isBefore(since))
                .mapToDouble(p -> p.distanceMeters / 1000.0)
                .sum();
    }

    private static int calculateStreak(List<SessionPoint> points, LocalDate today) {
        Set<LocalDate> trained = new HashSet<>();
        for (SessionPoint p : points) {
            trained.add(p.at.atZone(ZONE).toLocalDate());
        }
        int streak = 0;
        for (int i = 0; i < 365; i++) {
            LocalDate date = today.minusDays(i);
            if (trained.contains(date)) {
                streak++;
            } else if (i > 0) {
                break;
            }
        }
        return streak;
    }

    private User requireStudent(AuthUser student) {
        User user = userRepository.findById(student.getId())
                .orElseThrow(() -> new ApiException("Aluno não encontrado"));
        tenantService.requireActiveAcademy(user);
        if (user.getRole() != UserRole.ALUNO) {
            throw new ApiException("Acesso negado");
        }
        return user;
    }

    private static double round1(double v) {
        return Math.round(v * 10.0) / 10.0;
    }

    private static double round2(double v) {
        return Math.round(v * 100.0) / 100.0;
    }

    private record SessionPoint(Instant at, int calories, double distanceMeters, long durationMs) {}
}
