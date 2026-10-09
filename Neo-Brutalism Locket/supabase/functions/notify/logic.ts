// Pure logic of the `notify` Edge Function (no network, no database), so it can be
// tested with plain Node:  node --test supabase/functions/notify/logic.test.ts

export type EventType =
  | "new_post"
  | "message"
  | "reaction"
  | "friend_request"
  | "friend_accepted";

/** What the database trigger (notify_push) sends. */
export interface PushEvent {
  type: EventType;
  /** The person who did it (absent for new_post: the post's author is looked up). */
  from?: string | null;
  /** The person to tell (absent for reaction: it is the post's author). */
  to?: string | null;
  post_id?: string | null;
  body?: string | null;
  emoji?: string | null;
}

export interface Prefs {
  new_post: boolean;
  messages: boolean;
  reactions: boolean;
  friend_requests: boolean;
}

export const DEFAULT_PREFS: Prefs = {
  new_post: true,
  messages: true,
  reactions: true,
  friend_requests: true,
};

const EVENT_TYPES: EventType[] = [
  "new_post",
  "message",
  "reaction",
  "friend_request",
  "friend_accepted",
];

const UUID = /^[0-9a-f]{8}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{12}$/i;

/** Checks the shape of an incoming event; null when it is not one of ours. */
export function parseEvent(raw: unknown): PushEvent | null {
  if (typeof raw !== "object" || raw === null) return null;
  const e = raw as Record<string, unknown>;
  if (!EVENT_TYPES.includes(e.type as EventType)) return null;
  const id = (value: unknown): string | null =>
    typeof value === "string" && UUID.test(value) ? value : null;
  const event: PushEvent = {
    type: e.type as EventType,
    from: id(e.from),
    to: id(e.to),
    post_id: id(e.post_id),
    body: typeof e.body === "string" ? e.body.slice(0, 140) : null,
    emoji: typeof e.emoji === "string" ? e.emoji.slice(0, 16) : null,
  };
  switch (event.type) {
    case "new_post":
      return event.post_id && event.to ? event : null;
    case "message":
      return event.from && event.to && event.body ? event : null;
    case "reaction":
      return event.post_id && event.from && event.emoji ? event : null;
    default:
      return event.from && event.to ? event : null;
  }
}

/** Which setting turns this kind of push off. */
export function prefKey(type: EventType): keyof Prefs {
  switch (type) {
    case "new_post":
      return "new_post";
    case "message":
      return "messages";
    case "reaction":
      return "reactions";
    default:
      return "friend_requests";
  }
}

/** True unless the person switched this kind off. No saved settings = on. */
export function wants(prefs: Partial<Prefs> | null | undefined, type: EventType): boolean {
  const value = prefs?.[prefKey(type)];
  return value !== false;
}

export type Locale = "vi" | "en";

export function asLocale(value: unknown): Locale {
  return value === "en" ? "en" : "vi";
}

export interface Notification {
  title: string;
  body: string;
  /** Strings only (FCM requirement); the app uses these to open the right screen. */
  data: Record<string, string>;
}

/** The text of the push. [actorName] is who did it. */
export function buildNotification(
  event: PushEvent,
  actorName: string,
  locale: Locale,
): Notification {
  const name = actorName.trim() || (locale === "en" ? "Someone" : "Ai đó");
  const vi = locale === "vi";
  const data: Record<string, string> = { type: event.type };
  if (event.post_id) data.post_id = event.post_id;
  // Not "from": FCM reserves that key and rejects the whole message (400).
  if (event.from) data.from_id = event.from;
  switch (event.type) {
    case "new_post":
      return { title: name, body: vi ? "đã gửi cho bạn một ảnh" : "sent you a photo", data };
    case "message":
      return { title: name, body: (event.body ?? "").trim(), data };
    case "reaction":
      return {
        title: name,
        body: vi ? `đã thả ${event.emoji} vào ảnh của bạn` : `reacted ${event.emoji} to your photo`,
        data,
      };
    case "friend_accepted":
      return {
        title: name,
        body: vi ? "đã chấp nhận lời mời kết bạn" : "accepted your friend request",
        data,
      };
    default:
      return {
        title: name,
        body: vi ? "muốn kết bạn với bạn" : "wants to be your friend",
        data,
      };
  }
}

// ---- Home-screen widget ------------------------------------------------------------

/** The parts of a post the widget needs. */
export interface PostInfo {
  kind: string;
  caption: string | null;
  thumb_path: string | null;
  media_path: string;
  created_at: string;
}

