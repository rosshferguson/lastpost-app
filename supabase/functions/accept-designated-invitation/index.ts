// accept-designated-invitation/index.ts
// Called when a designated person clicks "Accept" in their invitation email.
// Marks invitation_accepted = true, then redirects to a confirmation page.
// Uses raw fetch (no Supabase JS client) to avoid auth issues with SERVICE_ROLE_KEY.
//
// Deploy: supabase functions deploy accept-designated-invitation --project-ref kypzbbupzuaukdkjeghu --no-verify-jwt

const SUPABASE_URL     = 'https://kypzbbupzuaukdkjeghu.supabase.co'
const SERVICE_ROLE_KEY = Deno.env.get('SERVICE_ROLE_KEY')!
const SITE_URL         = 'https://lastpost.app'

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

function redirect(page: string): Response {
  return new Response(null, {
    status: 302,
    headers: { Location: `${SITE_URL}/${page}.html` },
  })
}

Deno.serve(async (req) => {
  if (req.method === 'OPTIONS') return new Response('ok', { headers: CORS })

  const url   = new URL(req.url)
  const token = url.searchParams.get('token')

  if (!token) return redirect('expired')

  // Look up the row by acceptance_token
  const res = await fetch(
    `${SUPABASE_URL}/rest/v1/designated_persons?acceptance_token=eq.${encodeURIComponent(token)}&select=id,invitation_accepted&limit=1`,
    { headers: dbHeaders }
  )

  const rows = res.ok ? await res.json() as { id: string; invitation_accepted: boolean }[] : []
  const row  = rows?.[0]

  if (!row) return redirect('expired')
  if (row.invitation_accepted) return redirect('accepted-designated')

  // GET or POST: mark as accepted and redirect to confirmation page
  await fetch(
    `${SUPABASE_URL}/rest/v1/designated_persons?acceptance_token=eq.${encodeURIComponent(token)}`,
    {
      method: 'PATCH',
      headers: dbHeaders,
      body: JSON.stringify({ invitation_accepted: true }),
    }
  )

  return redirect('accepted-designated')
})
