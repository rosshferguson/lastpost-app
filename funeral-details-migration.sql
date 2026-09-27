-- funeral-details-migration.sql
-- Tracks whether the designated person has sent funeral details to contacts.
-- Run this in the Supabase SQL editor.

ALTER TABLE death_notifications
  ADD COLUMN IF NOT EXISTS funeral_details_sent_at TIMESTAMPTZ;
