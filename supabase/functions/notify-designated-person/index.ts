// notify-designated-person.ts
// Deploy with: supabase functions deploy notify-designated-person --project-ref kypzbbupzuaukdkjeghu --no-verify-jwt
//
// Upserts the designated_persons row (generating acceptance_token via DB DEFAULT),
// then sends the invitation email with an Accept button.

const CORS = {
  'Access-Control-Allow-Origin': '*',
  'Access-Control-Allow-Headers': 'authorization, x-client-info, apikey, content-type',
}

const SUPABASE_URL     = 'https://kypzbbupzuaukdkjeghu.supabase.co'
const SERVICE_ROLE_KEY = Deno.env.get('SERVICE_ROLE_KEY')!

// ── Twilio SMS helper ──────────────────────────────────────────────────────────
function normalisePhone(raw: string): string | null {
  const digits = raw.replace(/\D/g, '')
  if (!digits) return null
  // UK mobile: 07xxx → +447xxx
  if (digits.startsWith('07') && digits.length === 11) return '+44' + digits.slice(1)
  // Already international (without +)
  if (digits.length >= 10) return '+' + digits
  return null
}

async function sendSMS(to: string, body: string): Promise<void> {
  const sid   = Deno.env.get('TWILIO_ACCOUNT_SID')
  const token = Deno.env.get('TWILIO_AUTH_TOKEN')
  const from  = Deno.env.get('TWILIO_FROM_NUMBER')
  if (!sid || !token || !from) {
    console.warn('[sendSMS] Twilio not configured — skipping')
    return
  }

  const phone = normalisePhone(to)
  console.log('[sendSMS] normalised phone:', phone ?? 'null (skipping)')
  if (!phone) return

  console.log('[sendSMS] sending to:', phone, 'from:', from)
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
  const resText = await res.text()
  if (!res.ok) {
    console.error('[sendSMS] Twilio error:', resText)
  } else {
    console.log('[sendSMS] Twilio success:', resText.slice(0, 100))
  }
}

