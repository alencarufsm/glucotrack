package com.glucotrack.backend.repository;

import com.glucotrack.backend.entity.GlucoseReading;
import org.springframework.data.jpa.repository.JpaRepository;
import org.springframework.data.jpa.repository.Query;
import org.springframework.stereotype.Repository;

import java.time.OffsetDateTime;
import java.util.List;
import java.util.Optional;
import java.util.UUID;

@Repository
public interface GlucoseReadingRepository extends JpaRepository<GlucoseReading, UUID> {

    List<GlucoseReading> findByUserIdOrderByMeasuredAtDesc(UUID userId);

    List<GlucoseReading> findByUserIdAndMeasuredAtBetweenOrderByMeasuredAtDesc(
            UUID userId, OffsetDateTime from, OffsetDateTime to);

    Optional<GlucoseReading> findFirstByUserIdOrderByMeasuredAtDesc(UUID userId);

    // Busca as últimas N leituras — útil para calcular tendência de subida/queda
    @Query("SELECT r FROM GlucoseReading r WHERE r.user.id = :userId ORDER BY r.measuredAt DESC LIMIT :limit")
    List<GlucoseReading> findLastNByUserId(UUID userId, int limit);
}
