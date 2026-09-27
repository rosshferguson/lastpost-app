// request-welfare-check/index.ts
// Sends a wellness check request to all designated persons.
// Priority: email → SMS only if no email.

const RESEND_API_KEY = Deno.env.get("RESEND_API_KEY")      ?? "";
const TWILIO_SID     = Deno.env.get("TWILIO_ACCOUNT_SID")  ?? "";
const TWILIO_TOKEN   = Deno.env.get("TWILIO_AUTH_TOKEN")   ?? "";
const TWILIO_FROM    = Deno.env.get("TWILIO_PHONE_NUMBER") ?? "";
const SUPABASE_URL   = Deno.env.get("SUPABASE_URL")        ?? "";
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
      owner_id   = "",
      owner_name = "Someone",
    } = body;

    // Fetch designated persons from Supabase
    let designatedPersons: { email: string; phone_number: string; first_name: string }[] = [];

    if (owner_id && SUPABASE_URL && SUPABASE_KEY) {
      const res = await fetch(
        `${SUPABASE_URL}/rest/v1/designated_persons?owner_id=eq.${owner_id}&select=first_name,email,phone_number`,
        {
          headers: {
            "apikey": SUPABASE_KEY,
            "Authorization": `Bearer ${SUPABASE_KEY}`,
          },
        }
      );
      if (res.ok) {
        designatedPersons = await res.json();
      }
    }

    if (designatedPersons.length === 0) {
      return new Response(JSON.stringify({ ok: false, reason: "no designated persons found" }), {
        headers: { ...CORS, "Content-Type": "application/json" },
      });
    }

    const results: { name: string; channel: string; ok: boolean }[] = [];

    for (const person of designatedPersons) {
      const hasEmail = (person.email ?? "").trim().length > 0;
      const hasPhone = (person.phone_number ?? "").trim().length > 0;

      // ── EMAIL (preferred) ──────────────────────────────────────────────
      if (hasEmail) {
        const html = `
          <div style="font-family:sans-serif;max-width:560px;margin:0 auto;padding:24px;">
            <h2 style="color:#111827;">Wellness check — ${owner_name}</h2>
            <p style="color:#374151;">Hi ${person.first_name},</p>
            <p style="color:#374151;">
              <strong>${owner_name}</strong> has requested a wellness check through
              Last Post. This is an automated message to let you know they would
              like someone to check in on them.
            </p>
            <p style="color:#374151;">
              Please reach out to them directly to make sure they're ok.
            </p>
            <hr style="border:none;border-top:1px solid #e5e7eb;margin:32px 0;" />
            <p style="color:#9ca3af;font-size:12px;">
              Last Post — <a href="https://lastpost.app" style="color:#7c3aed;">lastpost.app</a>
            </p>
          </div>`;

        const res = await fetch("https://api.resend.com/emails", {
          method: "POST",
          headers: {
            "Content-Type": "application/json",
            "Authorization": `Bearer ${RESEND_API_KEY}`,
          },
          body: JSON.stringify({
            from:    "Last Post <noreply@lastpost.app>",
            to:      [person.email.trim()],
            subject: `Wellness check request from ${owner_name}`,
            html,
          }),
        });

        results.push({ name: person.first_name, channel: "email", ok: res.ok });
        continue;
      }

      // ── SMS fallback (only when no email) ──────────────────────────────
      if (hasPhone && TWILIO_SID && TWILIO_TOKEN && TWILIO_FROM) {
        const message =
          `Last Post: ${owner_name} has requested a wellness check. ` +
          `Please reach out to them to make sure they're ok. — lastpost.app`;

        const params = new URLSearchParams({
          From: TWILIO_FROM,
          To:   person.phone_number.trim(),
          Body: message,
        });

        const res = await fetch(
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

        results.push({ name: person.first_name, channel: "sms", ok: res.ok });
        continue;
      }

      results.push({ name: person.first_name, channel: "none", ok: false });
    }

    return new Response(JSON.stringify({ ok: true, results }), {
      headers: { ...CORS, "Content-Type": "application/json" },
    });

  } catch (err) {
    return new Response(JSON.stringify({ error: String(err) }), {
      status: 500,
      headers: { ...CORS, "Content-Type": "application/json" },
    });
  }
});
