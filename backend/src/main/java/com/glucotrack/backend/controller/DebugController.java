package com.glucotrack.backend.controller;

import org.springframework.web.bind.annotation.GetMapping;
import org.springframework.web.bind.annotation.RestController;

import jakarta.servlet.http.HttpServletRequest;
import java.util.Base64;
import java.util.Map;

@RestController
public class DebugController {

    @GetMapping("/debug/jwt")
    public Map<String, String> debugJwt(HttpServletRequest request) {
        String auth = request.getHeader("Authorization");
        if (auth == null || !auth.startsWith("Bearer ")) {
            return Map.of("error", "no token");
        }
        try {
            String token = auth.substring(7);
            String[] parts = token.split("\\.");
            String header = new String(Base64.getUrlDecoder().decode(parts[0]));
            String payload = new String(Base64.getUrlDecoder().decode(parts[1]));
            return Map.of("header", header, "payload", payload);
        } catch (Exception e) {
            return Map.of("error", e.getMessage());
        }
    }
}
