package com.glucotrack.backend.entity;

import com.glucotrack.backend.enums.DiabetesType;
import jakarta.persistence.*;
import lombok.Getter;
import lombok.NoArgsConstructor;
import lombok.Setter;
import org.hibernate.annotations.UpdateTimestamp;

import java.time.LocalDate;
import java.time.OffsetDateTime;
import java.util.UUID;

@Entity
@Table(name = "profiles")
@Getter @Setter @NoArgsConstructor
public class Profile {

    @Id
    @Column(nullable = false, updatable = false)
    private UUID id;

    @Column(nullable = false)
    private String name;

    @Column(name = "birth_date")
    private LocalDate birthDate;

    @Enumerated(EnumType.STRING)
    @Column(name = "diabetes_type", nullable = false)
    private DiabetesType diabetesType = DiabetesType.NONE;

    @Column(name = "physical_limitations", columnDefinition = "TEXT")
    private String physicalLimitations;

    @Column(name = "target_min", nullable = false)
    private Integer targetMin = 70;

    @Column(name = "target_max", nullable = false)
    private Integer targetMax = 180;

    @Column(name = "created_at", updatable = false)
    private OffsetDateTime createdAt;

    @UpdateTimestamp
    @Column(name = "updated_at")
    private OffsetDateTime updatedAt;
}
