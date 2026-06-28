-- =============================================================================
-- GlicoTrack — Schema inicial do banco de dados
-- Migration: 001_initial_schema.sql
-- =============================================================================
-- Usando VARCHAR + CHECK em vez de tipos ENUM customizados do PostgreSQL,
-- para compatibilidade direta com Spring Data JPA (@Enumerated(EnumType.STRING))
-- sem necessidade de conversores especiais.
-- =============================================================================

-- -----------------------------------------------------------------------------
-- PERFIS DE USUÁRIO
-- Estende o auth.users do Supabase com dados clínicos e preferências.
-- O registro é criado automaticamente via trigger quando o usuário se cadastra.
-- -----------------------------------------------------------------------------

CREATE TABLE profiles (
    id            UUID PRIMARY KEY REFERENCES auth.users(id) ON DELETE CASCADE,
    name          TEXT NOT NULL,
    birth_date    DATE,
    diabetes_type VARCHAR(20) NOT NULL DEFAULT 'NONE'
                  CHECK (diabetes_type IN ('TYPE_1', 'TYPE_2', 'PREDIABETES', 'NONE')),
    physical_limitations TEXT,
    target_min    INTEGER NOT NULL DEFAULT 70,
    target_max    INTEGER NOT NULL DEFAULT 180,
    created_at    TIMESTAMPTZ NOT NULL DEFAULT NOW(),
    updated_at    TIMESTAMPTZ NOT NULL DEFAULT NOW()
);

-- Trigger: cria perfil automaticamente quando usuário se cadastra no Supabase Auth
CREATE OR REPLACE FUNCTION handle_new_user()
RETURNS TRIGGER AS $$
BEGIN
    INSERT INTO profiles (id, name)
    VALUES (
        NEW.id,
        COALESCE(NEW.raw_user_meta_data->>'name', split_part(NEW.email, '@', 1))
    );
    RETURN NEW;
END;
$$ LANGUAGE plpgsql SECURITY DEFINER;

CREATE TRIGGER on_auth_user_created
    AFTER INSERT ON auth.users
    FOR EACH ROW EXECUTE FUNCTION handle_new_user();

-- Trigger: atualiza updated_at automaticamente
CREATE OR REPLACE FUNCTION update_updated_at()
RETURNS TRIGGER AS $$
BEGIN
    NEW.updated_at = NOW();
    RETURN NEW;
END;
$$ LANGUAGE plpgsql;

CREATE TRIGGER profiles_updated_at
    BEFORE UPDATE ON profiles
    FOR EACH ROW EXECUTE FUNCTION update_updated_at();

-- -----------------------------------------------------------------------------
-- MEDIÇÕES DE GLICEMIA
-- -----------------------------------------------------------------------------

CREATE TABLE glucose_readings (
    id           UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    user_id      UUID NOT NULL REFERENCES profiles(id) ON DELETE CASCADE,
    value        INTEGER NOT NULL CHECK (value > 0 AND value < 1000),
    measured_at  TIMESTAMPTZ NOT NULL DEFAULT NOW(),
    meal_context VARCHAR(20) NOT NULL DEFAULT 'OTHER'
                 CHECK (meal_context IN ('FASTING', 'PRE_MEAL', 'POST_MEAL', 'BEDTIME', 'OTHER')),
    source       VARCHAR(20) NOT NULL DEFAULT 'MANUAL'
                 CHECK (source IN ('MANUAL', 'CGM_IMPORT')),
    notes        TEXT,
    created_at   TIMESTAMPTZ NOT NULL DEFAULT NOW()
);

CREATE INDEX idx_glucose_readings_user_date ON glucose_readings(user_id, measured_at DESC);

-- -----------------------------------------------------------------------------
-- DOSES DE INSULINA (exclusivo para Tipo 1)
-- -----------------------------------------------------------------------------

CREATE TABLE insulin_doses (
    id           UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    user_id      UUID NOT NULL REFERENCES profiles(id) ON DELETE CASCADE,
    reading_id   UUID REFERENCES glucose_readings(id) ON DELETE SET NULL,
    insulin_type TEXT NOT NULL,
    dose_units   DECIMAL(5,1) NOT NULL CHECK (dose_units > 0),
    applied_at   TIMESTAMPTZ NOT NULL DEFAULT NOW(),
    notes        TEXT,
    created_at   TIMESTAMPTZ NOT NULL DEFAULT NOW()
);

