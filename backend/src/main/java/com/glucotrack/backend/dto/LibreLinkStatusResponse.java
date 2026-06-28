package com.glucotrack.backend.dto;

import java.time.OffsetDateTime;

public record LibreLinkStatusResponse(
    boolean connected,
    String patientName,
    OffsetDateTime lastSync
) {}
