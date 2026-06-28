package com.glucotrack.backend.dto;

import java.util.List;

public record GlucoseStatsResponse(
    double average,
    double timeInRange,
    double timeBelow,
    double timeAbove,
    double coefficientOfVariation,
    double estimatedHba1c,
    int totalReadings,
    int periodDays
) {
    public static GlucoseStatsResponse from(List<Integer> values, int periodDays) {
        if (values.isEmpty()) {
            return new GlucoseStatsResponse(0, 0, 0, 0, 0, 0, 0, periodDays);
        }

        int total = values.size();
        double avg = values.stream().mapToInt(v -> v).average().orElse(0);

        long inRange = values.stream().filter(v -> v >= 70 && v <= 180).count();
        long below   = values.stream().filter(v -> v < 70).count();
        long above   = values.stream().filter(v -> v > 180).count();

        double stdDev = Math.sqrt(
            values.stream()
                .mapToDouble(v -> Math.pow(v - avg, 2))
                .average()
                .orElse(0)
        );
        double cv = avg > 0 ? (stdDev / avg) * 100 : 0;

        // Fórmula ADAG: HbA1c(%) = (46.7 + média) / 28.7
        double hba1c = (46.7 + avg) / 28.7;

        return new GlucoseStatsResponse(
            Math.round(avg * 10.0) / 10.0,
            Math.round((inRange * 100.0 / total) * 10.0) / 10.0,
            Math.round((below  * 100.0 / total) * 10.0) / 10.0,
            Math.round((above  * 100.0 / total) * 10.0) / 10.0,
            Math.round(cv * 10.0) / 10.0,
            Math.round(hba1c * 10.0) / 10.0,
            total,
            periodDays
        );
    }
}