CREATE INDEX idx_insulin_doses_user_date ON insulin_doses(user_id, applied_at DESC);

-- -----------------------------------------------------------------------------
-- REFEIÇÕES
-- -----------------------------------------------------------------------------

CREATE TABLE meals (
    id          UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    user_id     UUID NOT NULL REFERENCES profiles(id) ON DELETE CASCADE,
    description TEXT NOT NULL,
    logged_at   TIMESTAMPTZ NOT NULL DEFAULT NOW(),
    created_at  TIMESTAMPTZ NOT NULL DEFAULT NOW()
);

CREATE INDEX idx_meals_user_date ON meals(user_id, logged_at DESC);

-- -----------------------------------------------------------------------------
-- ATIVIDADES FÍSICAS
-- -----------------------------------------------------------------------------

CREATE TABLE physical_activities (
    id               UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    user_id          UUID NOT NULL REFERENCES profiles(id) ON DELETE CASCADE,
    activity_type    TEXT NOT NULL,
    duration_minutes INTEGER NOT NULL CHECK (duration_minutes > 0),
    intensity        VARCHAR(20) NOT NULL DEFAULT 'MODERATE'
                     CHECK (intensity IN ('LOW', 'MODERATE', 'HIGH')),
    performed_at     TIMESTAMPTZ NOT NULL DEFAULT NOW(),
    notes            TEXT,
    created_at       TIMESTAMPTZ NOT NULL DEFAULT NOW()
);

CREATE INDEX idx_activities_user_date ON physical_activities(user_id, performed_at DESC);

-- -----------------------------------------------------------------------------
-- CONEXÕES FAMILIARES
-- -----------------------------------------------------------------------------

CREATE TABLE family_connections (
    id                 UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    monitored_user_id  UUID NOT NULL REFERENCES profiles(id) ON DELETE CASCADE,
    observer_user_id   UUID NOT NULL REFERENCES profiles(id) ON DELETE CASCADE,
    status             VARCHAR(20) NOT NULL DEFAULT 'PENDING'
                       CHECK (status IN ('PENDING', 'ACTIVE', 'REJECTED')),
    invited_at         TIMESTAMPTZ NOT NULL DEFAULT NOW(),
    accepted_at        TIMESTAMPTZ,
    CONSTRAINT unique_connection UNIQUE (monitored_user_id, observer_user_id),
    CONSTRAINT no_self_connection CHECK (monitored_user_id != observer_user_id)
);

CREATE INDEX idx_connections_monitored ON family_connections(monitored_user_id);
CREATE INDEX idx_connections_observer  ON family_connections(observer_user_id);

-- -----------------------------------------------------------------------------
-- ALERTAS
-- -----------------------------------------------------------------------------

CREATE TABLE alerts (
    id             UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    user_id        UUID NOT NULL REFERENCES profiles(id) ON DELETE CASCADE,
    reading_id     UUID REFERENCES glucose_readings(id) ON DELETE SET NULL,
    alert_type     VARCHAR(30) NOT NULL
                   CHECK (alert_type IN ('HYPOGLYCEMIA_SEVERE', 'HYPOGLYCEMIA', 'HYPERGLYCEMIA',
                                         'HYPERGLYCEMIA_SEVERE', 'RAPID_FALL', 'RAPID_RISE', 'REMINDER')),
    severity       VARCHAR(20) NOT NULL
                   CHECK (severity IN ('INFO', 'WARNING', 'CRITICAL', 'EMERGENCY')),
    glucose_value  INTEGER,
    message        TEXT NOT NULL,
    notified_users UUID[] NOT NULL DEFAULT '{}',
    is_read        BOOLEAN NOT NULL DEFAULT FALSE,
    triggered_at   TIMESTAMPTZ NOT NULL DEFAULT NOW()
);

CREATE INDEX idx_alerts_user_date   ON alerts(user_id, triggered_at DESC);
CREATE INDEX idx_alerts_user_unread ON alerts(user_id, is_read) WHERE is_read = FALSE;

-- =============================================================================
-- ROW LEVEL SECURITY (RLS)
-- =============================================================================

