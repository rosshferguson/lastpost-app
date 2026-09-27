# Last Post — Project Brief & Handoff Document

This document gives a new Claude session full context to continue developing the Last Post iOS app. Read this before asking any questions.

---

## What the App Is

**Last Post** is an iOS app that helps people notify their friends and family when they pass away. Users set up a list of contacts and designate a trusted person (a "designated person") who will trigger notifications after the user's death. The app handles the entire notification flow — emails, SMS, funeral wishes, digital asset records, and more.

- **App name:** Last Post
- **Bundle ID:** RF.FinalFarewell
- **Xcode project folder:** `~/Desktop/FinalFarewell/FinalFarewell.xcodeproj`
- **Website:** https://lastpost.app (GitHub Pages repo: `rosshferguson/lastpost-app`)
- **App Store:** Submitted for review (as of August 2026), pending approval
- **TestFlight:** Live

---

## Technical Stack

| Layer | Technology |
|-------|-----------|
| iOS app | SwiftUI + SwiftData |
| Backend | Supabase (PostgreSQL + Edge Functions) |
| Email | Resend API (`noreply@lastpost.app`) |
| SMS | Twilio (UK number: +447462165308) |
| Auth | Supabase Auth (email/password) |
| Subscriptions | StoreKit 2 / App Store Connect |
| Website | GitHub Pages (static HTML) |

---

## Key References

| Item | Value |
|------|-------|
| Supabase project ref | `kypzbbupzuaukdkjeghu` |
| Supabase URL | `https://kypzbbupzuaukdkjeghu.supabase.co` |
| Twilio account SID | `AC2a27d8f4f2baf30c546fb24934aa5a0d` |
| Twilio from number | `+447462165308` |
| Resend domain | `lastpost.app` |
| App reviewer account | `rossmrpharms+appreviewer@gmail.com` |
| Ross's email | `rossmrpharms@gmail.com` |

> **Note:** Twilio Auth Token and Supabase Service Role Key are stored as Supabase secrets and should NOT be hardcoded anywhere.

---

## Supabase Edge Functions

All functions are in `~/Desktop/FinalFarewell/supabase/functions/`. Deploy with:

```bash
supabase functions deploy <function-name> --project-ref kypzbbupzuaukdkjeghu --no-verify-jwt
```

| Function | Purpose |
|----------|---------|
| `notify-designated-person` | Sends invitation email (+ SMS) when user adds a designated person. Email is **required** — designated persons must have an email to use the app. |
| `accept-designated-invitation` | Handles Accept/Decline clicks from the invitation email. |
| `sync-designated-person` | Upserts designated person record in Supabase. |
| `notify-contact-added` | Emails a contact when they're added to someone's list (with Accept/Decline buttons). |
| `accept-contact-invitation` | Handles Accept/Decline from contact invitation email. |
| `send-death-notifications` | Called from the iOS app after confirmation. Sends death notification **email** to contacts with email, or **SMS** (Twilio) to contacts with only a phone number. |
| `web-trigger-notifications` | Same as above but triggered from `trigger.html` via a web link. Also sends legacy summary email to the designated person. |
| `send-funeral-details` | Sends funeral arrangement details to contacts who opted in. Can be sent multiple times. |
| `request-welfare-check` | Emails (+ SMS) designated persons when the owner requests a wellness check. |
| `get-legacy-data` | Returns the owner's funeral wishes, documents, digital assets, and life history for the designated person to view. |
| `get-trigger-info` | Returns owner info from a trigger token (used by trigger.html). |
| `sync-contacts` | Syncs contacts from the iOS app to the `user_contacts` Supabase table. |

### SMS logic (important)
- **Contacts:** Email is primary channel. SMS (Twilio) fires only as a **fallback** when a contact has no email address.
- **Designated persons:** Email is **mandatory** (needed for app sign-up and trigger link). SMS is sent *additionally* as a supplement if they have a phone number.

---

## Database Tables (Supabase)

| Table | Purpose |
|-------|---------|
| `profiles` | One row per user. Stores name, email, phone. Also has JSONB columns: `funeral_wishes_data`, `important_documents_data`, `digital_assets_data`, `life_history_data`. |
| `designated_persons` | Designated persons linked to an owner. Key columns: `owner_id`, `email`, `phone_number`, `invitation_accepted`, `acceptance_token`, `trigger_token`, `can_view_arrangements`. |
| `user_contacts` | Contacts synced from the iOS app. Columns: `owner_id`, `local_id`, `first_name`, `last_name`, `email`, `phone_number`, `personal_message`, `group_name`. |
| `death_notifications` | Records of death notification events. Includes `funeral_details_sent_at`. |
| `invitation_tokens` | Stores acceptance tokens for contact invitations. |

---

## iOS App Structure