/** Which stored file to show on the widget; null for a video with no still. */
export function widgetImagePath(post: PostInfo): string | null {
  if (post.thumb_path) return post.thumb_path;
  return post.kind === "photo" ? post.media_path : null;
}

/** The data-only message that makes the phone refresh its widget. All strings. */
export function buildWidgetData(
  event: PushEvent,
  post: PostInfo,
  actorName: string,
  imageUrl: string,
): Record<string, string> {
  const created = Date.parse(post.created_at);
  return {
    type: "widget_update",
    post_id: event.post_id ?? "",
    name: actorName.trim(),
    caption: (post.caption ?? "").slice(0, 80),
    image_url: imageUrl,
    created_at: String(Number.isNaN(created) ? 0 : created),
  };
}

/** A message with no notification part: the app reads it silently. */
export function fcmDataMessage(token: string, data: Record<string, string>) {
  return { message: { token, data, android: { priority: "HIGH" } } };
}

// ---- Google service account → FCM access token ------------------------------------

export interface ServiceAccount {
  client_email: string;
  private_key: string;
  project_id: string;
}

/** The secret is the downloaded service-account JSON, base64 encoded. */
export function decodeServiceAccount(base64: string): ServiceAccount {
  const json = JSON.parse(new TextDecoder().decode(base64ToBytes(base64.trim())));
  if (!json.client_email || !json.private_key || !json.project_id) {
    throw new Error("service account is missing client_email, private_key or project_id");
  }
  return json as ServiceAccount;
}

export function base64ToBytes(base64: string): Uint8Array {
  const binary = atob(base64.replace(/-/g, "+").replace(/_/g, "/"));
  return Uint8Array.from(binary, (c) => c.charCodeAt(0));
}

export function base64Url(bytes: Uint8Array): string {
  let binary = "";
  for (const byte of bytes) binary += String.fromCharCode(byte);
  return btoa(binary).replace(/\+/g, "-").replace(/\//g, "_").replace(/=+$/, "");
}

function pemToDer(pem: string): Uint8Array {
  const body = pem
    .replace(/-----BEGIN [A-Z ]+-----/, "")
    .replace(/-----END [A-Z ]+-----/, "")
    .replace(/\s+/g, "");
  return base64ToBytes(body);
}

export const FCM_SCOPE = "https://www.googleapis.com/auth/firebase.messaging";
export const TOKEN_URL = "https://oauth2.googleapis.com/token";

/** A signed JWT that Google exchanges for an access token (RS256). */
export async function signServiceAccountJwt(
  account: ServiceAccount,
  nowSeconds: number,
): Promise<string> {
  const encoder = new TextEncoder();
  const header = base64Url(encoder.encode(JSON.stringify({ alg: "RS256", typ: "JWT" })));
  const claims = base64Url(
    encoder.encode(
      JSON.stringify({
        iss: account.client_email,
        scope: FCM_SCOPE,
        aud: TOKEN_URL,
        iat: nowSeconds,
        exp: nowSeconds + 3600,
      }),
    ),
  );
  const key = await crypto.subtle.importKey(
    "pkcs8",
    pemToDer(account.private_key),
    { name: "RSASSA-PKCS1-v1_5", hash: "SHA-256" },
    false,
    ["sign"],
  );
  const signature = await crypto.subtle.sign(
    "RSASSA-PKCS1-v1_5",
    key,
    encoder.encode(`${header}.${claims}`),
  );
  return `${header}.${claims}.${base64Url(new Uint8Array(signature))}`;
}

// ---- FCM -----------------------------------------------------------------------------

/** The request body for one phone (HTTP v1 API). */
export function fcmMessage(token: string, notification: Notification) {
  return {
    message: {
      token,
      notification: { title: notification.title, body: notification.body },
      data: notification.data,
      android: { priority: "HIGH" },
    },
  };
}

/** True when FCM says this token will never work again (app removed, token rotated). */
export function isDeadToken(status: number, body: unknown): boolean {
  if (status === 404) return true;
  const details = (body as { error?: { details?: { errorCode?: string }[] } })?.error?.details;
  return Array.isArray(details) && details.some((d) => d?.errorCode === "UNREGISTERED");
}

/** Compares two secrets without stopping at the first difference. */
export function sameSecret(a: string | null | undefined, b: string | null | undefined): boolean {
  if (!a || !b || a.length !== b.length) return false;
  let diff = 0;
  for (let i = 0; i < a.length; i++) diff |= a.charCodeAt(i) ^ b.charCodeAt(i);
  return diff === 0;
}