ALTER TABLE profiles            ENABLE ROW LEVEL SECURITY;
ALTER TABLE glucose_readings    ENABLE ROW LEVEL SECURITY;
ALTER TABLE insulin_doses       ENABLE ROW LEVEL SECURITY;
ALTER TABLE meals               ENABLE ROW LEVEL SECURITY;
ALTER TABLE physical_activities ENABLE ROW LEVEL SECURITY;
ALTER TABLE family_connections  ENABLE ROW LEVEL SECURITY;
ALTER TABLE alerts              ENABLE ROW LEVEL SECURITY;

-- profiles
CREATE POLICY "profiles: user reads own" ON profiles
    FOR SELECT USING (auth.uid() = id);

CREATE POLICY "profiles: user updates own" ON profiles
    FOR UPDATE USING (auth.uid() = id);

CREATE POLICY "profiles: observer reads connected" ON profiles
    FOR SELECT USING (
        EXISTS (
            SELECT 1 FROM family_connections
            WHERE monitored_user_id = profiles.id
              AND observer_user_id = auth.uid()
              AND status = 'ACTIVE'
        )
    );

-- glucose_readings
CREATE POLICY "readings: user reads own" ON glucose_readings
    FOR SELECT USING (auth.uid() = user_id);

CREATE POLICY "readings: user inserts own" ON glucose_readings
    FOR INSERT WITH CHECK (auth.uid() = user_id);

CREATE POLICY "readings: user deletes own" ON glucose_readings
    FOR DELETE USING (auth.uid() = user_id);

CREATE POLICY "readings: observer reads connected" ON glucose_readings
    FOR SELECT USING (
        EXISTS (
            SELECT 1 FROM family_connections
            WHERE monitored_user_id = glucose_readings.user_id
              AND observer_user_id = auth.uid()
              AND status = 'ACTIVE'
        )
    );

-- insulin_doses
CREATE POLICY "insulin: user reads own" ON insulin_doses
    FOR SELECT USING (auth.uid() = user_id);

CREATE POLICY "insulin: user inserts own" ON insulin_doses
    FOR INSERT WITH CHECK (auth.uid() = user_id);

CREATE POLICY "insulin: observer reads connected" ON insulin_doses
    FOR SELECT USING (
        EXISTS (
            SELECT 1 FROM family_connections
            WHERE monitored_user_id = insulin_doses.user_id
              AND observer_user_id = auth.uid()
              AND status = 'ACTIVE'
        )
    );

-- meals
CREATE POLICY "meals: user reads own" ON meals
    FOR SELECT USING (auth.uid() = user_id);

CREATE POLICY "meals: user inserts own" ON meals
    FOR INSERT WITH CHECK (auth.uid() = user_id);

CREATE POLICY "meals: observer reads connected" ON meals
    FOR SELECT USING (
        EXISTS (
            SELECT 1 FROM family_connections
            WHERE monitored_user_id = meals.user_id
              AND observer_user_id = auth.uid()
              AND status = 'ACTIVE'
        )
    );

-- physical_activities
CREATE POLICY "activities: user reads own" ON physical_activities
    FOR SELECT USING (auth.uid() = user_id);

CREATE POLICY "activities: user inserts own" ON physical_activities
    FOR INSERT WITH CHECK (auth.uid() = user_id);

CREATE POLICY "activities: observer reads connected" ON physical_activities
    FOR SELECT USING (
        EXISTS (
            SELECT 1 FROM family_connections
            WHERE monitored_user_id = physical_activities.user_id
              AND observer_user_id = auth.uid()
              AND status = 'ACTIVE'
        )
    );

-- family_connections
CREATE POLICY "connections: user reads own" ON family_connections
    FOR SELECT USING (
        auth.uid() = monitored_user_id OR auth.uid() = observer_user_id
    );

CREATE POLICY "connections: monitored user invites" ON family_connections
    FOR INSERT WITH CHECK (auth.uid() = monitored_user_id);

CREATE POLICY "connections: observer accepts" ON family_connections
    FOR UPDATE USING (auth.uid() = observer_user_id);

CREATE POLICY "connections: either party deletes" ON family_connections
    FOR DELETE USING (
        auth.uid() = monitored_user_id OR auth.uid() = observer_user_id
    );

-- alerts
CREATE POLICY "alerts: user reads own" ON alerts
    FOR SELECT USING (auth.uid() = user_id OR auth.uid() = ANY(notified_users));

CREATE POLICY "alerts: user marks read" ON alerts
    FOR UPDATE USING (auth.uid() = user_id OR auth.uid() = ANY(notified_users));