```
FinalFarewell/
├── Models/
│   ├── User.swift              — SwiftData model, owns contacts + designated persons
│   ├── Contact.swift           — Contact model (name, email, phoneNumber, personalMessage, group, wantsFuneralDetails)
│   └── DesignatedPerson.swift  — Designated person model (name, email, phoneNumber, relationship, canViewArrangements, linkedUserId, invitationAccepted, triggerToken)
├── ViewModels/
│   ├── SupabaseService.swift   — All Supabase API calls and edge function calls
│   ├── UserViewModel.swift     — Current user state
│   ├── ContactsViewModel.swift — Contacts list management + syncContacts()
│   └── NotificationViewModel.swift — Handles dry run + real notification flow
├── Views/
│   ├── Home/
│   │   ├── HomeView.swift
│   │   └── SetupChecklistView.swift  — 5-step setup checklist incl. Apple Legacy Contact
│   ├── Auth/
│   │   └── AuthView.swift
│   ├── Contacts/
│   │   └── AddContactView.swift      — Add/edit contact, includes phone number field
│   ├── Designated/
│   │   ├── AddDesignatedPersonView.swift
│   │   ├── DesignatedModeView.swift  — View shown when logged in as designated person
│   │   ├── DesignatedLegacyView.swift — Shows owner's legacy info to designated person
│   │   └── SendFuneralDetailsView.swift
│   ├── Notification/
│   │   └── DryRunView.swift          — 4-step dry run flow + DryRunSummaryView
│   ├── Settings/
│   │   └── SettingsView.swift
│   └── Legacy/
│       ├── FuneralWishesView.swift
│       ├── DocumentsChecklistView.swift
│       ├── DigitalAssetsView.swift
│       └── LifeHistoryView.swift
```

---

## Subscriptions / IAP

- **Product:** Last Post Annual
- **Subscription group:** Last Post Premium
- **StoreKit file:** `FinalFarewell/Products.storekit`
- **SubscriptionService.swift** handles purchase/restore
- **PaywallView.swift** shown when a free user tries a premium feature
- Features gated behind subscription: designated persons, contacts beyond 2, wellness check, funeral details

---

## Website (`~/Desktop/FinalFarewell/index.html`)

Published via the `rosshferguson/lastpost-app` GitHub repo (GitHub Pages). Files to upload there:
- `index.html`
- `privacy.html`
- `icon.png` (app icon, dark green with white lily + LP)
- `screenshot.png`, `screenshot2.png`, `screenshot3.png`

Design: dark green (`#173027`) and purple hybrid. Headline: "Making difficult times a little easier."

---

## App Store Status (as of August 2026)

- **Version:** 1.0 (build uploaded to App Store Connect)
- **Status:** Under review (resubmitted after rejection for missing IAP screenshot)
- **Previous rejection reason:** IAP/subscription not submitted alongside app (Guideline 2.1b). Fixed by adding subscription group localization and uploading paywall screenshot.
- **Reviewer account:** `rossmrpharms+appreviewer@gmail.com`

---

## Pending / To Do After App Store Approval

1. **Twilio compliance** — Upgrade Twilio account from trial and submit a Primary Customer Profile (PCP). This removes the restriction that prevents SMS sending to non-verified numbers. Until this is done, SMS only works to verified numbers.
2. **Deploy updated edge functions** — `send-death-notifications` and `web-trigger-notifications` were updated (SMS now fallback-only for contacts without email) but need deploying from terminal:
   ```bash
   cd ~/Desktop/FinalFarewell
   supabase functions deploy send-death-notifications --project-ref kypzbbupzuaukdkjeghu --no-verify-jwt
   supabase functions deploy web-trigger-notifications --project-ref kypzbbupzuaukdkjeghu --no-verify-jwt
   ```
3. **Website screenshots** — `screenshot2.png` and `screenshot3.png` still need uploading to the GitHub Pages repo.

---

## Important Conventions & Decisions

- **`#if DEBUG`** used throughout for debug-only features (these are automatically stripped from release builds — no manual cleanup needed).
- **`@AppStorage("debugOverridePremium")`** persists in UserDefaults across builds — clear by deleting and reinstalling the app.
- **`@AppStorage("appleLegacyContactDone")`** tracks whether user has set up Apple Legacy Contact.
- **Phone normalisation** in edge functions: `07xxxxxxxxx` → `+447xxxxxxxxx` for UK numbers.
- **Dry run** uses 60-second waiting period instead of 24 hours.
- **Designated person linking:** When a designated person signs in, `fetchAndLinkDesignations()` runs to auto-link their account using their email.
- All edge functions are **self-contained single files** (no shared modules) to avoid Deno import issues.
- JWT verification is disabled (`--no-verify-jwt`) on all functions because some are called unauthenticated (e.g. web trigger, invitation acceptance).

---

*Document generated August 2026. Ross's working folder is `~/Desktop/FinalFarewell`.*
