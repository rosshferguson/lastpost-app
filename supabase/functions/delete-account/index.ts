// delete-account.ts
// Deploy: supabase functions deploy delete-account --project-ref kypzbbupzuaukdkjeghu --no-verify-jwt
//
// Permanently deletes a user's Supabase auth account and all associated DB rows.
// Uses SERVICE_ROLE_KEY so it can call the Admin API regardless of session state.

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

  const { user_id } = await req.json()

  if (!user_id) {
    return new Response(JSON.stringify({ error: 'user_id required' }), {
      status: 400, headers: { ...CORS, 'Content-Type': 'application/json' },
    })
  }

  // Best-effort helper — logs failures but doesn't block the delete
  const bestEffortDelete = async (label: string, url: string) => {
    const res = await fetch(url, { method: 'DELETE', headers: { ...dbHeaders, 'Prefer': 'return=minimal' } })
    if (!res.ok) console.warn(`[delete-account] ${label} delete failed (${res.status}):`, await res.text())
  }

  // 1. Delete designated_persons rows owned by this user
  await bestEffortDelete('designated_persons', `${SUPABASE_URL}/rest/v1/designated_persons?owner_id=eq.${user_id}`)

  // 2. Delete user_contacts rows for this user
  await bestEffortDelete('user_contacts', `${SUPABASE_URL}/rest/v1/user_contacts?owner_id=eq.${user_id}`)

  // 3. Delete profile row
  await bestEffortDelete('profiles', `${SUPABASE_URL}/rest/v1/profiles?id=eq.${user_id}`)

  // 4. Delete the Supabase auth user (Admin API) — this IS critical
  const authRes = await fetch(
    `${SUPABASE_URL}/auth/v1/admin/users/${user_id}`,
    { method: 'DELETE', headers: dbHeaders }
  )
  if (!authRes.ok) {
    const e = await authRes.text()
    console.error('[delete-account] auth user delete failed:', e)
    return new Response(JSON.stringify({ deleted: false, error: 'auth: ' + e }), {
      status: 500, headers: { ...CORS, 'Content-Type': 'application/json' },
    })
  }

  console.log('[delete-account] completed for', user_id)

  return new Response(JSON.stringify({ deleted: true }), {
    headers: { ...CORS, 'Content-Type': 'application/json' },
  })
})