Deno.serve(async (req) => {
  if (req.method === 'OPTIONS') return new Response('ok', { headers: CORS })

  const {
    owner_id,
    owner_name,
    designated_person_name,
    designated_person_email,
    designated_person_phone,
    relationship,
    invite_link,
    can_access_photos,
    can_view_arrangements,
  } = await req.json()

  // Need at least one contact method
  if (!designated_person_email && !designated_person_phone) {
    return new Response(JSON.stringify({ error: 'email or phone required' }), {
      status: 400, headers: { ...CORS, 'Content-Type': 'application/json' },
    })
  }

  // ── Step 1: upsert the designated_persons row ──
  let acceptUrl: string | null = null

  console.log('[notify-designated-person] owner_id received:', owner_id ?? 'NULL')
  console.log('[notify-designated-person] email:', designated_person_email ?? '(none)')
  console.log('[notify-designated-person] phone:', designated_person_phone ?? '(none)')

  const dbHeaders = {
    'Authorization': `Bearer ${SERVICE_ROLE_KEY}`,
    'apikey': SERVICE_ROLE_KEY,
    'Content-Type': 'application/json',
  }

  const generatedTriggerToken = crypto.randomUUID()

  if (owner_id) {
    const nameParts = (designated_person_name ?? '').trim().split(' ')
    const firstName = nameParts[0] ?? ''
    const lastName  = nameParts.slice(1).join(' ')
    // Upsert on email if provided, on phone_number if phone-only
    const conflictCol = designated_person_email ? 'owner_id,email' : 'owner_id,phone_number'
    const url = `${SUPABASE_URL}/rest/v1/designated_persons?on_conflict=${conflictCol}`
    const upsertRes = await fetch(url, {
      method: 'POST',
      headers: { ...dbHeaders, 'Prefer': 'resolution=merge-duplicates' },
      body: JSON.stringify({
        owner_id,
        first_name:              firstName,
        last_name:               lastName,
        email:                   designated_person_email ?? '',
        phone_number:            designated_person_phone ?? '',
        relationship:            relationship ?? '',
        invitation_accepted:     false,
        invitation_sent:         true,
        is_primary:              false,
        can_access_photos:       can_access_photos ?? false,
        can_view_arrangements:   can_view_arrangements ?? true,
        can_trigger_notification: true,
        trigger_token:           generatedTriggerToken,
      }),
    })
    const upsertText = await upsertRes.text()
    console.log('[notify-designated-person] upsert status:', upsertRes.status, upsertText)
  } else {
    console.log('[notify-designated-person] no owner_id — skipping upsert')
  }

  // Step 2: read back tokens (only possible if email available for lookup)
  let triggerUrl: string | null = `https://lastpost.app/trigger.html?token=${generatedTriggerToken}`

  if (designated_person_email) {
    const email_encoded = encodeURIComponent(designated_person_email)
    const selectRes = await fetch(
      `${SUPABASE_URL}/rest/v1/designated_persons?email=eq.${email_encoded}&select=acceptance_token,trigger_token&limit=1`,
      { headers: { ...dbHeaders, 'Accept': 'application/json' } }
    )
    const selectText = await selectRes.text()
    console.log('[notify-designated-person] select:', selectRes.status, selectText)

    if (selectRes.ok) {
      const rows = JSON.parse(selectText) as { acceptance_token?: string; trigger_token?: string }[]
      const acceptanceToken = rows[0]?.acceptance_token
      const triggerToken    = rows[0]?.trigger_token ?? generatedTriggerToken
      console.log('[notify-designated-person] acceptance_token found:', acceptanceToken ?? 'NONE')
      if (acceptanceToken) {
        acceptUrl = `${SUPABASE_URL}/functions/v1/accept-designated-invitation?token=${acceptanceToken}`
      }
      if (triggerToken) {
        triggerUrl = `https://lastpost.app/trigger.html?token=${triggerToken}`
      }
    }
  }

  const resendKey = Deno.env.get('RESEND_API_KEY')!
  const fromName  = owner_name ?? 'Someone'
  const toName    = designated_person_name ?? designated_person_email ?? designated_person_phone

  const acceptBlock = acceptUrl
    ? `<tr><td style="text-align:center;padding-bottom:32px">
    <p style="font-size:16px;color:#3c3c43;margin:0 0 20px">
      Please confirm that you're happy to take on this responsibility:
    </p>
    <table role="presentation" cellpadding="0" cellspacing="0" style="margin:0 auto">
      <tr>
        <td style="border-radius:14px;background-color:#34c759;text-align:center">
          <a href="${acceptUrl}" target="_blank"
             style="display:inline-block;padding:16px 40px;color:#ffffff;font-size:17px;
                    font-weight:700;text-decoration:none;
                    font-family:-apple-system,BlinkMacSystemFont,sans-serif">
            &#10003;&nbsp; Accept invitation
          </a>
        </td>
      </tr>
    </table>
    <p style="font-size:13px;color:#aeaeb2;margin:16px 0 0">
      Or copy this link into your browser:<br>
      <span style="word-break:break-all">${acceptUrl}</span>
    </p>
  </td></tr>`
    : ''

  const stepOne = acceptUrl
    ? 'Click <strong>Accept invitation</strong> above to confirm your role.'
    : `Let ${fromName} know you're happy to help.`

  // Web trigger link block (shown below the numbered steps)
  const triggerBlock = triggerUrl
    ? `<tr><td style="padding-bottom:28px">
    <div style="background:#fff8ed;border:1px solid #ffe0a0;border-radius:12px;padding:20px 22px">
      <p style="font-size:15px;font-weight:600;color:#1c1c1e;margin:0 0 8px">📌 Save this link — you'll need it later</p>
      <p style="font-size:14px;color:#3c3c43;line-height:1.5;margin:0 0 12px">
        If you <strong>don't have an iPhone</strong>, use this personal link instead of the app
        when the time comes. It will guide you through notifying ${fromName}'s contacts.
      </p>
      <p style="font-size:13px;color:#636366;word-break:break-all;margin:0">
        <a href="${triggerUrl}" style="color:#007aff">${triggerUrl}</a>
      </p>
    </div>
  </td></tr>`
    : ''

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
    <p style="font-size:32px;margin:0">🤝</p>
  </td></tr>

  <tr><td>
    <h1 style="font-size:22px;font-weight:700;color:#1c1c1e;margin:0 0 16px;text-align:center">
      You've been chosen as a Designated Person
    </h1>
    <p style="font-size:16px;color:#3c3c43;line-height:1.6;margin:0 0 8px">
      Hi ${toName},
    </p>
    <p style="font-size:16px;color:#3c3c43;line-height:1.6;margin:0 0 16px">
      <strong>${fromName}</strong> has named you as their Designated Person on <strong>Last Post</strong> —
      an app that ensures friends and family are notified when someone passes away.
    </p>
    <p style="font-size:16px;color:#3c3c43;line-height:1.6;margin:0 0 32px">
      There is no cause for concern — ${fromName} is simply making preparations for the
      future as part of their legacy planning.
    </p>
  </td></tr>

  <!-- What this means -->
  <tr><td style="padding-bottom:24px">
    <p style="font-size:17px;font-weight:600;color:#1c1c1e;margin:0 0 12px">What does this mean?</p>
    <p style="font-size:15px;color:#3c3c43;line-height:1.6;margin:0 0 8px">
      When the time comes, you'll be responsible for opening the Last Post app and confirming
      that ${fromName} has passed away. Last Post will then automatically notify all of their
      chosen contacts on your behalf — you won't need to make any difficult phone calls or send
      individual messages.
    </p>
  </td></tr>

  <!-- Accept button -->
  ${acceptBlock}

  <!-- What to do next -->
  <tr><td style="padding-bottom:32px">
    <p style="font-size:17px;font-weight:600;color:#1c1c1e;margin:0 0 12px">What happens next?</p>
    <table cellpadding="0" cellspacing="0" width="100%">
      <tr>
        <td style="width:28px;vertical-align:top;padding-top:2px">
          <span style="display:inline-block;width:20px;height:20px;background:#007aff;border-radius:50%;color:#fff;font-size:12px;font-weight:700;text-align:center;line-height:20px">1</span>
        </td>
        <td style="font-size:15px;color:#3c3c43;line-height:1.6;padding-bottom:10px">
          ${stepOne}
        </td>
      </tr>
      <tr>
        <td style="width:28px;vertical-align:top;padding-top:2px">
          <span style="display:inline-block;width:20px;height:20px;background:#007aff;border-radius:50%;color:#fff;font-size:12px;font-weight:700;text-align:center;line-height:20px">2</span>
        </td>
        <td style="font-size:15px;color:#3c3c43;line-height:1.6;padding-bottom:10px">
          Download <strong>Last Post</strong> from the App Store and sign up using
          <strong>this email address</strong> — you'll be automatically recognised as ${fromName}'s Designated Person.
        </td>
      </tr>
      <tr>
        <td style="width:28px;vertical-align:top;padding-top:2px">
          <span style="display:inline-block;width:20px;height:20px;background:#007aff;border-radius:50%;color:#fff;font-size:12px;font-weight:700;text-align:center;line-height:20px">3</span>
        </td>
        <td style="font-size:15px;color:#3c3c43;line-height:1.6">
          When the time comes, open the Last Post app and follow the prompts. If you don't
          have an iPhone, use the personal trigger link in the yellow box below instead.
          Last Post will handle notifying all of ${fromName}'s contacts on your behalf.
        </td>
      </tr>
    </table>
  </td></tr>

  <!-- Web trigger link (for non-iOS designated persons) -->
  ${triggerBlock}

  <tr><td style="text-align:center;padding-bottom:32px">
    <p style="font-size:16px;margin:0 0 8px">
      <a href="https://lastpost.app" style="color:#007aff;font-weight:600">
        Download Last Post
      </a>
    </p>
    <p style="font-size:13px;color:#aeaeb2;margin:0">https://lastpost.app</p>
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

  // ── Send email (only if email address provided) ──
  if (designated_person_email) {
    const emailRes = await fetch('https://api.resend.com/emails', {
      method: 'POST',
      headers: {
        'Authorization': `Bearer ${resendKey}`,
        'Content-Type': 'application/json',
      },
      body: JSON.stringify({
        from: 'Last Post <noreply@lastpost.app>',
        to: [designated_person_email],
        subject: `${fromName} has named you as their Designated Person on Last Post`,
        html: emailHtml,
      }),
    })
    if (!emailRes.ok) {
      const err = await emailRes.text()
      console.error('Resend error:', err)
      // If we also have a phone number, fall through to SMS rather than failing hard
      if (!designated_person_phone) {
        return new Response(JSON.stringify({ error: 'Email send failed', detail: err }), {
          status: 500, headers: { ...CORS, 'Content-Type': 'application/json' },
        })
      }
    }
  }

  // ── SMS (if phone number provided) ──
  if (designated_person_phone) {
    const sid   = Deno.env.get('TWILIO_ACCOUNT_SID')
    const token = Deno.env.get('TWILIO_AUTH_TOKEN')
    const from  = Deno.env.get('TWILIO_FROM_NUMBER')
    console.log('[notify-designated-person] Twilio secrets present:', !!sid, !!token, !!from)
    const smsBody = `Hi ${toName}, ${fromName} has named you as their Designated Person on Last Post. Please download the Last Post app and sign in to confirm your role.`
    await sendSMS(designated_person_phone, smsBody)
  }

  return new Response(JSON.stringify({ ok: true }), {
    headers: { ...CORS, 'Content-Type': 'application/json' },
  })
})
