// get-designated-statuses/index.ts
// Accepts { emails: string[] }, returns { accepted: string[] }
// Uses service role key server-side — safe to call from the app without embedding secrets.
//
// Deploy: supabase functions deploy get-designated-statuses --project-ref kypzbbupzuaukdkjeghu --no-verify-jwt

const CORS = {
  'Access-Control-Allow-Origin': '*',
  'Access-Control-Allow-Headers': 'authorization, x-client-info, apikey, content-type',
}

const SUPABASE_URL     = 'https://kypzbbupzuaukdkjeghu.supabase.co'
const SERVICE_ROLE_KEY = Deno.env.get('SERVICE_ROLE_KEY')!

Deno.serve(async (req) => {
  if (req.method === 'OPTIONS') return new Response('ok', { headers: CORS })

  const { emails } = await req.json() as { emails: string[] }

  if (!emails || emails.length === 0) {
    return new Response(JSON.stringify({ accepted: [] }), {
      headers: { ...CORS, 'Content-Type': 'application/json' },
    })
  }

  // Query designated_persons by email list
  const emailList = emails.map(e => `"${e}"`).join(',')
  const res = await fetch(
    `${SUPABASE_URL}/rest/v1/designated_persons?email=in.(${emailList})&invitation_accepted=eq.true&select=email`,
    {
      headers: {
        'Authorization': `Bearer ${SERVICE_ROLE_KEY}`,
        'apikey': SERVICE_ROLE_KEY,
        'Accept': 'application/json',
      },
    }
  )

  if (!res.ok) {
    console.error('[get-designated-statuses] DB error:', await res.text())
    return new Response(JSON.stringify({ accepted: [] }), {
      headers: { ...CORS, 'Content-Type': 'application/json' },
    })
  }

  const rows = await res.json() as { email: string }[]
  const accepted = rows.map(r => r.email)

  return new Response(JSON.stringify({ accepted }), {
    headers: { ...CORS, 'Content-Type': 'application/json' },
  })
})
