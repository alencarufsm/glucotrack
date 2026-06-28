package com.glucotrack.backend.entity;

import com.glucotrack.backend.enums.ActivityIntensity;
import jakarta.persistence.*;
import lombok.Getter;
import lombok.NoArgsConstructor;
import lombok.Setter;

import java.time.OffsetDateTime;
import java.util.UUID;

@Entity
@Table(name = "physical_activities")
@Getter @Setter @NoArgsConstructor
public class PhysicalActivity {

    @Id
    @GeneratedValue(strategy = GenerationType.UUID)
    private UUID id;

    @ManyToOne(fetch = FetchType.LAZY)
    @JoinColumn(name = "user_id", nullable = false)
    private Profile user;

    @Column(name = "activity_type", nullable = false)
    private String activityType;

    @Column(name = "duration_minutes", nullable = false)
    private Integer durationMinutes;

    @Enumerated(EnumType.STRING)
    @Column(nullable = false)
    private ActivityIntensity intensity = ActivityIntensity.MODERATE;

    @Column(name = "performed_at", nullable = false)
    private OffsetDateTime performedAt;

    @Column(columnDefinition = "TEXT")
    private String notes;

    @Column(name = "created_at", updatable = false)
    private OffsetDateTime createdAt;

    @PrePersist
    void prePersist() {
        if (performedAt == null) performedAt = OffsetDateTime.now();
        if (createdAt == null) createdAt = OffsetDateTime.now();
    }
}
