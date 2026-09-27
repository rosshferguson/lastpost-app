# Web Trigger — Deployment Steps

## What was built

Non-iOS designated persons can now trigger notifications from any web browser using
a personal, one-time URL that arrives in their invitation email.

Flow: **invitation email → save the yellow link → visit link when needed →
two confirmation screens → notifications sent**

---

## Step 1: Run the SQL migration

Go to **Supabase Dashboard → SQL Editor** and run the contents of:
`supabase/web-trigger-migration.sql`

This adds:
- `trigger_token` column to `designated_persons` (auto-generated UUID)
- `user_contacts` table (mirrors iOS contacts for the web trigger to read)

---

## Step 2: Deploy the three new edge functions

```bash
cd /Users/ross/Desktop/FinalFarewell

supabase functions deploy sync-contacts \
  --project-ref kypzbbupzuaukdkjeghu --no-verify-jwt

supabase functions deploy get-trigger-info \
  --project-ref kypzbbupzuaukdkjeghu --no-verify-jwt

supabase functions deploy web-trigger-notifications \
  --project-ref kypzbbupzuaukdkjeghu --no-verify-jwt
```

---

## Step 3: Redeploy notify-designated-person

The invitation email now includes the yellow "Save this link" box with the
personal trigger URL. Redeploy so future invitations include it:

```bash
supabase functions deploy notify-designated-person \
  --project-ref kypzbbupzuaukdkjeghu --no-verify-jwt
```

---

## Step 4: Upload trigger.html to lastpost.app

Upload `static-pages/trigger.html` to your web host at:
**https://lastpost.app/trigger.html**

The page is self-contained — no build step, no dependencies.

---

## Step 5: Build and run the iOS app

The Swift changes are in:
- `SupabaseService.swift` — new `syncContacts()` method
- `ContactsViewModel.swift` — calls `syncContacts()` on add/update/delete

Contacts now sync to Supabase automatically whenever the user's list changes.
Existing contacts will sync on the next add/edit/delete, or you can add a
one-time sync call on app launch if you want immediate backfill.

---

## How it works end-to-end

1. User adds a designated person → `sync-designated-person` creates the row with
   a `trigger_token` (DB DEFAULT generates it automatically)
2. `notify-designated-person` fetches the `trigger_token` and adds a yellow
   "Save this link" box to the invitation email with the URL:
   `https://lastpost.app/trigger.html?token=<trigger_token>`
3. Designated person saves that link (bookmarks it, photos the screen, etc.)
4. When the time comes, they visit the link → the page calls `get-trigger-info`
   to show the owner name and contact count
5. Step 1: they confirm they understand what will happen
6. Step 2: they type **SEND** and press the red button
7. `web-trigger-notifications` fetches all contacts from `user_contacts` and
   sends the death notification email + SMS to each one

---

## Security notes

- The `trigger_token` is a UUID (128-bit random) — brute force is impossible
- It is sent only to the specific designated person's email address
- There is no way to cancel once sent — the two-step confirmation is the only guard
- If a designated person loses their link, the owner can re-send the invitation
  from the app (which generates a new email with the same token)
