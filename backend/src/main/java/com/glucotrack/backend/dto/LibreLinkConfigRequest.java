package com.glucotrack.backend.dto;

import jakarta.validation.constraints.Email;
import jakarta.validation.constraints.NotBlank;

public record LibreLinkConfigRequest(
    @NotBlank @Email String email,
    @NotBlank String password,
    @NotBlank String patientId,
    @NotBlank String patientName
) {}
