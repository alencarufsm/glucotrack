package com.glucotrack.backend.dto;

import java.util.List;

public record LibreLinkTestResponse(List<LibreLinkPatient> patients) {
    public record LibreLinkPatient(String patientId, String displayName) {}
}
