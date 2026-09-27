// request-welfare-check.ts
// Deploy: supabase functions deploy request-welfare-check --project-ref kypzbbupzuaukdkjeghu --no-verify-jwt
//
// Called when the owner taps "Request welfare check" in the app.
// Looks up their designated persons and emails + SMS each one asking them
// to check in with the owner.

const SUPABASE_URL     = 'https://kypzbbupzuaukdkjeghu.supabase.co'
const SERVICE_ROLE_KEY = Deno.env.get('SERVICE_ROLE_KEY')!
const RESEND_API_KEY   = Deno.env.get('RESEND_API_KEY')!
const FROM_EMAIL       = 'Last Post <notifications@lastpost.app>'

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

Deno.serve(async (req) => {
  if (req.method === 'OPTIONS') return new Response('ok', { headers: CORS })

  const { owner_id, owner_name } = await req.json()

  if (!owner_id || !owner_name) {
    return new Response(JSON.stringify({ error: 'owner_id and owner_name required' }), {
      status: 400, headers: { ...CORS, 'Content-Type': 'application/json' },
    })
  }

  // Find accepted designated persons for this owner
  const res = await fetch(
    `${SUPABASE_URL}/rest/v1/designated_persons?owner_id=eq.${encodeURIComponent(owner_id)}&invitation_accepted=eq.true&select=email,first_name,last_name,phone_number`,
    {
      headers: {
        'Authorization': `Bearer ${SERVICE_ROLE_KEY}`,
        'apikey':        SERVICE_ROLE_KEY,
        'Accept':        'application/json',
      },
    }
  )

  if (!res.ok) {
    const err = await res.text()
    return new Response(JSON.stringify({ error: err }), {
      status: 500, headers: { ...CORS, 'Content-Type': 'application/json' },
    })
  }

  const persons = await res.json() as { email: string; first_name: string; last_name: string; phone_number?: string }[]

  if (!persons || persons.length === 0) {
    return new Response(JSON.stringify({ error: 'No accepted designated persons found' }), {
      status: 404, headers: { ...CORS, 'Content-Type': 'application/json' },
    })
  }

  const sent: string[] = []

  for (const person of persons) {
    const html = `
      <div style="font-family: -apple-system, sans-serif; max-width: 520px; margin: 0 auto; padding: 32px 24px; color: #1a1a1a;">
        <div style="text-align: center; margin-bottom: 32px;">
          <div style="width: 56px; height: 56px; background: #e0f2fe; border-radius: 50%; display: inline-flex; align-items: center; justify-content: center; margin-bottom: 12px;">
            <span style="font-size: 24px;">🙋</span>
          </div>
          <h1 style="font-size: 22px; font-weight: 700; margin: 0 0 8px;">Wellness check request</h1>
          <p style="color: #6b7280; margin: 0;">Hi ${person.first_name},</p>
        </div>

        <div style="background: #f0f9ff; border: 1px solid #bae6fd; border-radius: 12px; padding: 20px; margin-bottom: 24px;">
          <p style="margin: 0; font-size: 16px; line-height: 1.6;">
            <strong>${owner_name}</strong> has sent a wellness check request through Last Post. They'd like someone to reach out and check in with them.
          </p>
        </div>

        <p style="color: #4b5563; line-height: 1.6;">
          This isn't an emergency alert — they're just asking you to get in touch when you can. Please contact them directly by phone, message, or in person.
        </p>

        <hr style="border: none; border-top: 1px solid #e5e7eb; margin: 24px 0;" />
        <p style="color: #9ca3af; font-size: 12px; text-align: center; margin: 0;">
          You're receiving this because you're a designated person for ${owner_name} on Last Post.
        </p>
      </div>
    `

    const emailRes = await fetch('https://api.resend.com/emails', {
      method: 'POST',
      headers: {
        'Authorization': `Bearer ${RESEND_API_KEY}`,
        'Content-Type':  'application/json',
      },
      body: JSON.stringify({
        from:    FROM_EMAIL,
        to:      [person.email],
        subject: `${owner_name} has requested a wellness check`,
        html,
      }),
    })

    if (emailRes.ok) sent.push(person.email)
    else console.error('Resend error for', person.email, await emailRes.text())

    // SMS (optional)
    if (person.phone_number) {
      await sendSMS(
        person.phone_number,
        `Hi ${person.first_name}, ${owner_name} has sent a wellness check via Last Post. Please reach out to them when you can.`
      )
    }
  }

  return new Response(JSON.stringify({ sent }), {
    headers: { ...CORS, 'Content-Type': 'application/json' },
  })
})
