// send-confirmation-code/index.ts
// Sends the confirmation code to the designated person when they trigger a notification.
// Priority: email → SMS only if no email.

const RESEND_API_KEY = Deno.env.get("RESEND_API_KEY")      ?? "";
const TWILIO_SID     = Deno.env.get("TWILIO_ACCOUNT_SID")  ?? "";
const TWILIO_TOKEN   = Deno.env.get("TWILIO_AUTH_TOKEN")   ?? "";
const TWILIO_FROM    = Deno.env.get("TWILIO_PHONE_NUMBER") ?? "";

const CORS = {
  "Access-Control-Allow-Origin":  "*",
  "Access-Control-Allow-Headers": "authorization, x-client-info, apikey, content-type",
};

Deno.serve(async (req) => {
  if (req.method === "OPTIONS") return new Response("ok", { headers: CORS });

  try {
    const body = await req.json();
    const {
      code                    = "",
      designated_person_name  = "there",
      designated_person_email = "",
      designated_person_phone = "",
      deceased_name           = "the person",
    } = body;

    const hasEmail = designated_person_email.trim().length > 0;
    const hasPhone = designated_person_phone.trim().length > 0;

    // ── EMAIL (preferred) ────────────────────────────────────────────────────
    if (hasEmail) {
      const html = `
        <div style="font-family:sans-serif;max-width:560px;margin:0 auto;padding:24px;">
          <h2 style="color:#111827;">Your confirmation code</h2>
          <p style="color:#374151;">Hi ${designated_person_name},</p>
          <p style="color:#374151;">
            You've begun the notification process for <strong>${deceased_name}</strong>
            on Last Post. Please enter the code below in the app to continue.
          </p>
          <div style="margin:32px 0;text-align:center;">
            <span style="font-size:36px;font-weight:700;letter-spacing:8px;color:#7c3aed;">${code}</span>
          </div>
          <p style="color:#6b7280;font-size:14px;">
            After entering this code, a 24-hour waiting period will begin before
            notifications are sent to contacts.
          </p>
          <p style="color:#6b7280;font-size:14px;">
            If you did not start this process, please ignore this email.
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
          to:      [designated_person_email.trim()],
          subject: `Your Last Post confirmation code: ${code}`,
          html,
        }),
      });

      const sent = res.ok;
      return new Response(JSON.stringify({ ok: sent, sent, channel: "email" }), {
        headers: { ...CORS, "Content-Type": "application/json" },
      });
    }

    // ── SMS fallback (only when no email) ───────────────────────────────────
    if (hasPhone && TWILIO_SID && TWILIO_TOKEN && TWILIO_FROM) {
      const message =
        `Last Post confirmation code for ${deceased_name}'s notification: ${code}. ` +
        `Enter this in the app to continue. A 24-hour waiting period will then begin.`;

      const params = new URLSearchParams({
        From: TWILIO_FROM,
        To:   designated_person_phone.trim(),
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

      const sent = res.ok;
      return new Response(JSON.stringify({ ok: sent, sent, channel: "sms" }), {
        headers: { ...CORS, "Content-Type": "application/json" },
      });
    }

    return new Response(JSON.stringify({ ok: false, sent: false, reason: "no contact method" }), {
      headers: { ...CORS, "Content-Type": "application/json" },
    });

  } catch (err) {
    return new Response(JSON.stringify({ error: String(err) }), {
      status: 500,
      headers: { ...CORS, "Content-Type": "application/json" },
    });
  }
});
