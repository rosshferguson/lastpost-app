// send-funeral-details/index.ts
// Deploy: supabase functions deploy send-funeral-details --project-ref kypzbbupzuaukdkjeghu --no-verify-jwt
//
// Called by the designated person after funeral arrangements are known.
// Sends a follow-up email (and optional SMS) to all contacts who were
// previously notified of the death, with the funeral arrangement details.
//
// All detail fields are optional — the designated person sends whatever
// is currently known and can send updates more than once.
//
// Payload:
// {
//   owner_supabase_id: string,        // required
//   funeral_date?:    string,         // e.g. "Monday, 14 July 2025"
//   funeral_time?:    string,         // e.g. "2:00 PM"
//   venue_name?:      string,
//   venue_address?:   string,
//   additional_notes?: string
// }

const CORS = {
  'Access-Control-Allow-Origin': '*',
  'Access-Control-Allow-Headers': 'authorization, x-client-info, apikey, content-type',
}

const SUPABASE_URL     = 'https://kypzbbupzuaukdkjeghu.supabase.co'
const SERVICE_ROLE_KEY = Deno.env.get('SERVICE_ROLE_KEY')!

const dbHeaders = {
  'Authorization': `Bearer ${SERVICE_ROLE_KEY}`,
  'apikey':        SERVICE_ROLE_KEY,
  'Accept':        'application/json',
  'Content-Type':  'application/json',
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

function buildFuneralDetailsHtml(
  deceasedName: string,
  toName: string,
  details: {
    funeral_date?:    string
    funeral_time?:    string
    venue_name?:      string
    venue_address?:   string
    additional_notes?: string
  }
): string {
  const hasWhen  = details.funeral_date || details.funeral_time
  const hasWhere = details.venue_name   || details.venue_address

  const whenBlock = hasWhen ? `
    <tr>
      <td style="padding:0 0 20px">
        <p style="font-size:13px;font-weight:600;color:#aeaeb2;margin:0 0 6px;text-transform:uppercase;letter-spacing:0.5px">When</p>
        ${details.funeral_date ? `<p style="font-size:16px;color:#1c1c1e;margin:0 0 2px;font-weight:500">${details.funeral_date}</p>` : ''}
        ${details.funeral_time ? `<p style="font-size:16px;color:#3c3c43;margin:0">${details.funeral_time}</p>` : ''}
      </td>
    </tr>` : ''

  const whereBlock = hasWhere ? `
    <tr>
      <td style="padding:0 0 20px">
        <p style="font-size:13px;font-weight:600;color:#aeaeb2;margin:0 0 6px;text-transform:uppercase;letter-spacing:0.5px">Where</p>
        ${details.venue_name    ? `<p style="font-size:16px;color:#1c1c1e;margin:0 0 2px;font-weight:500">${details.venue_name}</p>` : ''}
        ${details.venue_address ? `<p style="font-size:15px;color:#3c3c43;margin:0;white-space:pre-line">${details.venue_address}</p>` : ''}
      </td>
    </tr>` : ''

  const notesBlock = details.additional_notes ? `
    <tr>
      <td style="padding:0 0 20px">
        <p style="font-size:13px;font-weight:600;color:#aeaeb2;margin:0 0 6px;text-transform:uppercase;letter-spacing:0.5px">Additional information</p>
        <p style="font-size:15px;color:#3c3c43;margin:0;line-height:1.6;white-space:pre-line">${details.additional_notes}</p>
      </td>
    </tr>` : ''

  const detailsTable = (hasWhen || hasWhere || details.additional_notes) ? `
    <tr>
      <td style="padding:24px;background:#f9f9f9;border-radius:12px;margin-bottom:24px">
        <table width="100%" cellpadding="0" cellspacing="0">
          ${whenBlock}
          ${whereBlock}
          ${notesBlock}
        </table>
      </td>
    </tr>` : ''

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
      Funeral arrangement details
    </h1>
    <p style="font-size:16px;color:#3c3c43;line-height:1.6;margin:0 0 8px">
      Dear ${toName},
    </p>
    <p style="font-size:16px;color:#3c3c43;line-height:1.6;margin:0 0 24px">
      We are writing with further details regarding the funeral arrangements
      for <strong>${deceasedName}</strong>.
    </p>
  </td></tr>

  ${detailsTable}

  <tr><td style="padding-top:24px">
    <p style="font-size:15px;color:#3c3c43;line-height:1.6;margin:0 0 8px">
      If you have any questions or need further information, please reply to this email.
    </p>
    <p style="font-size:14px;color:#636366;line-height:1.6;margin:0 0 24px">
      Please pass on these details to anyone else who knew ${deceasedName} and may wish to attend.
    </p>
  </td></tr>

  <tr><td style="padding-top:8px">
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
    owner_supabase_id: string
    funeral_date?:     string
    funeral_time?:     string
    venue_name?:       string
    venue_address?:    string
    additional_notes?: string
  }

  if (!payload.owner_supabase_id) {
    return new Response(JSON.stringify({ error: 'owner_supabase_id is required' }), {
      status: 400, headers: { ...CORS, 'Content-Type': 'application/json' },
    })
  }

  const ownerId = payload.owner_supabase_id

  // 1. Get the owner's name
  const profileRes = await fetch(
    `${SUPABASE_URL}/rest/v1/profiles?id=eq.${encodeURIComponent(ownerId)}&select=first_name,last_name&limit=1`,
    { headers: dbHeaders }
  )

  let deceasedName = 'the deceased'
  if (profileRes.ok) {
    const profiles = await profileRes.json() as { first_name?: string; last_name?: string }[]
    const p = profiles[0]
    if (p) deceasedName = [p.first_name, p.last_name].filter(Boolean).join(' ') || deceasedName
  }

  // 2. Fetch all contacts for this owner
  const contactsRes = await fetch(
    `${SUPABASE_URL}/rest/v1/user_contacts?owner_id=eq.${encodeURIComponent(ownerId)}&select=first_name,last_name,email,phone_number`,
    { headers: dbHeaders }
  )

  if (!contactsRes.ok) {
    return new Response(JSON.stringify({ error: 'could not fetch contacts' }), {
      status: 500, headers: { ...CORS, 'Content-Type': 'application/json' },
    })
  }

  const contacts = await contactsRes.json() as {
    first_name:   string
    last_name:    string
    email:        string
    phone_number: string
  }[]

  if (contacts.length === 0) {
    return new Response(JSON.stringify({ error: 'no contacts found' }), {
      status: 422, headers: { ...CORS, 'Content-Type': 'application/json' },
    })
  }

  // 3. Send to each contact
  const resendKey = Deno.env.get('RESEND_API_KEY')!
  const details = {
    funeral_date:    payload.funeral_date,
    funeral_time:    payload.funeral_time,
    venue_name:      payload.venue_name,
    venue_address:   payload.venue_address,
    additional_notes: payload.additional_notes,
  }

  let notified = 0

  for (const contact of contacts) {
    const contactName = [contact.first_name, contact.last_name].filter(Boolean).join(' ') || 'Friend'
    const email = contact.email?.trim()
    const phone = contact.phone_number?.trim()

    if (email) {
      const html = buildFuneralDetailsHtml(deceasedName, contactName, details)
      const emailRes = await fetch('https://api.resend.com/emails', {
        method: 'POST',
        headers: {
          Authorization:  `Bearer ${resendKey}`,
          'Content-Type': 'application/json',
        },
        body: JSON.stringify({
          from:    'Last Post <noreply@lastpost.app>',
          to:      [email],
          subject: `Funeral arrangements for ${deceasedName}`,
          html,
        }),
      })
      if (emailRes.ok) {
        notified++
      } else {
        console.error('[funeral-details] Resend error for', email, await emailRes.text())
      }
    }

    if (phone) {
      const parts: string[] = []
      if (payload.funeral_date) parts.push(payload.funeral_date)
      if (payload.funeral_time) parts.push(`at ${payload.funeral_time}`)
      if (payload.venue_name)   parts.push(`at ${payload.venue_name}`)
      const smsBody = parts.length > 0
        ? `Funeral arrangements for ${deceasedName}: ${parts.join(', ')}. Check your email for full details.`
        : `Funeral arrangements for ${deceasedName} have been shared. Please check your email for details.`
      await sendSMS(phone, smsBody)
    }
  }

  console.log(`[funeral-details] Sent to ${notified}/${contacts.length} contacts for owner ${ownerId}`)

  return new Response(JSON.stringify({ ok: true, notified, total: contacts.length }), {
    headers: { ...CORS, 'Content-Type': 'application/json' },
  })
})
