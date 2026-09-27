// accept-contact-invitation/index.ts
// Handles the Accept / Decline links from the invitation email.
// Uses raw fetch (same as notify-contact-added) to avoid JS client auth issues.

const SUPABASE_URL = Deno.env.get("SUPABASE_URL") ?? "";
const SUPABASE_KEY = Deno.env.get("SERVICE_ROLE_KEY") ?? "";
const SITE_URL     = "https://lastpost.app";

const CORS = {
  "Access-Control-Allow-Origin":  "*",
  "Access-Control-Allow-Headers": "authorization, x-client-info, apikey, content-type",
};

function redirect(page: "accepted" | "declined" | "expired" | "error" | "already-responded" | "invalid"): Response {
  return new Response(null, {
    status: 302,
    headers: { Location: `${SITE_URL}/${page}.html`, ...CORS },
  });
}

Deno.serve(async (req) => {
  if (req.method === "OPTIONS") return new Response("ok", { headers: CORS });

  const url    = new URL(req.url);
  const token  = url.searchParams.get("token");
  const action = (url.searchParams.get("action") ?? "accept").toLowerCase();

  if (!token) return redirect("invalid");

  // Look up token in invitation_tokens
  const dbRes = await fetch(
    `${SUPABASE_URL}/rest/v1/invitation_tokens?token=eq.${encodeURIComponent(token)}&select=token,owner_id,email,phone_number,used_at`,
    {
      headers: {
        "apikey":         SUPABASE_KEY,
        "Authorization":  `Bearer ${SUPABASE_KEY}`,
      },
    }
  );

  const rows = dbRes.ok ? await dbRes.json() : [];
  const row  = rows?.[0];

  if (!row) return redirect("expired");
  if (row.used_at) return redirect("already-responded");

  // Mark token as used
  await fetch(
    `${SUPABASE_URL}/rest/v1/invitation_tokens?token=eq.${encodeURIComponent(token)}`,
    {
      method: "PATCH",
      headers: {
        "apikey":         SUPABASE_KEY,
        "Authorization":  `Bearer ${SUPABASE_KEY}`,
        "Content-Type":   "application/json",
      },
      body: JSON.stringify({ used_at: new Date().toISOString(), action }),
    }
  );

  const isAccepted = action !== "decline";

  // Update contacts table — match by email (email contacts) or phone_number (phone-only)
  if (row.owner_id) {
    let contactFilter = "";
    if (row.email) {
      contactFilter = `owner_id=eq.${row.owner_id}&email=eq.${encodeURIComponent(row.email)}`;
    } else if (row.phone_number) {
      contactFilter = `owner_id=eq.${row.owner_id}&phone_number=eq.${encodeURIComponent(row.phone_number)}`;
    }

    if (contactFilter) {
      await fetch(
        `${SUPABASE_URL}/rest/v1/contacts?${contactFilter}`,
        {
          method: "PATCH",
          headers: {
            "apikey":         SUPABASE_KEY,
            "Authorization":  `Bearer ${SUPABASE_KEY}`,
            "Content-Type":   "application/json",
          },
          body: JSON.stringify({
            invitation_accepted: isAccepted,
            invitation_declined: !isAccepted,
          }),
        }
      );

      // If declined, remove from user_contacts so they don't receive death notifications
      if (!isAccepted) {
        let userContactFilter = "";
        if (row.email) {
          userContactFilter = `owner_id=eq.${row.owner_id}&email=eq.${encodeURIComponent(row.email)}`;
        } else if (row.phone_number) {
          userContactFilter = `owner_id=eq.${row.owner_id}&phone_number=eq.${encodeURIComponent(row.phone_number)}`;
        }
        if (userContactFilter) {
          await fetch(
            `${SUPABASE_URL}/rest/v1/user_contacts?${userContactFilter}`,
            {
              method: "DELETE",
              headers: {
                "apikey":        SUPABASE_KEY,
                "Authorization": `Bearer ${SUPABASE_KEY}`,
              },
            }
          );
        }
      }
    }
  }

  if (action === "decline") return redirect("declined");
  return redirect("accepted");
});
