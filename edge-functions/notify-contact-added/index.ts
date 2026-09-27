// notify-contact-added/index.ts
// Sends an invitation notification when a contact is added to Last Post.
// Priority: email (with Accept/Decline buttons) → SMS only if no email.

const RESEND_API_KEY = Deno.env.get("RESEND_API_KEY")           ?? "";
const TWILIO_SID     = Deno.env.get("TWILIO_ACCOUNT_SID")       ?? "";
const TWILIO_TOKEN   = Deno.env.get("TWILIO_AUTH_TOKEN")        ?? "";
const TWILIO_FROM    = Deno.env.get("TWILIO_PHONE_NUMBER")      ?? "";
const SUPABASE_URL   = Deno.env.get("SUPABASE_URL")             ?? "";
const SUPABASE_KEY   = Deno.env.get("SERVICE_ROLE_KEY") ?? "";

const CORS = {
  "Access-Control-Allow-Origin":  "*",
  "Access-Control-Allow-Headers": "authorization, x-client-info, apikey, content-type",
};

Deno.serve(async (req) => {
  if (req.method === "OPTIONS") return new Response("ok", { headers: CORS });

  try {
    const body = await req.json();
    const {
      ownerName        = "Someone",
      contactFirstName = "",
      contactLastName  = "",
      contactName,
      contactEmail     = "",
      contactPhone     = "",
      relationship     = "contact",
      ownerSupabaseId  = "",
    } = body;

    const fullName = contactName ?? `${contactFirstName} ${contactLastName}`.trim();
    const hasEmail = contactEmail.trim().length > 0;
    const hasPhone = contactPhone.trim().length > 0;

    // --- Generate and store an acceptance token if we have a Supabase context ---
    let acceptUrl  = "";
    let declineUrl = "";

    if (hasEmail && ownerSupabaseId && SUPABASE_URL && SUPABASE_KEY) {
      const token = crypto.randomUUID();
      const tokenExpiry = new Date(Date.now() + 30 * 24 * 60 * 60 * 1000).toISOString();

      await fetch(`${SUPABASE_URL}/rest/v1/invitation_tokens`, {
        method: "POST",
        headers: {
          "Content-Type": "application/json",
          "apikey": SUPABASE_KEY,
          "Authorization": `Bearer ${SUPABASE_KEY}`,
          "Prefer": "resolution=merge-duplicates",
        },
        body: JSON.stringify({
          token,
          owner_id: ownerSupabaseId,
          email:    contactEmail.trim(),
        }),
      });

      const base = `${SUPABASE_URL}/functions/v1/accept-contact-invitation`;
      acceptUrl  = `${base}?token=${token}&action=accept`;
      declineUrl = `${base}?token=${token}&action=decline`;
    }

    // ── EMAIL (preferred) ────────────────────────────────────────────────────
    if (hasEmail) {
      const acceptButton = acceptUrl
        ? `<a href="${acceptUrl}" style="display:inline-block;background:#7c3aed;color:#fff;padding:12px 24px;border-radius:8px;text-decoration:none;font-weight:600;margin-right:12px;">Accept</a>`
        : "";
      const declineButton = declineUrl
        ? `<a href="${declineUrl}" style="display:inline-block;background:#e5e7eb;color:#374151;padding:12px 24px;border-radius:8px;text-decoration:none;font-weight:600;">Decline</a>`
        : "";

      const html = `
        <div style="font-family:sans-serif;max-width:560px;margin:0 auto;padding:24px;">
          <h2 style="color:#111827;">You've been added to Last Post</h2>
          <p style="color:#374151;">Hi ${contactFirstName || fullName},</p>
          <p style="color:#374151;">
            <strong>${ownerName}</strong> has added you as a ${relationship} on
            <strong>Last Post</strong> — an app that ensures the people who matter
            are notified if they pass away.
          </p>
          <p style="color:#374151;">
            If they pass away, you will receive a notification letting you know.
            You don't need to do anything right now.
          </p>
          ${acceptUrl ? `
          <p style="color:#374151;margin-top:24px;">Please confirm you're happy to be included:</p>
          <div style="margin:24px 0;">${acceptButton}${declineButton}</div>` : ""}
          <hr style="border:none;border-top:1px solid #e5e7eb;margin:32px 0;" />
          <p style="color:#9ca3af;font-size:12px;">
            Last Post — <a href="https://lastpost.app" style="color:#7c3aed;">lastpost.app</a>
          </p>
        </div>`;

      await fetch("https://api.resend.com/emails", {
        method: "POST",
        headers: {
          "Content-Type": "application/json",
          "Authorization": `Bearer ${RESEND_API_KEY}`,
        },
        body: JSON.stringify({
          from:    "Last Post <noreply@lastpost.app>",
          to:      [contactEmail.trim()],
          subject: `${ownerName} has added you to Last Post`,
          html,
        }),
      });

      return new Response(JSON.stringify({ ok: true, channel: "email" }), {
        headers: { ...CORS, "Content-Type": "application/json" },
      });
    }

    // ── SMS fallback (only when no email) ───────────────────────────────────
    if (hasPhone && TWILIO_SID && TWILIO_TOKEN && TWILIO_FROM) {
      const message =
        `${ownerName} has added you as a contact on Last Post. ` +
        `If they pass away, you will be notified. No action needed right now. ` +
        `lastpost.app`;

      const params = new URLSearchParams({
        From: TWILIO_FROM,
        To:   contactPhone.trim(),
        Body: message,
      });

      await fetch(
        `https://api.twilio.com/2010-04-01/Accounts/${TWILIO_SID}/Messages.json`,
        {
          method: "POST",
          headers: {
            "Content-Type": "application/x-www-form-urlencoded",
            "Authorization": `Basic ${btoa(`${TWILIO_SID}:${TWILIO_TOKEN}`)}`,
          },
          body: params.toString(),
        }
      );

      return new Response(JSON.stringify({ ok: true, channel: "sms" }), {
        headers: { ...CORS, "Content-Type": "application/json" },
      });
    }

    return new Response(JSON.stringify({ ok: false, reason: "no contact method" }), {
      headers: { ...CORS, "Content-Type": "application/json" },
    });

  } catch (err) {
    return new Response(JSON.stringify({ error: String(err) }), {
      status: 500,
      headers: { ...CORS, "Content-Type": "application/json" },
    });
  }
});
