-- Fix 1: adiciona LIBRE ao CHECK de source em glucose_readings
ALTER TABLE glucose_readings
  DROP CONSTRAINT IF EXISTS glucose_readings_source_check;

ALTER TABLE glucose_readings
  ADD CONSTRAINT glucose_readings_source_check
  CHECK (source IN ('MANUAL', 'CGM_IMPORT', 'LIBRE'));

-- Fix 2: índice único parcial para evitar duplicatas de leituras do sensor.
-- Usa índice parcial (WHERE source = 'LIBRE') para não impactar leituras manuais,
-- que podem ter timestamps coincidentes em situações normais.
CREATE UNIQUE INDEX IF NOT EXISTS idx_unique_libre_reading
  ON glucose_readings(user_id, measured_at)
  WHERE source = 'LIBRE';
