package com.glucotrack.backend.security;

import jakarta.servlet.FilterChain;
import jakarta.servlet.ServletException;
import jakarta.servlet.http.HttpServletRequest;
import jakarta.servlet.http.HttpServletResponse;
import org.springframework.stereotype.Component;
import org.springframework.web.filter.OncePerRequestFilter;

import java.io.IOException;
import java.util.Base64;

@Component
public class JwtDebugFilter extends OncePerRequestFilter {

    @Override
    protected void doFilterInternal(HttpServletRequest request,
                                    HttpServletResponse response,
                                    FilterChain chain) throws ServletException, IOException {
        String auth = request.getHeader("Authorization");
        if (auth != null && auth.startsWith("Bearer ")) {
            try {
                String token = auth.substring(7);
                String[] parts = token.split("\\.");
                String header = new String(Base64.getUrlDecoder().decode(parts[0]));
                System.err.println("JWT HEADER: " + header);
                System.err.println("JWT alg check — token starts with: " + token.substring(0, Math.min(30, token.length())));
            } catch (Exception e) {
                System.err.println("JWT DECODE ERROR: " + e.getMessage());
            }
        }
        chain.doFilter(request, response);
    }
}
