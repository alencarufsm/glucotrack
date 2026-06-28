package com.glucotrack.backend.dto;

import com.glucotrack.backend.entity.GlucoseReading;
import com.glucotrack.backend.enums.MealContext;
import com.glucotrack.backend.enums.ReadingSource;

import java.time.OffsetDateTime;
import java.util.UUID;

public record GlucoseReadingResponse(
    UUID id,
    Integer value,
    OffsetDateTime measuredAt,
    MealContext mealContext,
    ReadingSource source,
    String notes,
    String glucoseLevel  // classificação clínica: "NORMAL", "LOW", "HIGH", etc.
) {
    public static GlucoseReadingResponse from(GlucoseReading r) {
        return new GlucoseReadingResponse(
            r.getId(),
            r.getValue(),
            r.getMeasuredAt(),
            r.getMealContext(),
            r.getSource(),
            r.getNotes(),
            classifyGlucose(r.getValue())
        );
    }

    private static String classifyGlucose(int value) {
        if (value < 54)  return "HYPOGLYCEMIA_SEVERE";
        if (value < 70)  return "HYPOGLYCEMIA";
        if (value <= 180) return "NORMAL";
        if (value <= 249) return "HYPERGLYCEMIA";
        return "HYPERGLYCEMIA_SEVERE";
    }
}
