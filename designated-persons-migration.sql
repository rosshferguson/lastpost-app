-- designated-persons-migration.sql
-- Creates the designated_persons table in Supabase.
-- Safe to re-run — uses IF NOT EXISTS guards throughout.
-- Run this in the Supabase SQL editor.

CREATE TABLE IF NOT EXISTS designated_persons (
  id                    UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  owner_id              UUID NOT NULL REFERENCES profiles(id) ON DELETE CASCADE,
  linked_profile_id     UUID REFERENCES profiles(id) ON DELETE SET NULL,
  first_name            TEXT NOT NULL DEFAULT '',
  last_name             TEXT NOT NULL DEFAULT '',
  email                 TEXT NOT NULL,
  relationship          TEXT NOT NULL DEFAULT '',
  invitation_accepted   BOOLEAN NOT NULL DEFAULT FALSE,
  can_access_photos     BOOLEAN NOT NULL DEFAULT FALSE,
  can_view_arrangements BOOLEAN NOT NULL DEFAULT TRUE,
  created_at            TIMESTAMPTZ NOT NULL DEFAULT now(),
  UNIQUE (owner_id, email)
);

-- Fast look-ups for the edge functions
CREATE INDEX IF NOT EXISTS idx_designated_persons_owner_id
  ON designated_persons (owner_id);

CREATE INDEX IF NOT EXISTS idx_designated_persons_linked_profile_id
  ON designated_persons (linked_profile_id)
  WHERE linked_profile_id IS NOT NULL;

CREATE INDEX IF NOT EXISTS idx_designated_persons_email
  ON designated_persons (email);

-- Row-level security — only service role can read/write
-- (all access goes through authenticated edge functions)
ALTER TABLE designated_persons ENABLE ROW LEVEL SECURITY;

DO $$
BEGIN
  IF NOT EXISTS (
    SELECT 1 FROM pg_policies
    WHERE tablename = 'designated_persons'
      AND policyname = 'Service role full access on designated_persons'
  ) THEN
    EXECUTE $policy$
      CREATE POLICY "Service role full access on designated_persons"
        ON designated_persons
        FOR ALL
        USING (auth.role() = 'service_role')
    $policy$;
  END IF;
END;
$$;
