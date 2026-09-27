-- web-trigger-migration.sql
-- Run in Supabase Dashboard → SQL Editor
--
-- 1. Adds trigger_token to designated_persons (auto-generated UUID per person)
-- 2. Creates user_contacts table so the web trigger can send notifications
--    without the iOS app being open

-- ── 1. trigger_token on designated_persons ────────────────────────────────────

ALTER TABLE designated_persons
ADD COLUMN IF NOT EXISTS trigger_token TEXT UNIQUE DEFAULT gen_random_uuid()::text;

-- Backfill any existing rows that have a NULL trigger_token
UPDATE designated_persons
SET trigger_token = gen_random_uuid()::text
WHERE trigger_token IS NULL;

-- ── 2. user_contacts table ────────────────────────────────────────────────────
-- Mirrors the iOS SwiftData Contact model; synced whenever contacts change.
-- The web-trigger-notifications edge function reads from here.

CREATE TABLE IF NOT EXISTS user_contacts (
  id               UUID        PRIMARY KEY DEFAULT gen_random_uuid(),
  owner_id         UUID        NOT NULL REFERENCES auth.users(id) ON DELETE CASCADE,
  local_id         TEXT        NOT NULL,                      -- SwiftData UUID string
  first_name       TEXT        NOT NULL DEFAULT '',
  last_name        TEXT        NOT NULL DEFAULT '',
  email            TEXT                 DEFAULT '',
  phone_number     TEXT                 DEFAULT '',
  personal_message TEXT                 DEFAULT '',
  group_name       TEXT,
  created_at       TIMESTAMPTZ          DEFAULT NOW(),
  updated_at       TIMESTAMPTZ          DEFAULT NOW(),
  UNIQUE (owner_id, local_id)
);

-- Row-level security: owners can only see/edit their own contacts
ALTER TABLE user_contacts ENABLE ROW LEVEL SECURITY;

DROP POLICY IF EXISTS "Users manage their own contacts" ON user_contacts;
CREATE POLICY "Users manage their own contacts"
  ON user_contacts FOR ALL
  USING      (auth.uid() = owner_id)
  WITH CHECK (auth.uid() = owner_id);

-- Index to speed up the per-owner lookup in web-trigger-notifications
CREATE INDEX IF NOT EXISTS user_contacts_owner_idx ON user_contacts (owner_id);
