// remove-designation.ts
// Deploy: supabase functions deploy remove-designation --project-ref kypzbbupzuaukdkjeghu --no-verify-jwt
//
// Called when a designated person removes themselves from someone's account.
// Uses SERVICE_ROLE_KEY to bypass RLS.

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

  const { owner_id, designated_user_id } = await req.json()

  if (!owner_id || !designated_user_id) {
    return new Response(JSON.stringify({ error: 'owner_id and designated_user_id required' }), {
      status: 400, headers: { ...CORS, 'Content-Type': 'application/json' },
    })
  }

  // DELETE the designated_persons row for this owner + designated user pair
  const deleteRes = await fetch(
    `${SUPABASE_URL}/rest/v1/designated_persons?owner_id=eq.${owner_id}&linked_profile_id=eq.${designated_user_id}`,
    {
      method: 'DELETE',
      headers: { ...dbHeaders, 'Prefer': 'return=minimal' },
    }
  )

  console.log('[remove-designation] delete status:', deleteRes.status, 'owner:', owner_id, 'user:', designated_user_id)

  if (!deleteRes.ok) {
    const err = await deleteRes.text()
    console.error('[remove-designation] delete error:', err)
    return new Response(JSON.stringify({ error: 'Delete failed' }), {
      status: 500, headers: { ...CORS, 'Content-Type': 'application/json' },
    })
  }

  return new Response(JSON.stringify({ removed: true }), {
    headers: { ...CORS, 'Content-Type': 'application/json' },
  })
})
