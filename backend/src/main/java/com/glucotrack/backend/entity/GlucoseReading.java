package com.glucotrack.backend.entity;

import com.glucotrack.backend.enums.MealContext;
import com.glucotrack.backend.enums.ReadingSource;
import jakarta.persistence.*;
import lombok.Getter;
import lombok.NoArgsConstructor;
import lombok.Setter;

import java.time.OffsetDateTime;
import java.util.UUID;

@Entity
@Table(name = "glucose_readings")
@Getter @Setter @NoArgsConstructor
public class GlucoseReading {

    @Id
    @GeneratedValue(strategy = GenerationType.UUID)
    private UUID id;

    @ManyToOne(fetch = FetchType.LAZY)
    @JoinColumn(name = "user_id", nullable = false)
    private Profile user;

    // Valor em mg/dL
    @Column(nullable = false)
    private Integer value;

    @Column(name = "measured_at", nullable = false)
    private OffsetDateTime measuredAt;

    @Enumerated(EnumType.STRING)
    @Column(name = "meal_context", nullable = false)
    private MealContext mealContext = MealContext.OTHER;

    @Enumerated(EnumType.STRING)
    @Column(nullable = false)
    private ReadingSource source = ReadingSource.MANUAL;

    @Column(columnDefinition = "TEXT")
    private String notes;

    @Column(name = "created_at", updatable = false)
    private OffsetDateTime createdAt;

    @PrePersist
    void prePersist() {
        if (measuredAt == null) measuredAt = OffsetDateTime.now();
        if (createdAt == null) createdAt = OffsetDateTime.now();
    }
}
