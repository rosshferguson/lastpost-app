// get-profile-id.ts
// Deploy: supabase functions deploy get-profile-id --project-ref kypzbbupzuaukdkjeghu --no-verify-jwt
//
// DEBUG ONLY — takes an email, returns the matching profile UUID.
// Uses service role so RLS is bypassed.

const SUPABASE_URL     = 'https://kypzbbupzuaukdkjeghu.supabase.co'
const SERVICE_ROLE_KEY = Deno.env.get('SERVICE_ROLE_KEY')!

const CORS = {
  'Access-Control-Allow-Origin': '*',
  'Access-Control-Allow-Headers': 'authorization, x-client-info, apikey, content-type',
}

Deno.serve(async (req) => {
  if (req.method === 'OPTIONS') return new Response('ok', { headers: CORS })

  const { email } = await req.json()
  if (!email) {
    return new Response(JSON.stringify({ error: 'email required' }), {
      status: 400, headers: { ...CORS, 'Content-Type': 'application/json' },
    })
  }

  const res = await fetch(
    `${SUPABASE_URL}/rest/v1/profiles?email=eq.${encodeURIComponent(email)}&select=id&limit=1`,
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

  const rows = await res.json() as { id: string }[]
  return new Response(JSON.stringify({ id: rows[0]?.id ?? null }), {
    headers: { ...CORS, 'Content-Type': 'application/json' },
  })
})
