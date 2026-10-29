// Hands the two phones of an Omni POV session the ICE servers they need: Google's STUN and,
// when set up, short-lived credentials for a Metered TURN relay. Called by the app, signed in.
//
// Secrets (set with `npx supabase secrets set NAME=value`):
//   METERED_APP         the name of the Metered app (the part before .metered.live)
//   METERED_SECRET_KEY  Metered's secret key: it never leaves the server
// Without them the function still answers, with STUN only (`turn: false`): enough for two
// phones on the same Wi-Fi.
// SUPABASE_URL and SUPABASE_SERVICE_ROLE_KEY are provided by Supabase itself.
//
// The gateway does not check the token (verify_jwt = false in config.toml): it is checked
// here, with Auth, so it works with any signing key of the project.

import { createClient } from "npm:@supabase/supabase-js@2";
import {
  bearerToken,
  iceDecision,
  iceResponse,
  TURN_SECONDS,
  turnFromMetered,
} from "./logic.ts";
import type { IceServer, PovSession } from "./logic.ts";

const supabase = createClient(
  Deno.env.get("SUPABASE_URL")!,
  Deno.env.get("SUPABASE_SERVICE_ROLE_KEY")!,
  { auth: { persistSession: false } },
);

/** Short-lived relay servers from Metered; [] when it is not set up or it fails. */
async function relayServers(sessionId: string): Promise<IceServer[]> {
  const app = Deno.env.get("METERED_APP");
  const secret = Deno.env.get("METERED_SECRET_KEY");
  if (!app || !secret) return [];
  try {
    const base = `https://${app}.metered.live/api/v1/turn`;
    const made = await fetch(`${base}/credential?secretKey=${encodeURIComponent(secret)}`, {
      method: "POST",
      headers: { "Content-Type": "application/json" },
      body: JSON.stringify({ expiryInSeconds: TURN_SECONDS, label: `pov-${sessionId}` }),
    });
    if (!made.ok) {
      console.error("metered credential", made.status);
      return [];
    }
    const { apiKey } = await made.json();
    if (typeof apiKey !== "string") return [];
    const list = await fetch(`${base}/credentials?apiKey=${encodeURIComponent(apiKey)}`);
    if (!list.ok) {
      console.error("metered servers", list.status);
      return [];
    }
    return turnFromMetered(await list.json());
  } catch (error) {
    console.error("metered failed", error);
    return [];
  }
}

function json(body: unknown, status = 200) {
  return new Response(JSON.stringify(body), {
    status,
    headers: { "Content-Type": "application/json" },
  });
}

Deno.serve(async (request) => {
  if (request.method !== "POST") return json({ error: "method_not_allowed" }, 405);
  const token = bearerToken(request.headers.get("Authorization"));
  if (!token) return json({ error: "not_signed_in" }, 401);

  try {
    const { data: auth, error: authError } = await supabase.auth.getUser(token);
    if (authError || !auth?.user) return json({ error: "not_signed_in" }, 401);
    const userId = auth.user.id;

    const { data, error } = await supabase
      .from("pov_sessions")
      .select("id, viewer_id, host_id, status, expires_at, ice_calls")
      .or(`viewer_id.eq.${userId},host_id.eq.${userId}`)
      .in("status", ["pending", "accepted"])
      .order("created_at", { ascending: false })
      .limit(1);
    if (error) throw new Error(`read session: ${error.message}`);
    const session = (data?.[0] ?? null) as PovSession | null;

    const decision = iceDecision(session, userId, Date.now());
    if (decision === "not_in_session") return json({ error: "not_in_session" }, 403);
    if (decision === "too_many") return json({ error: "too_many" }, 429);

    const counted = await supabase
      .from("pov_sessions")
      .update({ ice_calls: session!.ice_calls + 1 })
      .eq("id", session!.id);
    if (counted.error) throw new Error(`count call: ${counted.error.message}`);

    return json(iceResponse(await relayServers(session!.id)));
  } catch (error) {
    console.error("pov-ice failed", error);
    return json({ error: "server_error" }, 500);
  }
});
