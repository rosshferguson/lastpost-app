-- Add action column to invitation_tokens so we know accept vs decline.
-- Run in Supabase Dashboard → SQL Editor.

ALTER TABLE invitation_tokens ADD COLUMN IF NOT EXISTS action TEXT;

-- RLS policy: let authenticated users read their own tokens
DROP POLICY IF EXISTS "owner can read own tokens" ON invitation_tokens;
CREATE POLICY "owner can read own tokens"
  ON invitation_tokens
  FOR SELECT
  USING (auth.uid()::text = owner_id);
