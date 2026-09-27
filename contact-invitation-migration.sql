-- contact-invitation-migration.sql
-- Adds acceptance token and invitation status columns to the contacts table.
-- Run this in the Supabase SQL editor.

ALTER TABLE contacts
  ADD COLUMN IF NOT EXISTS acceptance_token TEXT UNIQUE,
  ADD COLUMN IF NOT EXISTS invitation_accepted BOOLEAN DEFAULT FALSE,
  ADD COLUMN IF NOT EXISTS invitation_declined BOOLEAN DEFAULT FALSE;

-- Create an index so token lookups are fast
CREATE INDEX IF NOT EXISTS contacts_acceptance_token_idx
  ON contacts (acceptance_token)
  WHERE acceptance_token IS NOT NULL;

-- Grandfather in all existing contacts (they were added before the
-- acceptance flow existed, so treat them as implicitly accepted).
UPDATE contacts
  SET invitation_accepted = TRUE
  WHERE invitation_accepted = FALSE
    AND acceptance_token IS NULL;
