package com.glucotrack.backend.dto;

import com.glucotrack.backend.enums.MealContext;
import com.glucotrack.backend.enums.ReadingSource;
import jakarta.validation.constraints.Max;
import jakarta.validation.constraints.Min;
import jakarta.validation.constraints.NotNull;

import java.time.OffsetDateTime;

public record GlucoseReadingRequest(

    @NotNull(message = "Valor da glicemia é obrigatório")
    @Min(value = 20, message = "Valor mínimo: 20 mg/dL")
    @Max(value = 600, message = "Valor máximo: 600 mg/dL")
    Integer value,

    OffsetDateTime measuredAt,

    MealContext mealContext,

    ReadingSource source,

    String notes
) {}
