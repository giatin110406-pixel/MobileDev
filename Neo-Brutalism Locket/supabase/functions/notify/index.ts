// Sends a push notification to the phones of one person when something happens
// to them. Called by the database (trigger notify_push -> pg_net), not by the app.
//
// Secrets (see supabase/PUSH_SETUP.md):
//   NOTIFY_SECRET          shared with the database trigger (header x-notify-secret)
//   FCM_SERVICE_ACCOUNT_B64  the Firebase service-account JSON, base64 encoded
// SUPABASE_URL and SUPABASE_SERVICE_ROLE_KEY are provided by Supabase itself.

import { createClient } from "npm:@supabase/supabase-js@2";
import {
  asLocale,
  buildNotification,
  buildWidgetData,
  DEFAULT_PREFS,
  decodeServiceAccount,
  fcmDataMessage,
  fcmMessage,
  isDeadToken,
  parseEvent,
  sameSecret,
  signServiceAccountJwt,
  TOKEN_URL,
  wants,
  widgetImagePath,
} from "./logic.ts";
import type { PostInfo, PushEvent, ServiceAccount } from "./logic.ts";

const supabase = createClient(
  Deno.env.get("SUPABASE_URL")!,
  Deno.env.get("SUPABASE_SERVICE_ROLE_KEY")!,
  { auth: { persistSession: false } },
);

let account: ServiceAccount | null = null;
let cachedToken: { value: string; expires: number } | null = null;

async function accessToken(): Promise<string> {
  const now = Math.floor(Date.now() / 1000);
  if (cachedToken && cachedToken.expires - 60 > now) return cachedToken.value;
  account ??= decodeServiceAccount(Deno.env.get("FCM_SERVICE_ACCOUNT_B64") ?? "");
  const assertion = await signServiceAccountJwt(account, now);
  const response = await fetch(TOKEN_URL, {
    method: "POST",
    headers: { "Content-Type": "application/x-www-form-urlencoded" },
    body: new URLSearchParams({
      grant_type: "urn:ietf:params:oauth:grant-type:jwt-bearer",
      assertion,
    }),
  });
  if (!response.ok) throw new Error(`token exchange failed: ${response.status}`);
  const json = await response.json();
  cachedToken = { value: json.access_token, expires: now + (json.expires_in ?? 3600) };
  return cachedToken.value;
}

/** A query result's data, or an error: never mistake "could not read" for "nothing there". */
function must<T>(result: { data: T; error: { message: string } | null }, what: string): T {
  if (result.error) throw new Error(`${what}: ${result.error.message}`);
  return result.data;
}

/** Works out who did it and who must be told. Null = nobody to tell. */
async function resolveParties(event: PushEvent) {
  if (event.type === "new_post") {
    const data = must(
      await supabase.from("posts")
        .select("author_id, deleted_at, kind, caption, thumb_path, media_path, created_at")
        .eq("id", event.post_id!).maybeSingle(),
      "read post",
    );
    if (!data || data.deleted_at) return null;
    return { actor: data.author_id as string, target: event.to!, post: data as PostInfo };
  }
  if (event.type === "reaction") {
    const data = must(
      await supabase.from("posts").select("author_id").eq("id", event.post_id!)
        .maybeSingle(),
      "read post",
    );
    if (!data) return null;
    return { actor: event.from!, target: data.author_id as string, post: undefined };
  }
  return { actor: event.from!, target: event.to!, post: undefined };
}

