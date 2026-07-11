package br.com.focodev.academia.dto;

import java.util.List;

public record CalorieStatsResponse(
        int caloriesToday,
        double kmToday,
        int minutesToday,
        int caloriesLast7Days,
        double kmLast7Days,
        int caloriesLast30Days,
        double kmLast30Days,
        int caloriesLast12Months,
        double kmLast12Months,
        double totalKm,
        double totalHours,
        int totalSessions,
        int cardioSessions,
        double avgCaloriesPerSession,
        int maxCaloriesSingleSession,
        double maxDistanceKm,
        int maxDurationMinutes,
        int currentStreakDays,
        List<PeriodBucket> weekly,
        List<PeriodBucket> monthly,
        List<PeriodBucket> yearly,
        List<DistanceSession> recentDistances,
        String estimateDisclaimer
) {
    public record PeriodBucket(String label, int calories, double km, int sessions) {}

    public record DistanceSession(
            String id,
            String completedAt,
            String title,
            double distanceKm,
            Integer caloriesKcal,
            Long elapsedMs,
            Double avgSpeedKmh
    ) {}
}
