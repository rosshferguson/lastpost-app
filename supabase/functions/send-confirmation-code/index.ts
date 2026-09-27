// send-confirmation-code/index.ts
// Deploy: supabase functions deploy send-confirmation-code --project-ref kypzbbupzuaukdkjeghu --no-verify-jwt
//
// Sends the 6-character confirmation code to the designated person via email and/or SMS.
// Called by the app immediately after initiateDeathNotification generates the code.
//
// Payload:
// {
//   code:                    string,   // 6-char code e.g. "A3KP7X"
//   designated_person_name:  string,
//   designated_person_email: string,   // optional
//   designated_person_phone: string,   // optional
//   deceased_name:           string
// }

const CORS = {
  'Access-Control-Allow-Origin': '*',
  'Access-Control-Allow-Headers': 'authorization, x-client-info, apikey, content-type',
}

// ── Twilio SMS ─────────────────────────────────────────────────────────────────

function normalisePhone(raw: string): string | null {
  const digits = raw.replace(/\D/g, '')
  if (!digits) return null
  if (digits.startsWith('07') && digits.length === 11) return '+44' + digits.slice(1)
  if (digits.length >= 10) return '+' + digits
  return null
}

async function sendSMS(to: string, body: string): Promise<void> {
  const sid   = Deno.env.get('TWILIO_ACCOUNT_SID')
  const token = Deno.env.get('TWILIO_AUTH_TOKEN')
  const from  = Deno.env.get('TWILIO_FROM_NUMBER')
  if (!sid || !token || !from) return

  const phone = normalisePhone(to)
  if (!phone) return

  const res = await fetch(
    `https://api.twilio.com/2010-04-01/Accounts/${sid}/Messages.json`,
    {
      method: 'POST',
      headers: {
        Authorization:  'Basic ' + btoa(`${sid}:${token}`),
        'Content-Type': 'application/x-www-form-urlencoded',
      },
      body: new URLSearchParams({ To: phone, From: from, Body: body }).toString(),
    }
  )
  if (!res.ok) console.error('[send-confirmation-code] Twilio error:', await res.text())
}

// ── Email HTML ─────────────────────────────────────────────────────────────────

function buildEmailHtml(toName: string, deceasedName: string, code: string): string {
  return `<!DOCTYPE html>
<html lang="en">
<head>
<meta charset="utf-8">
<meta name="viewport" content="width=device-width, initial-scale=1">
</head>
<body style="margin:0;padding:0;background:#f2f2f7;font-family:-apple-system,BlinkMacSystemFont,sans-serif">
<table width="100%" cellpadding="0" cellspacing="0" style="padding:40px 16px">
<tr><td align="center">
<table width="100%" style="max-width:520px;background:#fff;border-radius:16px;padding:40px 32px;border:1px solid #e5e5ea">

  <tr><td style="text-align:center;padding-bottom:24px">
    <p style="font-size:40px;margin:0">🔐</p>
  </td></tr>

  <tr><td>
    <h1 style="font-size:22px;font-weight:700;color:#1c1c1e;margin:0 0 16px;text-align:center">
      Your confirmation code
    </h1>
    <p style="font-size:16px;color:#3c3c43;line-height:1.6;margin:0 0 8px">
      Hi ${toName},
    </p>
    <p style="font-size:16px;color:#3c3c43;line-height:1.6;margin:0 0 24px">
      You are confirming the passing of <strong>${deceasedName}</strong> in the Last Post app.
      Enter the code below to complete the final confirmation step.
    </p>
  </td></tr>

  <tr><td style="text-align:center;padding:24px 0">
    <div style="display:inline-block;background:#f2f2f7;border-radius:12px;padding:20px 40px">
      <p style="font-size:36px;font-weight:700;letter-spacing:8px;color:#1c1c1e;margin:0;font-family:monospace">
        ${code}
      </p>
    </div>
  </td></tr>

  <tr><td style="padding-top:16px">
    <p style="font-size:14px;color:#636366;line-height:1.6;margin:0 0 24px;text-align:center">
      Enter this code in the Last Post app to proceed.<br>
      If you did not initiate this, please ignore this message.
    </p>
  </td></tr>

  <tr><td>
    <p style="font-size:13px;color:#aeaeb2;text-align:center;line-height:1.5;margin:0">
      Last Post &bull; <a href="https://lastpost.app/privacy.html" style="color:#aeaeb2">Privacy Policy</a>
    </p>
  </td></tr>

</table>
</td></tr>
</table>
</body>
</html>`
}

// ── Handler ────────────────────────────────────────────────────────────────────

Deno.serve(async (req) => {
  if (req.method === 'OPTIONS') return new Response('ok', { headers: CORS })

  const payload = await req.json() as {
    code:                    string
    designated_person_name:  string
    designated_person_email?: string
    designated_person_phone?: string
    deceased_name:           string
  }

  const { code, designated_person_name, designated_person_email, designated_person_phone, deceased_name } = payload

  console.log('[send-confirmation-code] code:', code ?? 'MISSING', 'deceased:', deceased_name ?? 'MISSING')
  console.log('[send-confirmation-code] email:', designated_person_email ?? '(none)', 'phone:', designated_person_phone ?? '(none)')

  if (!code || !deceased_name) {
    return new Response(JSON.stringify({ error: 'code and deceased_name are required' }), {
      status: 400, headers: { ...CORS, 'Content-Type': 'application/json' },
    })
  }

  if (!designated_person_email && !designated_person_phone) {
    return new Response(JSON.stringify({ error: 'designated_person_email or designated_person_phone required' }), {
      status: 400, headers: { ...CORS, 'Content-Type': 'application/json' },
    })
  }

  const resendKey = Deno.env.get('RESEND_API_KEY')!
  let sent = false

  // Email
  if (designated_person_email) {
    const html = buildEmailHtml(designated_person_name, deceased_name, code)
    const res = await fetch('https://api.resend.com/emails', {
      method: 'POST',
      headers: {
        Authorization:  `Bearer ${resendKey}`,
        'Content-Type': 'application/json',
      },
      body: JSON.stringify({
        from:    'Last Post <noreply@lastpost.app>',
        to:      [designated_person_email],
        subject: `Your Last Post confirmation code: ${code}`,
        html,
      }),
    })
    if (res.ok) {
      sent = true
    } else {
      console.error('[send-confirmation-code] Resend error:', await res.text())
    }
  }

  // SMS
  if (designated_person_phone) {
    const smsBody = `Your Last Post confirmation code is: ${code}\n\nEnter this in the app to confirm the passing of ${deceased_name}.`
    await sendSMS(designated_person_phone, smsBody)
    sent = true
  }

  return new Response(JSON.stringify({ ok: true, sent }), {
    headers: { ...CORS, 'Content-Type': 'application/json' },
  })
})
