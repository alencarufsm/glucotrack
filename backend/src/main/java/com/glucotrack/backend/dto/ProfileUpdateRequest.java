package com.glucotrack.backend.dto;

import com.glucotrack.backend.enums.DiabetesType;
import jakarta.validation.constraints.Max;
import jakarta.validation.constraints.Min;

import java.time.LocalDate;

public record ProfileUpdateRequest(
    String name,
    LocalDate birthDate,
    DiabetesType diabetesType,
    String physicalLimitations,

    @Min(value = 40) @Max(value = 200)
    Integer targetMin,

    @Min(value = 80) @Max(value = 400)
    Integer targetMax
) {}
