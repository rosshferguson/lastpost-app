// sync-contacts/index.ts
// Deploy: supabase functions deploy sync-contacts --project-ref kypzbbupzuaukdkjeghu --no-verify-jwt
//
// Upserts the current contact list for an owner into user_contacts, then deletes
// any rows whose local_id is no longer in the list (i.e. contact was removed in the app).
//
// Payload:
// {
//   owner_id: string,          // Supabase auth UUID
//   contacts: Array<{
//     local_id: string,        // SwiftData UUID string
//     first_name: string,
//     last_name: string,
//     email: string,
//     phone_number: string,
//     personal_message: string | null,
//     group_name: string | null
//   }>
// }

const CORS = {
  'Access-Control-Allow-Origin': '*',
  'Access-Control-Allow-Headers': 'authorization, x-client-info, apikey, content-type',
}

const SUPABASE_URL     = 'https://kypzbbupzuaukdkjeghu.supabase.co'
const SERVICE_ROLE_KEY = Deno.env.get('SERVICE_ROLE_KEY')!

interface ContactRow {
  local_id:         string
  first_name:       string
  last_name:        string
  email:            string
  phone_number:     string
  personal_message: string
  group_name:       string | null
}

Deno.serve(async (req) => {
  if (req.method === 'OPTIONS') return new Response('ok', { headers: CORS })

  const { owner_id, contacts } = await req.json() as {
    owner_id: string
    contacts: ContactRow[]
  }

  if (!owner_id) {
    return new Response(JSON.stringify({ error: 'owner_id is required' }), {
      status: 400, headers: { ...CORS, 'Content-Type': 'application/json' },
    })
  }

  const dbHeaders = {
    'Authorization': `Bearer ${SERVICE_ROLE_KEY}`,
    'apikey':        SERVICE_ROLE_KEY,
    'Content-Type':  'application/json',
    'Prefer':        'resolution=merge-duplicates',
  }

  // Upsert all provided contacts
  if (Array.isArray(contacts) && contacts.length > 0) {
    const rows = contacts.map(c => ({
      owner_id,
      local_id:         c.local_id,
      first_name:       c.first_name       ?? '',
      last_name:        c.last_name        ?? '',
      email:            c.email            ?? '',
      phone_number:     c.phone_number     ?? '',
      personal_message: c.personal_message ?? '',
      group_name:       c.group_name       ?? null,
      updated_at:       new Date().toISOString(),
    }))

    const upsertRes = await fetch(
      `${SUPABASE_URL}/rest/v1/user_contacts?on_conflict=owner_id,local_id`,
      { method: 'POST', headers: dbHeaders, body: JSON.stringify(rows) }
    )
    if (!upsertRes.ok) {
      const err = await upsertRes.text()
      console.error('[sync-contacts] upsert error:', err)
      return new Response(JSON.stringify({ error: 'upsert failed', detail: err }), {
        status: 500, headers: { ...CORS, 'Content-Type': 'application/json' },
      })
    }

    // Delete any contacts that are no longer in the list
    const keepIds = contacts.map(c => c.local_id)
    // Build a NOT IN filter as repeated OR negation isn't easy in REST;
    // use a custom RPC-style approach: delete where local_id not in list
    // Supabase REST supports `not.in.(a,b,c)` syntax
    const notIn = keepIds.map(id => id).join(',')
    const deleteRes = await fetch(
      `${SUPABASE_URL}/rest/v1/user_contacts?owner_id=eq.${encodeURIComponent(owner_id)}&local_id=not.in.(${encodeURIComponent(notIn)})`,
      { method: 'DELETE', headers: dbHeaders }
    )
    if (!deleteRes.ok) {
      console.error('[sync-contacts] delete old error:', await deleteRes.text())
      // Non-fatal — old contacts linger but don't cause notifications to wrong people
    }
  } else {
    // Empty list: delete all contacts for this owner (user removed everyone)
    const deleteRes = await fetch(
      `${SUPABASE_URL}/rest/v1/user_contacts?owner_id=eq.${encodeURIComponent(owner_id)}`,
      { method: 'DELETE', headers: dbHeaders }
    )
    if (!deleteRes.ok) {
      console.error('[sync-contacts] delete all error:', await deleteRes.text())
    }
  }

  return new Response(JSON.stringify({ ok: true }), {
    headers: { ...CORS, 'Content-Type': 'application/json' },
  })
})
