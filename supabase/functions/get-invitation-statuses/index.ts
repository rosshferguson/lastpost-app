// get-invitation-statuses.ts
// Deploy with: supabase functions deploy get-invitation-statuses --project-ref kypzbbupzuaukdkjeghu
//
// Called by the app to check which of the owner's contacts have accepted/declined.
// Uses service role to bypass RLS — safe because we match on emails the caller provided.
// Also backfills owner_id on any NULL rows it finds, fixing legacy data.

const SUPABASE_URL     = 'https://kypzbbupzuaukdkjeghu.supabase.co'
const SERVICE_ROLE_KEY = Deno.env.get('SERVICE_ROLE_KEY')!

const CORS = {
  'Access-Control-Allow-Origin': '*',
  'Access-Control-Allow-Headers': 'authorization, x-client-info, apikey, content-type',
}

const dbHeaders = {
  'Authorization': `Bearer ${SERVICE_ROLE_KEY}`,
  'apikey':        SERVICE_ROLE_KEY,
  'Accept':        'application/json',
  'Content-Type':  'application/json',
}

Deno.serve(async (req) => {
  if (req.method === 'OPTIONS') return new Response('ok', { headers: CORS })

  const { emails, ownerSupabaseId } = await req.json()

  if (!emails || !Array.isArray(emails) || emails.length === 0) {
    return new Response(JSON.stringify([]), {
      headers: { ...CORS, 'Content-Type': 'application/json' },
    })
  }

  // Find used tokens for any of these emails
  const emailList = emails.map((e: string) => `"${e}"`).join(',')
  const res = await fetch(
    `${SUPABASE_URL}/rest/v1/invitation_tokens?email=in.(${emailList})&used_at=not.is.null&select=email,action,owner_id`,
    { headers: dbHeaders }
  )

  if (!res.ok) {
    const err = await res.text()
    return new Response(JSON.stringify({ error: err }), {
      status: 500, headers: { ...CORS, 'Content-Type': 'application/json' },
    })
  }

  const rows = await res.json() as { email: string; action: string | null; owner_id: string | null }[]

  // Backfill owner_id on any NULL rows so future syncs work correctly
  if (ownerSupabaseId && rows) {
    for (const row of rows) {
      if (!row.owner_id) {
        await fetch(
          `${SUPABASE_URL}/rest/v1/invitation_tokens?email=eq.${encodeURIComponent(row.email)}&owner_id=is.null`,
          {
            method: 'PATCH',
            headers: dbHeaders,
            body: JSON.stringify({ owner_id: ownerSupabaseId }),
          }
        )
      }
    }
  }

  return new Response(JSON.stringify(rows), {
    headers: { ...CORS, 'Content-Type': 'application/json' },
  })
})
