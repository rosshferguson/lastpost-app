// notify-contact-added.ts
// Deploy with: supabase functions deploy notify-contact-added --project-ref kypzbbupzuaukdkjeghu
//
// Called from the app when a contact is added.
// 1. Generates a one-time acceptance token
// 2. Inserts it into the invitation_tokens table (simple, no unique-constraint dependency)
// 3. Emails the contact with Accept / Decline links

import { createClient } from 'https://esm.sh/@supabase/supabase-js@2'

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

const FUNCTION_URL = 'https://kypzbbupzuaukdkjeghu.supabase.co/functions/v1/accept-contact-invitation'

Deno.serve(async (req) => {
  if (req.method === 'OPTIONS') return new Response('ok', { headers: CORS })

  const {
    ownerName,
    contactFirstName,
    contactLastName,
    contactName,
    contactEmail,
    contactPhone,
    relationship,
    ownerSupabaseId,
  } = await req.json()

  if (!contactEmail && !contactPhone) {
    return new Response(JSON.stringify({ error: 'contactEmail or contactPhone required' }), {
      status: 400, headers: { ...CORS, 'Content-Type': 'application/json' },
    })
  }

  const firstName = contactFirstName ?? contactName?.split(' ')[0] ?? ''
  const lastName  = contactLastName  ?? (contactName?.split(' ').slice(1).join(' ') ?? '')
  const fromName  = ownerName ?? 'Someone'
  const toName    = `${firstName} ${lastName}`.trim() || contactEmail || contactPhone

  const supabase = createClient(
    Deno.env.get('SUPABASE_URL')!,
    Deno.env.get('SERVICE_ROLE_KEY')!
  )

  // Generate a one-time token and store it in the dedicated tokens table
  const token = crypto.randomUUID()

  // Phone-only contact: generate a token so they can accept/decline via SMS link
  if (!contactEmail) {
    if (contactPhone) {
      const { error: insertError } = await supabase
        .from('invitation_tokens')
        .insert({
          token,
          owner_id:     ownerSupabaseId ?? null,
          first_name:   firstName,
          last_name:    lastName,
          email:        null,
          phone_number: contactPhone,
          relationship: relationship ?? '',
        })

      if (insertError) console.error('Phone-only token insert error:', insertError)

      const fromEncoded = encodeURIComponent(fromName)
      const acceptPage  = `https://lastpost.app/accept?token=${token}&from=${fromEncoded}`
      const smsBody     = `Hi ${toName}, ${fromName} has added you to their Last Post contact list. Accept or decline: ${acceptPage}`
      await sendSMS(contactPhone, smsBody)
    }
    return new Response(JSON.stringify({ ok: true, channel: 'sms' }), {
      headers: { ...CORS, 'Content-Type': 'application/json' },
    })
  }

  const { error: insertError } = await supabase
    .from('invitation_tokens')
    .insert({
      token,
      owner_id:     ownerSupabaseId ?? null,
      first_name:   firstName,
      last_name:    lastName,
      email:        contactEmail,
      phone_number: contactPhone ?? null,
      relationship: relationship ?? '',
    })

  if (insertError) {
    console.error('Token insert error:', insertError)
    return new Response(JSON.stringify({ error: 'Failed to create invitation token', detail: insertError }), {
      status: 500, headers: { ...CORS, 'Content-Type': 'application/json' },
    })
  }

  const acceptUrl  = `${FUNCTION_URL}?token=${token}&action=accept`
  const declineUrl = `${FUNCTION_URL}?token=${token}&action=decline`

  const resendKey = Deno.env.get('RESEND_API_KEY')!

  const emailHtml = `
<!DOCTYPE html>
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
    <p style="font-size:32px;margin:0">✉️</p>
  </td></tr>

  <tr><td>
    <h1 style="font-size:22px;font-weight:700;color:#1c1c1e;margin:0 0 16px;text-align:center">
      You've been added as a contact
    </h1>
    <p style="font-size:16px;color:#3c3c43;line-height:1.6;margin:0 0 8px">
      Hi ${toName},
    </p>
    <p style="font-size:16px;color:#3c3c43;line-height:1.6;margin:0 0 24px">
      <strong>${fromName}</strong> has added you as a contact on <strong>Last Post</strong> —
      an app that notifies friends and family when someone passes away.
    </p>
    <p style="font-size:16px;color:#3c3c43;line-height:1.6;margin:0 0 24px">
      There is no cause for concern — ${fromName} is simply making preparations for the future as part of their legacy planning.
    </p>
    <p style="font-size:16px;color:#3c3c43;line-height:1.6;margin:0 0 32px">
      If you're happy to be notified in this way, please confirm below.
      You can also decline if you'd prefer not to be included.
    </p>
  </td></tr>

  <tr><td style="text-align:center;padding-bottom:16px">
    <table cellpadding="0" cellspacing="0" style="margin:0 auto">
      <tr>
        <td align="center" bgcolor="#34c759" style="border-radius:12px">
          <a href="${acceptUrl}"
             style="display:block;padding:14px 40px;color:#ffffff;font-size:17px;font-weight:600;text-decoration:none;font-family:-apple-system,BlinkMacSystemFont,sans-serif">
            Yes, notify me
          </a>
        </td>
      </tr>
    </table>
  </td></tr>

  <tr><td style="text-align:center;padding-bottom:32px">
    <a href="${declineUrl}" style="font-size:15px;color:#8e8e93;text-decoration:none">
      No thanks, remove me
    </a>
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

  const emailRes = await fetch('https://api.resend.com/emails', {
    method: 'POST',
    headers: {
      'Authorization': `Bearer ${resendKey}`,
      'Content-Type': 'application/json',
    },
    body: JSON.stringify({
      from: 'Last Post <noreply@lastpost.app>',
      to: [contactEmail],
      subject: `${fromName} has added you as a contact on Last Post`,
      html: emailHtml,
    }),
  })

  if (!emailRes.ok) {
    const err = await emailRes.text()
    console.error('Resend error:', err)
  }

  // SMS (optional — only if phone provided and Twilio configured)
  if (contactPhone) {
    const smsBody = `Hi ${toName}, ${fromName} has added you to their Last Post contact list. Check your email to confirm.`
    await sendSMS(contactPhone, smsBody)
  }

  return new Response(JSON.stringify({ ok: true }), {
    headers: { ...CORS, 'Content-Type': 'application/json' },
  })
})
