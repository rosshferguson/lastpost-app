// get-trigger-info/index.ts
// Deploy: supabase functions deploy get-trigger-info --project-ref kypzbbupzuaukdkjeghu --no-verify-jwt
//
// Called by trigger.html on page load to show the designated person what they're about to do.
//
// Accepts token via GET query param OR POST body:
//   GET  /get-trigger-info?token=abc123
//   POST /get-trigger-info   body: { token: "abc123" }
//
// Returns:
// {
//   found: true,
//   ownerName: "James Strong",
//   designatedPersonName: "Sarah Ferguson",
//   contactCount: 12
// }
// or: { found: false }

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

Deno.serve(async (req) => {
  if (req.method === 'OPTIONS') return new Response('ok', { headers: CORS })

  // Accept token from GET query string or POST body
  let token: string | null = null

  if (req.method === 'GET') {
    const url = new URL(req.url)
    token = url.searchParams.get('token')
  } else {
    try {
      const body = await req.json()
      token = body.token ?? null
    } catch {
      // ignore parse errors
    }
  }

  if (!token) {
    return new Response(JSON.stringify({ found: false, error: 'token is required' }), {
      status: 400, headers: { ...CORS, 'Content-Type': 'application/json' },
    })
  }

  // 1. Look up the designated_persons row
  const dpRes = await fetch(
    `${SUPABASE_URL}/rest/v1/designated_persons?trigger_token=eq.${encodeURIComponent(token)}&select=owner_id,first_name,last_name&limit=1`,
    { headers: dbHeaders }
  )

  if (!dpRes.ok) {
    return new Response(JSON.stringify({ found: false }), {
      status: 200, headers: { ...CORS, 'Content-Type': 'application/json' },
    })
  }

  const dpRows = await dpRes.json() as { owner_id: string; first_name: string; last_name: string }[]
  const dp = dpRows[0]

  if (!dp) {
    return new Response(JSON.stringify({ found: false }), {
      headers: { ...CORS, 'Content-Type': 'application/json' },
    })
  }

  const { owner_id } = dp
  const designatedPersonName = [dp.first_name, dp.last_name].filter(Boolean).join(' ') || 'Unknown'

  // 2. Look up the owner's name from profiles
  const profileRes = await fetch(
    `${SUPABASE_URL}/rest/v1/profiles?id=eq.${encodeURIComponent(owner_id)}&select=first_name,last_name&limit=1`,
    { headers: dbHeaders }
  )

  let ownerName = 'the account holder'
  if (profileRes.ok) {
    const profiles = await profileRes.json() as { first_name?: string; last_name?: string }[]
    const p = profiles[0]
    if (p) {
      ownerName = [p.first_name, p.last_name].filter(Boolean).join(' ') || ownerName
    }
  }

  // 3. Count the owner's synced contacts
  const countRes = await fetch(
    `${SUPABASE_URL}/rest/v1/user_contacts?owner_id=eq.${encodeURIComponent(owner_id)}&select=id`,
    { headers: { ...dbHeaders, 'Prefer': 'count=exact', 'Accept': 'application/json' } }
  )

  let contactCount = 0
  if (countRes.ok) {
    const countHeader = countRes.headers.get('content-range')
    // content-range: 0-11/12  →  "12"
    if (countHeader) {
      const total = countHeader.split('/')[1]
      contactCount = parseInt(total ?? '0', 10) || 0
    } else {
      // Fallback: count returned rows
      const rows = await countRes.json() as unknown[]
      contactCount = rows.length
    }
  }

  return new Response(JSON.stringify({
    found: true,
    ownerName,
    designatedPersonName,
    contactCount,
  }), {
    headers: { ...CORS, 'Content-Type': 'application/json' },
  })
})
