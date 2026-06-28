package com.glucotrack.backend.entity;

import com.glucotrack.backend.enums.ConnectionStatus;
import jakarta.persistence.*;
import lombok.Getter;
import lombok.NoArgsConstructor;
import lombok.Setter;

import java.time.OffsetDateTime;
import java.util.UUID;

@Entity
@Table(name = "family_connections")
@Getter @Setter @NoArgsConstructor
public class FamilyConnection {

    @Id
    @GeneratedValue(strategy = GenerationType.UUID)
    private UUID id;

    // Quem está sendo monitorado (ex: pai, Alencar)
    @ManyToOne(fetch = FetchType.LAZY)
    @JoinColumn(name = "monitored_user_id", nullable = false)
    private Profile monitoredUser;

    // Quem observa (ex: irmão)
    @ManyToOne(fetch = FetchType.LAZY)
    @JoinColumn(name = "observer_user_id", nullable = false)
    private Profile observerUser;

    @Enumerated(EnumType.STRING)
    @Column(nullable = false)
    private ConnectionStatus status = ConnectionStatus.PENDING;

    @Column(name = "invited_at", updatable = false)
    private OffsetDateTime invitedAt;

    @Column(name = "accepted_at")
    private OffsetDateTime acceptedAt;

    @PrePersist
    void prePersist() {
        if (invitedAt == null) invitedAt = OffsetDateTime.now();
    }
}
