// get-legacy-data.ts
// Deploy with: supabase functions deploy get-legacy-data --project-ref kypzbbupzuaukdkjeghu --no-verify-jwt
//
// Called by a designated person after the death notification is confirmed.
// Returns the owner's funeral wishes, important documents, digital assets and life history.

const SUPABASE_URL     = 'https://kypzbbupzuaukdkjeghu.supabase.co'
const SERVICE_ROLE_KEY = Deno.env.get('SERVICE_ROLE_KEY')!

const CORS = {
  'Access-Control-Allow-Origin': '*',
  'Access-Control-Allow-Headers': 'authorization, x-client-info, apikey, content-type',
}

Deno.serve(async (req) => {
  if (req.method === 'OPTIONS') return new Response('ok', { headers: CORS })

  const { owner_id } = await req.json()

  if (!owner_id) {
    return new Response(JSON.stringify({ error: 'owner_id required' }), {
      status: 400, headers: { ...CORS, 'Content-Type': 'application/json' },
    })
  }

  const res = await fetch(
    `${SUPABASE_URL}/rest/v1/profiles?id=eq.${encodeURIComponent(owner_id)}&select=funeral_wishes_data,important_documents_data,digital_assets_data,life_history_data&limit=1`,
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
    console.error('Profile fetch error:', err)
    return new Response(JSON.stringify({ error: err }), {
      status: 500, headers: { ...CORS, 'Content-Type': 'application/json' },
    })
  }

  const rows = await res.json() as Record<string, unknown>[]
  const result = rows[0] ?? {
    funeral_wishes_data:      null,
    important_documents_data: null,
    digital_assets_data:      null,
    life_history_data:        null,
  }

  return new Response(JSON.stringify(result), {
    headers: { ...CORS, 'Content-Type': 'application/json' },
  })
})
