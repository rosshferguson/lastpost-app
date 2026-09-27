// send-death-notifications/index.ts
// Deploy: supabase functions deploy send-death-notifications --project-ref kypzbbupzuaukdkjeghu --no-verify-jwt
//
// Called from the app after the designated person completes the confirmation flow.
// Sends a death notification email AND SMS to each contact on the list.
// Contacts are passed in the payload (from SwiftData) rather than fetched from Supabase,
// so phone numbers are always current even if not synced to the server.
//
// Payload:
// {
//   deceased_name: string,
//   contacts: Array<{
//     name: string,
//     email?: string,
//     phone?: string,
//     personal_message?: string
//   }>
// }

const CORS = {
  'Access-Control-Allow-Origin': '*',
  'Access-Control-Allow-Headers': 'authorization, x-client-info, apikey, content-type',
}

// ── Twilio SMS helper ──────────────────────────────────────────────────────────
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
      method:  'POST',
      headers: {
        Authorization:  'Basic ' + btoa(`${sid}:${token}`),
        'Content-Type': 'application/x-www-form-urlencoded',
      },
      body: new URLSearchParams({ To: phone, From: from, Body: body }).toString(),
    }
  )
  if (!res.ok) console.error('[sendSMS] Twilio error:', await res.text())
}

// ── Email builder ──────────────────────────────────────────────────────────────
function buildEmailHtml(deceasedName: string, toName: string, personalMessage?: string): string {
  const messageBlock = personalMessage?.trim()
    ? `<div style="background:#f9f9f9;border-left:3px solid #e5e5ea;border-radius:8px;padding:16px 20px;margin:24px 0">
        <p style="font-size:15px;color:#3c3c43;line-height:1.6;margin:0;font-style:italic">"${personalMessage}"</p>
        <p style="font-size:13px;color:#aeaeb2;margin:8px 0 0">— ${deceasedName}</p>
      </div>`
    : ''

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
    <p style="font-size:40px;margin:0">🕊️</p>
  </td></tr>

  <tr><td>
    <h1 style="font-size:22px;font-weight:700;color:#1c1c1e;margin:0 0 16px;text-align:center">
      A message from Last Post
    </h1>
    <p style="font-size:16px;color:#3c3c43;line-height:1.6;margin:0 0 8px">
      Dear ${toName},
    </p>
    <p style="font-size:16px;color:#3c3c43;line-height:1.6;margin:0 0 24px">
      We are deeply sorry to inform you that <strong>${deceasedName}</strong> has passed away.
      This message was prepared in advance by ${deceasedName} using Last Post, so that those
      closest to them would be notified promptly.
    </p>
    ${messageBlock}
    <p style="font-size:14px;color:#636366;line-height:1.6;margin:0 0 24px">
      If you have any questions, you can reply to this email and your message will be
      forwarded to the person who notified you on ${deceasedName}'s behalf.
    </p>
  </td></tr>

  <tr><td style="padding-top:16px">
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

interface ContactPayload {
  name: string
  email?: string
  phone?: string
  personal_message?: string
}

Deno.serve(async (req) => {
  if (req.method === 'OPTIONS') return new Response('ok', { headers: CORS })

  const { deceased_name, contacts: contactsFromPayload, designated_person_email, owner_id } = await req.json() as {
    deceased_name: string
    contacts?: ContactPayload[]
    designated_person_email?: string
    owner_id?: string
  }

  if (!deceased_name) {
    return new Response(JSON.stringify({ error: 'deceased_name is required' }), {
      status: 400, headers: { ...CORS, 'Content-Type': 'application/json' },
    })
  }

  let contacts: ContactPayload[] = contactsFromPayload ?? []

  // If no contacts were passed but an owner_id was provided, fetch them server-side.
  // This is used when the designated person's device doesn't have local contacts
  // (RLS would block a client-side fetch, so we use the service role key here).
  if (contacts.length === 0 && owner_id) {
    const supabaseUrl  = Deno.env.get('SUPABASE_URL')!
    const serviceKey   = Deno.env.get('SERVICE_ROLE_KEY') ?? Deno.env.get('SUPABASE_SERVICE_ROLE_KEY')!
    const res = await fetch(
      `${supabaseUrl}/rest/v1/user_contacts?owner_id=eq.${owner_id}&select=first_name,last_name,email,phone_number,personal_message`,
      { headers: { Authorization: `Bearer ${serviceKey}`, apikey: serviceKey, Accept: 'application/json' } }
    )
    if (res.ok) {
      const rows = await res.json() as Array<Record<string, string>>
      contacts = rows
        .filter(r => r.email || r.phone_number)
        .map(r => ({
          name:             `${r.first_name ?? ''} ${r.last_name ?? ''}`.trim(),
          email:            r.email      || undefined,
          phone:            r.phone_number || undefined,
          personal_message: r.personal_message || undefined,
        }))
    }
  }

  if (contacts.length === 0) {
    return new Response(JSON.stringify({ ok: true, sent: 0, note: 'no contacts found' }), {
      headers: { ...CORS, 'Content-Type': 'application/json' },
    })
  }

  const resendKey = Deno.env.get('RESEND_API_KEY')!
  const results: { name: string; email?: boolean; sms?: boolean }[] = []

  for (const contact of contacts) {
    const result: { name: string; email?: boolean; sms?: boolean } = { name: contact.name }

    if (contact.email) {
      // Primary channel: email
      const html = buildEmailHtml(deceased_name, contact.name, contact.personal_message)
      const emailPayload: Record<string, unknown> = {
        from:    'Last Post <noreply@lastpost.app>',
        to:      [contact.email],
        subject: `A message regarding ${deceased_name}`,
        html,
      }
      if (designated_person_email) emailPayload['reply_to'] = [designated_person_email]

      const emailRes = await fetch('https://api.resend.com/emails', {
        method: 'POST',
        headers: {
          Authorization:  `Bearer ${resendKey}`,
          'Content-Type': 'application/json',
        },
        body: JSON.stringify(emailPayload),
      })
      result.email = emailRes.ok
      if (!emailRes.ok) console.error('[email] Resend error for', contact.email, await emailRes.text())

    } else if (contact.phone) {
      // Fallback: SMS when no email address is available
      const personalMsg = contact.personal_message?.trim()
      const smsBody = personalMsg
        ? `${deceased_name} has passed away and left you a message: "${personalMsg}" — sent via Last Post.`
        : `We are deeply sorry to inform you that ${deceased_name} has passed away. This message was arranged in advance using Last Post.`
      await sendSMS(contact.phone, smsBody)
      result.sms = true
    }

    results.push(result)
  }

  return new Response(JSON.stringify({ ok: true, results }), {
    headers: { ...CORS, 'Content-Type': 'application/json' },
  })
})
