// web-trigger-notifications/index.ts
// Deploy: supabase functions deploy web-trigger-notifications --project-ref kypzbbupzuaukdkjeghu --no-verify-jwt
//
// Called from trigger.html after the designated person completes multi-step confirmation.
// Looks up the owner's contacts in user_contacts and sends death notification
// emails + SMS to each one — identical in content to send-death-notifications.
//
// Also sends the designated person a legacy summary email with the owner's
// funeral wishes, documents, digital assets and life history.
//
// Contact emails use Reply-To: <designated person email> so contacts can
// reply directly to the person who triggered the notification.
//
// Payload: { token: string }
// Returns: { ok: true, notified: number }

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

// ── Contact notification email ─────────────────────────────────────────────────

function buildContactEmailHtml(deceasedName: string, toName: string, personalMessage?: string): string {
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
    <p style="font-size:16px;color:#3c3c43;line-height:1.6;margin:0 0 8px">
      Please take care of yourself and your loved ones during this difficult time.
    </p>
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

// ── Legacy summary email (sent to the designated person) ───────────────────────

function legacyRow(label: string, value: string): string {
  const safe = value.replace(/&/g, '&amp;').replace(/</g, '&lt;').replace(/>/g, '&gt;')
  return `<div style="border-bottom:1px solid #f2f2f7;padding:10px 0">
    <p style="font-size:11px;font-weight:600;color:#aeaeb2;margin:0 0 2px;text-transform:uppercase;letter-spacing:0.5px">${label}</p>
    <p style="font-size:15px;color:#1c1c1e;margin:0;line-height:1.5;white-space:pre-wrap">${safe}</p>
  </div>`
}

function sectionBlock(title: string, content: string): string {
  return `<div style="margin-bottom:28px">
    <h2 style="font-size:16px;font-weight:700;color:#1c1c1e;margin:0 0 10px;border-bottom:2px solid #f2f2f7;padding-bottom:6px">${title}</h2>
    ${content}
  </div>`
}

function buildLegacyEmailHtml(
  deceasedName: string,
  dpName: string,
  data: {
    funeral_wishes_data?: Record<string, unknown> | null
    important_documents_data?: unknown[] | null
    digital_assets_data?: unknown[] | null
    life_history_data?: Record<string, unknown> | null
  }
): string {
  const sections: string[] = []

  // Funeral wishes
  const w = data.funeral_wishes_data as Record<string, string | boolean> | undefined
  if (w && !w['isPrivate']) {
    const rows: string[] = []
    if (w['dispositionType'] && w['dispositionType'] !== 'No preference')
      rows.push(legacyRow('Burial / cremation', String(w['dispositionType'])))
    if (w['serviceType'] && w['serviceType'] !== 'No preference')
      rows.push(legacyRow('Service type', String(w['serviceType'])))
    if (w['locationWishes'])  rows.push(legacyRow('Location', String(w['locationWishes'])))
    if (w['musicWishes'])     rows.push(legacyRow('Music', String(w['musicWishes'])))
    if (w['readingWishes'])   rows.push(legacyRow('Readings', String(w['readingWishes'])))
    if (w['dressCode'])       rows.push(legacyRow('Dress code', String(w['dressCode'])))
    if (w['donationInLieuOfFlowers'])
      rows.push(legacyRow('Donations in lieu of flowers', String(w['donationCharity'] || 'Yes')))
    else if (w['flowerPreferences'])
      rows.push(legacyRow('Flowers', String(w['flowerPreferences'])))
    if (w['additionalWishes']) rows.push(legacyRow('Additional wishes', String(w['additionalWishes'])))
    if (rows.length > 0) sections.push(sectionBlock('🌸 Funeral wishes', rows.join('')))
  }

  // Important documents
  const docs = data.important_documents_data as Record<string, unknown>[] | undefined
  if (Array.isArray(docs) && docs.length > 0) {
    const rows = docs.map(d => {
      const check = d['isComplete'] ? '&#10003;' : '○'
      const label = `${check} ${String(d['title'] ?? '')} — ${String(d['category'] ?? '')}`
      const notes = String(d['notes'] ?? '').trim()
      return legacyRow(label, notes || '(no notes)')
    })
    sections.push(sectionBlock('📄 Important documents', rows.join('')))
  }

  // Digital assets
  const assets = data.digital_assets_data as Record<string, unknown>[] | undefined
  if (Array.isArray(assets) && assets.length > 0) {
    const rows = assets.map(a => {
      const parts = [
        a['institution'] ? String(a['institution']) : '',
        a['accountHint'] ? String(a['accountHint']) : '',
        a['accessNotes'] ? `Access: ${String(a['accessNotes'])}` : '',
        a['locationNotes'] ? `Location: ${String(a['locationNotes'])}` : '',
      ].filter(Boolean)
      return legacyRow(
        `${String(a['name'] ?? '')} (${String(a['category'] ?? '')})`,
        parts.join('\n') || '(no details)'
      )
    })
    sections.push(sectionBlock('💼 Digital assets &amp; accounts', rows.join('')))
  }

  // Life history
  const h = data.life_history_data as Record<string, string> | undefined
  if (h) {
    const fields: [string, string][] = [
      ['Origins',              h['origins']          ?? ''],
      ['Family',               h['family']           ?? ''],
      ['Work & career',        h['career']           ?? ''],
      ['Passions & hobbies',   h['passions']         ?? ''],
      ['Memorable moments',    h['memorablemoments'] ?? ''],
      ['Their legacy',         h['legacy']           ?? ''],
      ['Final thoughts',       h['finalThoughts']    ?? ''],
    ]
    const rows = fields.filter(([, v]) => v.trim()).map(([k, v]) => legacyRow(k, v))
    if (rows.length > 0) sections.push(sectionBlock('📖 Life history', rows.join('')))
  }

  const body = sections.length > 0
    ? sections.join('')
    : '<p style="color:#636366;font-size:15px">No legacy information has been recorded yet.</p>'

  return `<!DOCTYPE html>
<html lang="en">
<head><meta charset="utf-8"><meta name="viewport" content="width=device-width, initial-scale=1"></head>
<body style="margin:0;padding:0;background:#f2f2f7;font-family:-apple-system,BlinkMacSystemFont,sans-serif">
<table width="100%" cellpadding="0" cellspacing="0" style="padding:40px 16px">
<tr><td align="center">
<table width="100%" style="max-width:600px;background:#fff;border-radius:16px;padding:40px 32px;border:1px solid #e5e5ea">

  <tr><td style="text-align:center;padding-bottom:24px">
    <p style="font-size:36px;margin:0">📋</p>
    <h1 style="font-size:22px;font-weight:700;color:#1c1c1e;margin:16px 0 8px">${deceasedName}'s legacy information</h1>
    <p style="font-size:14px;color:#636366;margin:0 0 4px">For ${dpName}</p>
    <p style="font-size:13px;color:#aeaeb2;margin:0">
      This information was recorded in advance by ${deceasedName} using Last Post.<br>
      Please keep this information confidential.
    </p>
  </td></tr>

  <tr><td style="padding-top:8px">
    ${body}
  </td></tr>

  <tr><td style="padding-top:24px">
    <div style="background:#f9f9f9;border-radius:10px;padding:16px 18px">
      <p style="font-size:13px;color:#3c3c43;margin:0;line-height:1.5">
        <strong>Next steps:</strong> You may be asked to share some of this information with family
        members or professionals (solicitors, funeral directors, etc.) who need it. Use your
        judgement about what to share and when.
      </p>
    </div>
  </td></tr>

  <tr><td style="padding-top:24px">
    <p style="font-size:12px;color:#aeaeb2;text-align:center;margin:0">
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

  const { token } = await req.json() as { token: string }

  if (!token) {
    return new Response(JSON.stringify({ error: 'token is required' }), {
      status: 400, headers: { ...CORS, 'Content-Type': 'application/json' },
    })
  }

  // 1. Look up the designated person and owner from the trigger_token.
  //    Also verify invitation_accepted=true so revoked tokens are rejected.
  const dpRes = await fetch(
    `${SUPABASE_URL}/rest/v1/designated_persons?trigger_token=eq.${encodeURIComponent(token)}&invitation_accepted=eq.true&select=owner_id,first_name,last_name,email&limit=1`,
    { headers: dbHeaders }
  )

  if (!dpRes.ok) {
    return new Response(JSON.stringify({ error: 'invalid token' }), {
      status: 404, headers: { ...CORS, 'Content-Type': 'application/json' },
    })
  }

  const dpRows = await dpRes.json() as { owner_id: string; first_name?: string; last_name?: string; email?: string }[]
  const dp = dpRows[0]
  if (!dp) {
    return new Response(JSON.stringify({ error: 'invalid token' }), {
      status: 404, headers: { ...CORS, 'Content-Type': 'application/json' },
    })
  }

  const { owner_id } = dp
  const dpEmail = dp.email?.trim() || undefined
  const dpName  = [dp.first_name, dp.last_name].filter(Boolean).join(' ') || 'Designated person'

  // 2. Get the owner's name from profiles
  const profileRes = await fetch(
    `${SUPABASE_URL}/rest/v1/profiles?id=eq.${encodeURIComponent(owner_id)}&select=first_name,last_name&limit=1`,
    { headers: dbHeaders }
  )

  let deceasedName = 'the account holder'
  if (profileRes.ok) {
    const profiles = await profileRes.json() as { first_name?: string; last_name?: string }[]
    const p = profiles[0]
    if (p) {
      deceasedName = [p.first_name, p.last_name].filter(Boolean).join(' ') || deceasedName
    }
  }

  // 3. Fetch all contacts for the owner
  const contactsRes = await fetch(
    `${SUPABASE_URL}/rest/v1/user_contacts?owner_id=eq.${encodeURIComponent(owner_id)}&select=first_name,last_name,email,phone_number,personal_message`,
    { headers: dbHeaders }
  )

  if (!contactsRes.ok) {
    return new Response(JSON.stringify({ error: 'could not fetch contacts' }), {
      status: 500, headers: { ...CORS, 'Content-Type': 'application/json' },
    })
  }

  const contacts = await contactsRes.json() as {
    first_name:       string
    last_name:        string
    email:            string
    phone_number:     string
    personal_message: string
  }[]

  if (contacts.length === 0) {
    return new Response(JSON.stringify({ error: 'no contacts found for this account' }), {
      status: 422, headers: { ...CORS, 'Content-Type': 'application/json' },
    })
  }

  // 4. Send to each contact
  const resendKey = Deno.env.get('RESEND_API_KEY')!
  let notified = 0

  for (const contact of contacts) {
    const contactName = [contact.first_name, contact.last_name].filter(Boolean).join(' ') || 'Friend'
    const email = contact.email?.trim()
    const phone = contact.phone_number?.trim()
    const message = contact.personal_message?.trim() || undefined

    if (email) {
      // Primary channel: email — Reply-To routes replies back to the designated person
      const html = buildContactEmailHtml(deceasedName, contactName, message)
      const emailPayload: Record<string, unknown> = {
        from:    'Last Post <noreply@lastpost.app>',
        to:      [email],
        subject: `A message regarding ${deceasedName}`,
        html,
      }
      if (dpEmail) emailPayload['reply_to'] = [dpEmail]

      const emailRes = await fetch('https://api.resend.com/emails', {
        method: 'POST',
        headers: {
          Authorization:  `Bearer ${resendKey}`,
          'Content-Type': 'application/json',
        },
        body: JSON.stringify(emailPayload),
      })
      if (emailRes.ok) {
        notified++
      } else {
        console.error('[web-trigger] Resend error for', email, await emailRes.text())
      }

    } else if (phone) {
      // Fallback: SMS when no email address is available
      const smsBody = message
        ? `${deceasedName} has passed away and left you a message: "${message}" — sent via Last Post.`
        : `We are deeply sorry to inform you that ${deceasedName} has passed away. This message was arranged in advance using Last Post.`
      await sendSMS(phone, smsBody)
      notified++
    }
  }

  console.log(`[web-trigger] Sent notifications to ${notified}/${contacts.length} contacts for owner ${owner_id}`)

  // 5. Send legacy summary email to the designated person
  if (dpEmail) {
    try {
      const legacyRes = await fetch(
        `${SUPABASE_URL}/rest/v1/profiles?id=eq.${encodeURIComponent(owner_id)}&select=funeral_wishes_data,important_documents_data,digital_assets_data,life_history_data&limit=1`,
        { headers: dbHeaders }
      )
      if (legacyRes.ok) {
        const legacyRows = await legacyRes.json() as Record<string, unknown>[]
        const legacy = legacyRows[0]
        if (legacy) {
          const legacyHtml = buildLegacyEmailHtml(deceasedName, dpName, legacy as Parameters<typeof buildLegacyEmailHtml>[2])
          const legacyEmailRes = await fetch('https://api.resend.com/emails', {
            method: 'POST',
            headers: {
              Authorization:  `Bearer ${resendKey}`,
              'Content-Type': 'application/json',
            },
            body: JSON.stringify({
              from:    'Last Post <noreply@lastpost.app>',
              to:      [dpEmail],
              subject: `${deceasedName}'s legacy information — Last Post`,
              html:    legacyHtml,
            }),
          })
          if (legacyEmailRes.ok) {
            console.log('[web-trigger] Legacy summary sent to designated person:', dpEmail)
          } else {
            console.error('[web-trigger] Failed to send legacy email to DP:', await legacyEmailRes.text())
          }
        }
      }
    } catch (err) {
      // Non-fatal — contact notifications already sent
      console.error('[web-trigger] Legacy email error:', err)
    }
  }

  return new Response(JSON.stringify({ ok: true, notified, total: contacts.length }), {
    headers: { ...CORS, 'Content-Type': 'application/json' },
  })
})
