// sync-legacy-data.ts
// Deploy with: supabase functions deploy sync-legacy-data --project-ref kypzbbupzuaukdkjeghu --no-verify-jwt
//
// Called by the owner when they save funeral wishes, life history, documents or digital assets.
// Uses service role to upsert the relevant JSONB column in profiles.

const SUPABASE_URL     = 'https://kypzbbupzuaukdkjeghu.supabase.co'
const SERVICE_ROLE_KEY = Deno.env.get('SERVICE_ROLE_KEY')!

const CORS = {
  'Access-Control-Allow-Origin': '*',
  'Access-Control-Allow-Headers': 'authorization, x-client-info, apikey, content-type',
}

Deno.serve(async (req) => {
  if (req.method === 'OPTIONS') return new Response('ok', { headers: CORS })

  const { owner_id, column, data } = await req.json()

  const allowed = ['funeral_wishes_data', 'important_documents_data', 'digital_assets_data', 'life_history_data']
  if (!owner_id || !column || !allowed.includes(column)) {
    return new Response(JSON.stringify({ error: 'owner_id and valid column required' }), {
      status: 400, headers: { ...CORS, 'Content-Type': 'application/json' },
    })
  }

  // Upsert: insert or update the profile row
  const res = await fetch(
    `${SUPABASE_URL}/rest/v1/profiles?on_conflict=id`,
    {
      method: 'POST',
      headers: {
        'Authorization': `Bearer ${SERVICE_ROLE_KEY}`,
        'apikey':        SERVICE_ROLE_KEY,
        'Content-Type':  'application/json',
        'Prefer':        'resolution=merge-duplicates',
      },
      body: JSON.stringify({ id: owner_id, [column]: data }),
    }
  )

  if (!res.ok) {
    const err = await res.text()
    console.error('Upsert error:', err)
    return new Response(JSON.stringify({ error: err }), {
      status: 500, headers: { ...CORS, 'Content-Type': 'application/json' },
    })
  }

  return new Response(JSON.stringify({ ok: true }), {
    headers: { ...CORS, 'Content-Type': 'application/json' },
  })
})
