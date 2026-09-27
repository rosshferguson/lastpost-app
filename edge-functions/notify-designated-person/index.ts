// notify-designated-person/index.ts
// Sends an invitation to a newly added designated person.
// Priority: email (with Accept button + trigger link) → SMS only if no email.
// Fetches the acceptance_token from Supabase using owner_id + email.

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
      owner_name              = "Someone",
      designated_person_name  = "",
      designated_person_email = "",
      designated_person_phone = "",
      relationship            = "trusted person",
      invite_link             = "",
      can_access_photos       = false,
      can_view_arrangements   = true,
      owner_id                = "",
    } = body;

    const hasEmail = designated_person_email.trim().length > 0;
    const hasPhone = designated_person_phone.trim().length > 0;

    // Fetch acceptance_token from Supabase designated_persons table
    let acceptUrl = "";
    if (hasEmail && owner_id && SUPABASE_URL && SUPABASE_KEY) {
      const encoded = encodeURIComponent(designated_person_email.trim());
      const res = await fetch(
        `${SUPABASE_URL}/rest/v1/designated_persons?owner_id=eq.${owner_id}&email=eq.${encoded}&select=acceptance_token`,
        {
          headers: {
            "apikey": SUPABASE_KEY,
            "Authorization": `Bearer ${SUPABASE_KEY}`,
          },
        }
      );
      if (res.ok) {
        const rows = await res.json();
        const token = rows?.[0]?.acceptance_token;
        if (token) {
          acceptUrl = `${SUPABASE_URL}/functions/v1/accept-designated-invitation?token=${token}`;
        }
      }
    }

    // ── EMAIL (preferred) ────────────────────────────────────────────────────
    if (hasEmail) {
      const accessItems = [
        can_access_photos     ? "<li>Access to photos and memories</li>" : "",
        can_view_arrangements ? "<li>View funeral and end-of-life arrangements</li>" : "",
        "<li>Trigger the death notification process if the time comes</li>",
      ].filter(Boolean).join("");

      const acceptButton = acceptUrl
        ? `<div style="margin:24px 0;"><a href="${acceptUrl}" style="display:inline-block;background:#7c3aed;color:#fff;padding:12px 24px;border-radius:8px;text-decoration:none;font-weight:600;">Accept role</a></div>`
        : "";

      const triggerSection = invite_link
        ? `<p style="color:#374151;margin-top:24px;">If the time comes and you need to trigger notifications, you can do so here even without the app:</p>
           <p><a href="${invite_link}" style="color:#7c3aed;">${invite_link}</a></p>`
        : "";

      const html = `
        <div style="font-family:sans-serif;max-width:560px;margin:0 auto;padding:24px;">
          <h2 style="color:#111827;">You've been chosen as a designated person</h2>
          <p style="color:#374151;">Hi ${designated_person_name},</p>
          <p style="color:#374151;">
            <strong>${owner_name}</strong> has named you as their designated person
            on <strong>Last Post</strong>. This means they trust you to help notify
            their contacts if they pass away.
          </p>
          <p style="color:#374151;font-weight:600;">Your role includes:</p>
          <ul style="color:#374151;">${accessItems}</ul>
          ${acceptButton}
          ${triggerSection}
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
          to:      [designated_person_email.trim()],
          subject: `${owner_name} has named you as their designated person on Last Post`,
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
        `${owner_name} has named you as their designated person on Last Post. ` +
        `If they pass away, you'll be asked to help notify their contacts. ` +
        (invite_link ? `Trigger link: ${invite_link} ` : "") +
        `lastpost.app`;

      const params = new URLSearchParams({
        From: TWILIO_FROM,
        To:   designated_person_phone.trim(),
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
