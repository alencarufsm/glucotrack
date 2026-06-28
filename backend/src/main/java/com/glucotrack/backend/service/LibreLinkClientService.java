package com.glucotrack.backend.service;

import lombok.extern.slf4j.Slf4j;
import org.springframework.http.HttpHeaders;
import org.springframework.http.MediaType;
import org.springframework.stereotype.Service;
import org.springframework.web.client.RestClient;

import java.time.LocalDateTime;
import java.time.OffsetDateTime;
import java.time.ZoneOffset;
import java.time.format.DateTimeFormatter;
import java.time.format.DateTimeFormatterBuilder;
import java.time.temporal.ChronoField;
import java.util.ArrayList;
import java.util.List;
import java.util.Map;

/**
 * Cliente HTTP para a LibreLink Up API (Abbott).
 * Protocolo documentado pela comunidade open-source (xDrip+, Juggluco).
 */
@Service
@Slf4j
public class LibreLinkClientService {

    private static final String DEFAULT_BASE_URL = "https://api.libreview.io";

    private final RestClient restClient;

    public LibreLinkClientService() {
        this.restClient = RestClient.builder()
                .defaultHeader("product", "llu.ios")
                .defaultHeader("version", "4.7.0")
                .defaultHeader(HttpHeaders.ACCEPT, MediaType.APPLICATION_JSON_VALUE)
                .defaultHeader(HttpHeaders.CONTENT_TYPE, MediaType.APPLICATION_JSON_VALUE)
                .build();
    }

    public record LibreLinkSession(String token, String accountId, String baseUrl) {}
    public record LibrePatient(String patientId, String firstName, String lastName) {
        public String displayName() {
            return (firstName + " " + lastName).trim();
        }
    }
    public record LibreGlucoseReading(int valueInMgDl, OffsetDateTime timestamp) {}

    public LibreLinkSession login(String email, String password) {
        String baseUrl = DEFAULT_BASE_URL;

        Map<String, Object> body = postLogin(baseUrl, email, password);

        // status 2 = precisa redirecionar para o servidor regional
        if (Integer.valueOf(2).equals(body.get("status"))) {
            @SuppressWarnings("unchecked")
            Map<String, Object> data = (Map<String, Object>) body.get("data");
            String region = data != null ? (String) data.get("region") : null;
            if (region == null) throw new RuntimeException("Região LibreLink não identificada");
            baseUrl = "https://api-" + region + ".libreview.io";
            body = postLogin(baseUrl, email, password);
        }

        if (!Integer.valueOf(0).equals(body.get("status"))) {
            @SuppressWarnings("unchecked")
            Map<String, Object> error = (Map<String, Object>) body.get("error");
            String msg = error != null ? (String) error.get("message") : "Credenciais inválidas";
            throw new RuntimeException(msg);
        }

        @SuppressWarnings("unchecked")
        Map<String, Object> data = (Map<String, Object>) body.get("data");
        @SuppressWarnings("unchecked")
        Map<String, Object> authTicket = (Map<String, Object>) data.get("authTicket");
        @SuppressWarnings("unchecked")
        Map<String, Object> user = (Map<String, Object>) data.get("user");

        return new LibreLinkSession(
                (String) authTicket.get("token"),
                (String) user.get("id"),
                baseUrl
        );
    }

    @SuppressWarnings("unchecked")
    private Map<String, Object> postLogin(String baseUrl, String email, String password) {
        Map<String, Object> payload = new java.util.HashMap<>();
        payload.put("email", email);
        payload.put("password", password);
        Map<String, Object> result = restClient.post()
                .uri(baseUrl + "/llu/auth/login")
                .body(payload)
                .retrieve()
                .body(Map.class);
        if (result == null) throw new RuntimeException("Resposta vazia da API LibreLink");
        return result;
    }

