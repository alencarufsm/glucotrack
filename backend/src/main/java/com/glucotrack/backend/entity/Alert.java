package com.glucotrack.backend.entity;

import com.glucotrack.backend.enums.AlertSeverity;
import com.glucotrack.backend.enums.AlertType;
import jakarta.persistence.*;
import lombok.Getter;
import lombok.NoArgsConstructor;
import lombok.Setter;

import java.time.OffsetDateTime;
import java.util.UUID;

@Entity
@Table(name = "alerts")
@Getter @Setter @NoArgsConstructor
public class Alert {

    @Id
    @GeneratedValue(strategy = GenerationType.UUID)
    private UUID id;

    @ManyToOne(fetch = FetchType.LAZY)
    @JoinColumn(name = "user_id", nullable = false)
    private Profile user;

    @ManyToOne(fetch = FetchType.LAZY)
    @JoinColumn(name = "reading_id")
    private GlucoseReading reading;

    @Enumerated(EnumType.STRING)
    @Column(name = "alert_type", nullable = false)
    private AlertType alertType;

    @Enumerated(EnumType.STRING)
    @Column(nullable = false)
    private AlertSeverity severity;

    @Column(name = "glucose_value")
    private Integer glucoseValue;

    @Column(nullable = false, columnDefinition = "TEXT")
    private String message;

    @Column(name = "notified_users", columnDefinition = "uuid[]")
    private UUID[] notifiedUsers = new UUID[0];

    @Column(name = "is_read", nullable = false)
    private Boolean isRead = false;

    @Column(name = "triggered_at", updatable = false)
    private OffsetDateTime triggeredAt;

    @PrePersist
    void prePersist() {
        if (triggeredAt == null) triggeredAt = OffsetDateTime.now();
    }
}
