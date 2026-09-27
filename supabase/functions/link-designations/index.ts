// link-designations.ts
// Deploy: supabase functions deploy link-designations --project-ref kypzbbupzuaukdkjeghu --no-verify-jwt
//
// Called by the app on sign-in and app foreground to link designated_persons rows
// to the signed-in user's Supabase profile. Uses SERVICE_ROLE_KEY so it bypasses
// RLS and works even when the user's access token is expired.

const SUPABASE_URL     = 'https://kypzbbupzuaukdkjeghu.supabase.co'
const SERVICE_ROLE_KEY = Deno.env.get('SERVICE_ROLE_KEY')!

const CORS = {
  'Access-Control-Allow-Origin': '*',
  'Access-Control-Allow-Headers': 'authorization, x-client-info, apikey, content-type',
}

const dbHeaders = {
  'Authorization': `Bearer ${SERVICE_ROLE_KEY}`,
  'apikey': SERVICE_ROLE_KEY,
  'Content-Type': 'application/json',
  'Accept': 'application/json',
}

Deno.serve(async (req) => {
  if (req.method === 'OPTIONS') return new Response('ok', { headers: CORS })

  const { user_id, user_email } = await req.json()

  if (!user_id || !user_email) {
    return new Response(JSON.stringify({ error: 'user_id and user_email required' }), {
      status: 400, headers: { ...CORS, 'Content-Type': 'application/json' },
    })
  }

  const emailEncoded = encodeURIComponent(user_email)

  // Find all designated_persons rows matching this email
  const selectRes = await fetch(
    `${SUPABASE_URL}/rest/v1/designated_persons?email=eq.${emailEncoded}&select=id,linked_profile_id,invitation_accepted`,
    { headers: dbHeaders }
  )

  if (!selectRes.ok) {
    const err = await selectRes.text()
    console.error('[link-designations] select error:', err)
    return new Response(JSON.stringify({ error: 'DB lookup failed' }), {
      status: 500, headers: { ...CORS, 'Content-Type': 'application/json' },
    })
  }

  const rows = await selectRes.json() as {
    id: string
    linked_profile_id: string | null
    invitation_accepted: boolean
  }[]

  console.log('[link-designations] found rows for', user_email, ':', rows.length)

  if (rows.length === 0) {
    return new Response(JSON.stringify({ linked: 0, updated: 0 }), {
      headers: { ...CORS, 'Content-Type': 'application/json' },
    })
  }

  // Update ALL rows for this email — set linked_profile_id and ensure invitation_accepted=true
  const patchRes = await fetch(
    `${SUPABASE_URL}/rest/v1/designated_persons?email=eq.${emailEncoded}`,
    {
      method: 'PATCH',
      headers: { ...dbHeaders, 'Prefer': 'return=minimal' },
      body: JSON.stringify({
        linked_profile_id:   user_id,
        invitation_accepted: true,
      }),
    }
  )

  console.log('[link-designations] patch status:', patchRes.status)

  return new Response(JSON.stringify({ linked: rows.length, updated: rows.length }), {
    headers: { ...CORS, 'Content-Type': 'application/json' },
  })
})
