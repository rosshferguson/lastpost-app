// accept-contact-invitation.ts
// Deploy with: supabase functions deploy accept-contact-invitation --no-verify-jwt
//
// Called from the email link:
//   ?token=<acceptance_token>&action=accept   (default)
//   ?token=<acceptance_token>&action=decline

import { createClient } from 'https://esm.sh/@supabase/supabase-js@2'

function htmlResponse(title: string, message: string): Response {
  const html = `<!DOCTYPE html>
<html lang="en">
<head>
<meta charset="utf-8">
<meta name="viewport" content="width=device-width, initial-scale=1">
<title>${title}</title>
<style>
body{font-family:-apple-system,sans-serif;background:#f2f2f7;display:flex;align-items:center;justify-content:center;min-height:100vh;margin:0;padding:24px;box-sizing:border-box}
.card{background:#fff;border-radius:16px;padding:40px 32px;max-width:420px;width:100%;text-align:center}
h1{font-size:22px;color:#1c1c1e;margin:0 0 12px}
p{font-size:16px;color:#6c6c70;line-height:1.5;margin:0}
</style>
</head>
<body>
<div class="card">
<h1>${title}</h1>
<p>${message}</p>
</div>
</body>
</html>`

  const headers = new Headers()
  headers.set('content-type', 'text/html; charset=utf-8')
  headers.set('content-disposition', 'inline')
  headers.set('x-content-type-options', 'nosniff')
  headers.set('cache-control', 'no-store')
  return new Response(html, { status: 200, headers })
}

Deno.serve(async (req) => {
  if (req.method === 'OPTIONS') {
    return new Response('ok', {
      headers: {
        'Access-Control-Allow-Origin': '*',
        'Access-Control-Allow-Headers': 'authorization, x-client-info, apikey, content-type',
      },
    })
  }

  const url    = new URL(req.url)
  const token  = url.searchParams.get('token')
  const action = (url.searchParams.get('action') ?? 'accept').toLowerCase()

  if (!token) {
    return htmlResponse(
      'Invalid Link',
      'This invitation link is missing required information. Please ask to be re-invited.'
    )
  }

  const supabase = createClient(
    Deno.env.get('SUPABASE_URL')!,
    Deno.env.get('SUPABASE_SERVICE_ROLE_KEY')!
  )

  const { data: contact, error: lookupError } = await supabase
    .from('contacts')
    .select('id, first_name, invitation_accepted, invitation_declined')
    .eq('acceptance_token', token)
    .maybeSingle()

  if (lookupError || !contact) {
    return htmlResponse(
      'Link Expired',
      'This invitation link has already been used or is no longer valid. Please ask to be re-invited.'
    )
  }

  if (contact.invitation_accepted) {
    return htmlResponse(
      'Already Confirmed',
      "You have already confirmed this invitation. You are on the list."
    )
  }

  if (contact.invitation_declined) {
    return htmlResponse(
      'Already Declined',
      "You previously declined this invitation. If you have changed your mind, ask to be re-invited."
    )
  }

  if (action === 'decline') {
    await supabase
      .from('contacts')
      .update({ invitation_declined: true, acceptance_token: null })
      .eq('id', contact.id)

    return htmlResponse(
      'Invitation Declined',
      "You have been removed from the notification list. If you change your mind, ask to be re-invited."
    )
  }

  const { error: updateError } = await supabase
    .from('contacts')
    .update({ invitation_accepted: true, acceptance_token: null })
    .eq('id', contact.id)

  if (updateError) {
    return htmlResponse(
      'Something Went Wrong',
      "We could not save your response. Please try the link again."
    )
  }

  return htmlResponse(
    "You are on the list",
    "Thanks for confirming. You will be notified by Last Post when the time comes. You do not need to do anything else."
  )
})
