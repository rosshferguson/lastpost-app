-- invitation_tokens table
-- Stores one-time tokens for contact invitation accept/decline links.
-- Run this in the Supabase Dashboard → SQL Editor.

CREATE TABLE IF NOT EXISTS invitation_tokens (
  token       TEXT PRIMARY KEY,
  owner_id    TEXT,
  first_name  TEXT NOT NULL DEFAULT '',
  last_name   TEXT NOT NULL DEFAULT '',
  email       TEXT NOT NULL,
  relationship TEXT NOT NULL DEFAULT '',
  created_at  TIMESTAMPTZ NOT NULL DEFAULT NOW(),
  used_at     TIMESTAMPTZ
);

-- Automatically expire tokens after 30 days (optional but tidy)
-- Requires pg_cron extension to be enabled, so leave commented unless you have it.
-- SELECT cron.schedule('delete-expired-tokens', '0 3 * * *',
--   'DELETE FROM invitation_tokens WHERE created_at < NOW() - INTERVAL ''30 days''');