Deno.serve(async (request) => {
  if (request.method !== "POST") return new Response("method not allowed", { status: 405 });
  if (!sameSecret(request.headers.get("x-notify-secret"), Deno.env.get("NOTIFY_SECRET"))) {
    return new Response("unauthorized", { status: 401 });
  }

  let event: PushEvent | null = null;
  try {
    event = parseEvent(await request.json());
  } catch (_) { /* falls through */ }
  if (!event) return new Response("bad event", { status: 400 });

  try {
    const parties = await resolveParties(event);
    if (!parties || parties.actor === parties.target) return json({ sent: 0, skipped: "nobody" });

    // Never tell someone about a person they blocked, or who blocked them.
    const blocks = must(
      await supabase.from("blocks").select("blocker_id")
        .or(
          `and(blocker_id.eq.${parties.target},blocked_id.eq.${parties.actor}),` +
            `and(blocker_id.eq.${parties.actor},blocked_id.eq.${parties.target})`,
        ).limit(1),
      "read blocks",
    );
    if (blocks && blocks.length > 0) return json({ sent: 0, skipped: "blocked" });

    const prefs = must(
      await supabase.from("notification_prefs").select("*")
        .eq("user_id", parties.target).maybeSingle(),
      "read notification settings",
    );
    // The widget is separate from notifications: a new photo refreshes it even
    // when the person switched "new photos" notifications off.
    const showPush = wants(prefs ?? DEFAULT_PREFS, event.type);
    const refreshWidget = event.type === "new_post" && parties.post !== undefined;
    if (!showPush && !refreshWidget) return json({ sent: 0, skipped: "prefs" });

    const tokens = must(
      await supabase.from("device_tokens").select("token").eq("user_id", parties.target),
      "read devices",
    );
    if (!tokens || tokens.length === 0) return json({ sent: 0, skipped: "no devices" });

    const [actor, target] = await Promise.all([
      supabase.from("profiles").select("display_name, username").eq("id", parties.actor)
        .maybeSingle().then((r) => must(r, "read sender")),
      supabase.from("profiles").select("locale").eq("id", parties.target).maybeSingle()
        .then((r) => must(r, "read recipient")),
    ]);
    const notification = buildNotification(
      event,
      actor?.display_name ?? actor?.username ?? "",
      asLocale(target?.locale),
    );

    // A short-lived link the phone uses to download the picture for the widget.
    let widgetData: Record<string, string> | null = null;
    if (refreshWidget) {
      const path = widgetImagePath(parties.post!);
      if (path) {
        const signed = await supabase.storage.from("media").createSignedUrl(path, 3600);
        if (signed.data?.signedUrl) {
          widgetData = buildWidgetData(
            event,
            parties.post!,
            actor?.display_name ?? actor?.username ?? "",
            signed.data.signedUrl,
          );
        } else {
          console.error("could not sign widget image", signed.error?.message);
        }
      }
    }
    if (!showPush && !widgetData) return json({ sent: 0, skipped: "nothing to send" });

    const bearer = await accessToken();
    const projectId = account!.project_id;
    let sent = 0;
    const dead: string[] = [];
    const rejected: number[] = []; // FCM's status codes, for diagnosing
    const send = async (token: string, body: unknown): Promise<boolean> => {
      const response = await fetch(
        `https://fcm.googleapis.com/v1/projects/${projectId}/messages:send`,
        {
          method: "POST",
          headers: { Authorization: `Bearer ${bearer}`, "Content-Type": "application/json" },
          body: JSON.stringify(body),
        },
      );
      if (response.ok) return true;
      const failure = await response.json().catch(() => null);
      if (isDeadToken(response.status, failure)) {
        if (!dead.includes(token)) dead.push(token);
      } else {
        rejected.push(response.status);
        console.error("fcm error", response.status, JSON.stringify(failure));
      }
      return false;
    };
    await Promise.all(tokens.map(async ({ token }: { token: string }) => {
      if (showPush && await send(token, fcmMessage(token, notification))) sent++;
      if (widgetData) await send(token, fcmDataMessage(token, widgetData));
    }));
    if (dead.length > 0) {
      must(await supabase.from("device_tokens").delete().in("token", dead), "remove dead phones");
    }
    return json({ sent, removed: dead.length, rejected });
  } catch (error) {
    console.error("notify failed", error);
    return new Response("error", { status: 500 });
  }
});

function json(body: unknown) {
  return new Response(JSON.stringify(body), {
    headers: { "Content-Type": "application/json" },
  });
}
