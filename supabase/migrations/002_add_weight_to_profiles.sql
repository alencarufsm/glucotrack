-- Migration: 002_add_weight_to_profiles.sql
-- Adiciona campo de peso ao perfil do usuário

ALTER TABLE profiles ADD COLUMN weight DECIMAL(5,2);
