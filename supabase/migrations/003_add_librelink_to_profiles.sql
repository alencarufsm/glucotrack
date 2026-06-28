-- Integração FreeStyle Libre 2 Plus via LibreLink Up API (Abbott)
-- As credenciais são armazenadas por usuário para permitir sync server-side.
-- Nota: em produção, librelink_password deve ser criptografado (pgcrypto ou similar).

ALTER TABLE profiles
  ADD COLUMN IF NOT EXISTS librelink_email       VARCHAR(255),
  ADD COLUMN IF NOT EXISTS librelink_password    VARCHAR(255),
  ADD COLUMN IF NOT EXISTS librelink_patient_id  VARCHAR(255),
  ADD COLUMN IF NOT EXISTS librelink_patient_name VARCHAR(255),
  ADD COLUMN IF NOT EXISTS librelink_last_sync   TIMESTAMPTZ;
