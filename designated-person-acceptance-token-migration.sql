-- Add acceptance_token to designated_persons so invitation emails can include
-- a one-click Accept link without requiring the recipient to have the app.

ALTER TABLE designated_persons
  ADD COLUMN IF NOT EXISTS acceptance_token UUID DEFAULT gen_random_uuid() NOT NULL;

-- Backfill any existing rows that got a null (shouldn't happen with DEFAULT, but just in case)
UPDATE designated_persons
  SET acceptance_token = gen_random_uuid()
  WHERE acceptance_token IS NULL;

-- Unique index so we can look up by token efficiently
CREATE UNIQUE INDEX IF NOT EXISTS designated_persons_acceptance_token_idx
  ON designated_persons (acceptance_token);
