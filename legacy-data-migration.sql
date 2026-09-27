-- legacy-data-migration.sql
-- Run this in the Supabase SQL editor.
-- Adds four JSONB columns to profiles for legacy data that the
-- designated person can access after the notification is confirmed.

ALTER TABLE profiles
  ADD COLUMN IF NOT EXISTS funeral_wishes_data   JSONB,
  ADD COLUMN IF NOT EXISTS important_documents_data JSONB,
  ADD COLUMN IF NOT EXISTS digital_assets_data   JSONB,
  ADD COLUMN IF NOT EXISTS life_history_data     JSONB;
