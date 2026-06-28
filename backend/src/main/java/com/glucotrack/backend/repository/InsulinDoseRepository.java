package com.glucotrack.backend.repository;

import com.glucotrack.backend.entity.InsulinDose;
import org.springframework.data.jpa.repository.JpaRepository;
import org.springframework.stereotype.Repository;

import java.time.OffsetDateTime;
import java.util.List;
import java.util.UUID;

@Repository
public interface InsulinDoseRepository extends JpaRepository<InsulinDose, UUID> {

    List<InsulinDose> findByUserIdAndAppliedAtBetweenOrderByAppliedAtDesc(
            UUID userId, OffsetDateTime from, OffsetDateTime to);
}
