package com.glucotrack.backend.entity;

import jakarta.persistence.*;
import lombok.Getter;
import lombok.NoArgsConstructor;
import lombok.Setter;

import java.math.BigDecimal;
import java.time.OffsetDateTime;
import java.util.UUID;

@Entity
@Table(name = "insulin_doses")
@Getter @Setter @NoArgsConstructor
public class InsulinDose {

    @Id
    @GeneratedValue(strategy = GenerationType.UUID)
    private UUID id;

    @ManyToOne(fetch = FetchType.LAZY)
    @JoinColumn(name = "user_id", nullable = false)
    private Profile user;

    // Medição que originou a dose (opcional)
    @ManyToOne(fetch = FetchType.LAZY)
    @JoinColumn(name = "reading_id")
    private GlucoseReading reading;

    @Column(name = "insulin_type", nullable = false)
    private String insulinType;

    @Column(name = "dose_units", nullable = false, precision = 5, scale = 1)
    private BigDecimal doseUnits;

    @Column(name = "applied_at", nullable = false)
    private OffsetDateTime appliedAt;

    @Column(columnDefinition = "TEXT")
    private String notes;

    @Column(name = "created_at", updatable = false)
    private OffsetDateTime createdAt;

    @PrePersist
    void prePersist() {
        if (appliedAt == null) appliedAt = OffsetDateTime.now();
        if (createdAt == null) createdAt = OffsetDateTime.now();
    }
}
