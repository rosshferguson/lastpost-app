-- SMS / phone number migration
-- Run in Supabase SQL editor
--
-- Adds phone_number to designated_persons so welfare-check and
-- invitation edge functions can send SMS alongside email.

ALTER TABLE designated_persons
  ADD COLUMN IF NOT EXISTS phone_number TEXT NOT NULL DEFAULT '';