    @SuppressWarnings("unchecked")
    public List<LibrePatient> getConnections(LibreLinkSession session) {
        Map<String, Object> body = restClient.get()
                .uri(session.baseUrl() + "/llu/connections")
                .headers(h -> addAuthHeaders(h, session))
                .retrieve()
                .body(Map.class);

        if (body == null || !Integer.valueOf(0).equals(body.get("status"))) {
            throw new RuntimeException("Erro ao buscar conexões LibreLink");
        }

        List<Map<String, Object>> data = (List<Map<String, Object>>) body.get("data");
        if (data == null) return List.of();

        return data.stream()
                .map(c -> new LibrePatient(
                        (String) c.get("patientId"),
                        (String) c.getOrDefault("firstName", ""),
                        (String) c.getOrDefault("lastName", "")))
                .toList();
    }

    @SuppressWarnings("unchecked")
    public List<LibreGlucoseReading> getReadings(LibreLinkSession session, String patientId) {
        Map<String, Object> body = restClient.get()
                .uri(session.baseUrl() + "/llu/connections/" + patientId + "/graph")
                .headers(h -> addAuthHeaders(h, session))
                .retrieve()
                .body(Map.class);

        if (body == null || !Integer.valueOf(0).equals(body.get("status"))) {
            throw new RuntimeException("Erro ao buscar leituras LibreLink");
        }

        Map<String, Object> data = (Map<String, Object>) body.get("data");
        List<Map<String, Object>> graphData =
                data != null ? (List<Map<String, Object>>) data.get("graphData") : null;

        List<Map<String, Object>> allPoints = new ArrayList<>();
        if (graphData != null) allPoints.addAll(graphData);

        // Inclui leitura atual do sensor se disponível
        Map<String, Object> connection = data != null ? (Map<String, Object>) data.get("connection") : null;
        if (connection != null) {
            Map<String, Object> current = (Map<String, Object>) connection.get("glucoseMeasurement");
            if (current != null) allPoints.add(current);
        }

        List<LibreGlucoseReading> readings = new ArrayList<>();
        for (Map<String, Object> point : allPoints) {
            try {
                readings.add(parseReading(point));
            } catch (Exception e) {
                log.debug("Falha ao parsear leitura LibreLink: {}", e.getMessage());
            }
        }
        return readings;
    }

    private LibreGlucoseReading parseReading(Map<String, Object> r) {
        // Prefere mg/dL direto; fallback: converte mmol/L × 18.02
        int value;
        Object mgDl = r.get("ValueInMgPerDl");
        if (mgDl instanceof Number) {
            value = ((Number) mgDl).intValue();
        } else {
            value = (int) Math.round(((Number) r.get("Value")).doubleValue() * 18.02);
        }

        String ts = r.containsKey("FactoryTimestamp")
                ? (String) r.get("FactoryTimestamp")
                : (String) r.get("Timestamp");

        return new LibreGlucoseReading(value, parseTimestamp(ts));
    }

    private OffsetDateTime parseTimestamp(String ts) {
        // Tenta ISO 8601 primeiro
        try {
            return OffsetDateTime.parse(ts);
        } catch (Exception ignored) {}

        // Formato LibreLink: "M/D/YYYY h:mm:ss AM/PM" ou "M/D/YYYY HH:mm:ss"
        try {
            DateTimeFormatter fmt = new DateTimeFormatterBuilder()
                    .appendPattern("M/d/yyyy h:mm:ss")
                    .optionalStart()
                    .appendPattern(" a")
                    .optionalEnd()
                    .parseDefaulting(ChronoField.AMPM_OF_DAY, 0)
                    .toFormatter();
            LocalDateTime ldt = LocalDateTime.parse(ts.trim(), fmt);
            return ldt.atOffset(ZoneOffset.UTC);
        } catch (Exception e) {
            log.warn("Não foi possível parsear timestamp LibreLink '{}': {}", ts, e.getMessage());
            return OffsetDateTime.now(ZoneOffset.UTC);
        }
    }

    private void addAuthHeaders(HttpHeaders headers, LibreLinkSession session) {
        String token = session.token();
        String accountId = session.accountId();
        if (token != null) headers.setBearerAuth(token);
        if (accountId != null) headers.set("Account-Id", accountId);
    }
}
