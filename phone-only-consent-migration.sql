-- phone-only-consent-migration.sql
-- Allows invitation_tokens to store phone-only contacts (no email required).
-- Run in Supabase Dashboard → SQL Editor.

-- 1. Make email nullable (was NOT NULL)
ALTER TABLE invitation_tokens
  ALTER COLUMN email DROP NOT NULL;

-- 2. Add phone_number column for phone-only contact tokens
ALTER TABLE invitation_tokens
  ADD COLUMN IF NOT EXISTS phone_number TEXT;

-- 3. Ensure contacts table has invitation_declined column (in case not already added)
ALTER TABLE contacts
  ADD COLUMN IF NOT EXISTS invitation_declined BOOLEAN DEFAULT FALSE;
