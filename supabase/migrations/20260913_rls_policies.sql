-- RLS POLICIES FOR LAST POST
-- Safe to re-run: each policy is dropped before being recreated.
-- death_notifications is excluded — it is not accessed directly by the app.
-- user_contacts already has RLS; the old catch-all policy is replaced below.

-- 1. profiles

ALTER TABLE profiles ENABLE ROW LEVEL SECURITY;

DROP POLICY IF EXISTS "profiles: owner read"   ON profiles;
DROP POLICY IF EXISTS "profiles: owner update" ON profiles;
DROP POLICY IF EXISTS "profiles: owner insert" ON profiles;

CREATE POLICY "profiles: owner read"
  ON profiles FOR SELECT
  USING (auth.uid()::text = id::text);

CREATE POLICY "profiles: owner update"
  ON profiles FOR UPDATE
  USING (auth.uid()::text = id::text);

CREATE POLICY "profiles: owner insert"
  ON profiles FOR INSERT
  WITH CHECK (auth.uid()::text = id::text);

-- 2. designated_persons

ALTER TABLE designated_persons ENABLE ROW LEVEL SECURITY;

DROP POLICY IF EXISTS "designated_persons: owner read"         ON designated_persons;
DROP POLICY IF EXISTS "designated_persons: owner insert"       ON designated_persons;
DROP POLICY IF EXISTS "designated_persons: owner update"       ON designated_persons;
DROP POLICY IF EXISTS "designated_persons: owner delete"       ON designated_persons;
DROP POLICY IF EXISTS "designated_persons: linked person read"  ON designated_persons;
DROP POLICY IF EXISTS "designated_persons: linked person accept" ON designated_persons;

CREATE POLICY "designated_persons: owner read"
  ON designated_persons FOR SELECT
  USING (auth.uid()::text = owner_id::text);

CREATE POLICY "designated_persons: owner insert"
  ON designated_persons FOR INSERT
  WITH CHECK (auth.uid()::text = owner_id::text);

CREATE POLICY "designated_persons: owner update"
  ON designated_persons FOR UPDATE
  USING (auth.uid()::text = owner_id::text);

CREATE POLICY "designated_persons: owner delete"
  ON designated_persons FOR DELETE
  USING (auth.uid()::text = owner_id::text);

CREATE POLICY "designated_persons: linked person read"
  ON designated_persons FOR SELECT
  USING (auth.uid()::text = linked_profile_id::text);

CREATE POLICY "designated_persons: linked person accept"
  ON designated_persons FOR UPDATE
  USING (auth.uid()::text = linked_profile_id::text)
  WITH CHECK (auth.uid()::text = linked_profile_id::text);

-- 3. invitation_tokens

ALTER TABLE invitation_tokens ENABLE ROW LEVEL SECURITY;

DROP POLICY IF EXISTS "invitation_tokens: owner read" ON invitation_tokens;

CREATE POLICY "invitation_tokens: owner read"
  ON invitation_tokens FOR SELECT
  USING (auth.uid()::text = owner_id::text);

-- 4. user_contacts (already has RLS; replace the old catch-all policy)

ALTER TABLE user_contacts ENABLE ROW LEVEL SECURITY;

DROP POLICY IF EXISTS "Users manage their own contacts" ON user_contacts;
DROP POLICY IF EXISTS "user_contacts: owner read"   ON user_contacts;
DROP POLICY IF EXISTS "user_contacts: owner insert" ON user_contacts;
DROP POLICY IF EXISTS "user_contacts: owner update" ON user_contacts;
DROP POLICY IF EXISTS "user_contacts: owner delete" ON user_contacts;

CREATE POLICY "user_contacts: owner read"
  ON user_contacts FOR SELECT
  USING (auth.uid()::text = owner_id::text);

CREATE POLICY "user_contacts: owner insert"
  ON user_contacts FOR INSERT
  WITH CHECK (auth.uid()::text = owner_id::text);

CREATE POLICY "user_contacts: owner update"
  ON user_contacts FOR UPDATE
  USING (auth.uid()::text = owner_id::text);

CREATE POLICY "user_contacts: owner delete"
  ON user_contacts FOR DELETE
  USING (auth.uid()::text = owner_id::text);
