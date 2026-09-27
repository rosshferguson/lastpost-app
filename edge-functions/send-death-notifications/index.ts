// send-death-notifications/index.ts
// Sends death notifications to all contacts.
// Priority: email → SMS only if no email.

const RESEND_API_KEY = Deno.env.get("RESEND_API_KEY")      ?? "";
const TWILIO_SID     = Deno.env.get("TWILIO_ACCOUNT_SID")  ?? "";
const TWILIO_TOKEN   = Deno.env.get("TWILIO_AUTH_TOKEN")   ?? "";
const TWILIO_FROM    = Deno.env.get("TWILIO_PHONE_NUMBER") ?? "";

const CORS = {
  "Access-Control-Allow-Origin":  "*",
  "Access-Control-Allow-Headers": "authorization, x-client-info, apikey, content-type",
};

interface Contact {
  name: string;
  email?: string;
  phone?: string;
  personal_message?: string;
}

Deno.serve(async (req) => {
  if (req.method === "OPTIONS") return new Response("ok", { headers: CORS });

  try {
    const body = await req.json();
    const {
      deceased_name            = "the person",
      contacts                 = [] as Contact[],
      designated_person_email  = "",
    } = body;

    const results: { name: string; channel: string; ok: boolean }[] = [];

    for (const contact of contacts) {
      const hasEmail = (contact.email ?? "").trim().length > 0;
      const hasPhone = (contact.phone ?? "").trim().length > 0;

      // ── EMAIL (preferred) ────────────────────────────────────────────────
      if (hasEmail) {
        const replyTo = designated_person_email.trim().length > 0
          ? designated_person_email.trim()
          : undefined;

        const personalSection = contact.personal_message?.trim()
          ? `<blockquote style="border-left:4px solid #7c3aed;margin:24px 0;padding:12px 16px;color:#374151;font-style:italic;">
               "${contact.personal_message.trim()}"
             </blockquote>`
          : "";

        const html = `
          <div style="font-family:sans-serif;max-width:560px;margin:0 auto;padding:24px;">
            <h2 style="color:#111827;">A message from Last Post</h2>
            <p style="color:#374151;">Dear ${contact.name},</p>
            <p style="color:#374151;">
              We are deeply sorry to let you know that
              <strong>${deceased_name}</strong> has passed away.
            </p>
            ${personalSection}
            ${replyTo ? `<p style="color:#374151;">If you have any questions, you can reply to this email to reach the person managing ${deceased_name}'s affairs.</p>` : ""}
            <hr style="border:none;border-top:1px solid #e5e7eb;margin:32px 0;" />
            <p style="color:#9ca3af;font-size:12px;">
              This notification was sent via Last Post —
              <a href="https://lastpost.app" style="color:#7c3aed;">lastpost.app</a>
            </p>
          </div>`;

        const emailBody: Record<string, unknown> = {
          from:    "Last Post <noreply@lastpost.app>",
          to:      [contact.email!.trim()],
          subject: `Important news about ${deceased_name}`,
          html,
        };
        if (replyTo) emailBody["reply_to"] = replyTo;

        const res = await fetch("https://api.resend.com/emails", {
          method: "POST",
          headers: {
            "Content-Type": "application/json",
            "Authorization": `Bearer ${RESEND_API_KEY}`,
          },
          body: JSON.stringify(emailBody),
        });

        results.push({ name: contact.name, channel: "email", ok: res.ok });
        continue;
      }

      // ── SMS fallback (only when no email) ──────────────────────────────
      if (hasPhone && TWILIO_SID && TWILIO_TOKEN && TWILIO_FROM) {
        const message = contact.personal_message?.trim()
          ? `${deceased_name} has passed away. A personal message was left for you: "${contact.personal_message.trim()}" — Last Post (lastpost.app)`
          : `We are sorry to let you know that ${deceased_name} has passed away. — Last Post (lastpost.app)`;

        const params = new URLSearchParams({
          From: TWILIO_FROM,
          To:   contact.phone!.trim(),
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

        results.push({ name: contact.name, channel: "sms", ok: res.ok });
        continue;
      }

      results.push({ name: contact.name, channel: "none", ok: false });
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
