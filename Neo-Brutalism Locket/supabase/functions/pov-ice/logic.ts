// Pure logic of the `pov-ice` Edge Function (no network, no database), so it can be
// tested with plain Node:  node --test supabase/functions/pov-ice/logic.test.ts
//
// The function hands the two phones of an Omni POV session the servers they need to find
// each other: Google's free STUN, and, when set up, a TURN relay from Metered (for two
// phones that cannot reach each other directly, e.g. both on mobile data).

export interface IceServer {
  urls: string | string[];
  username?: string;
  credential?: string;
}

/** Always offered: it is enough for two phones on the same Wi-Fi. */
export const STUN: IceServer = { urls: "stun:stun.l.google.com:19302" };

/** How long the relay credentials last (a session is over after 30 minutes). */
export const TURN_SECONDS = 30 * 60;

/** How many times one session may ask for credentials. */
export const MAX_ICE_CALLS = 20;

export interface PovSession {
  id: string;
  viewer_id: string;
  host_id: string;
  status: string;
  expires_at: string;
  ice_calls: number;
}

export type IceDecision = "ok" | "not_in_session" | "too_many";

/** May [userId] have credentials for [session] now? */
export function iceDecision(
  session: PovSession | null | undefined,
  userId: string,
  nowMs: number,
): IceDecision {
  if (!session) return "not_in_session";
  if (session.viewer_id !== userId && session.host_id !== userId) return "not_in_session";
  const waiting = session.status === "pending" && Date.parse(session.expires_at) > nowMs;
  if (session.status !== "accepted" && !waiting) return "not_in_session";
  if (session.ice_calls >= MAX_ICE_CALLS) return "too_many";
  return "ok";
}

/** The token in an `Authorization: Bearer <token>` header, or null. */
export function bearerToken(header: string | null | undefined): string | null {
  const match = /^Bearer\s+(\S+)$/i.exec(header ?? "");
  return match ? match[1] : null;
}

/** The relay servers in Metered's answer; anything that is not a usable server is dropped. */
export function turnFromMetered(raw: unknown): IceServer[] {
  if (!Array.isArray(raw)) return [];
  const servers: IceServer[] = [];
  for (const item of raw) {
    if (typeof item !== "object" || item === null) continue;
    const entry = item as Record<string, unknown>;
    const urls = entry.urls ?? entry.url;
    const usable = typeof urls === "string" ||
      (Array.isArray(urls) && urls.length > 0 && urls.every((u) => typeof u === "string"));
    if (!usable) continue;
    const server: IceServer = { urls: urls as string | string[] };
    if (typeof entry.username === "string") server.username = entry.username;
    if (typeof entry.credential === "string") server.credential = entry.credential;
    // A relay without credentials is of no use.
    const isTurn = [urls].flat().some((u) => /^turns?:/i.test(u as string));
    if (isTurn && (!server.username || !server.credential)) continue;
    servers.push(server);
  }
  return servers;
}

/** What the phone gets: STUN first, then the relay when there is one. */
export function iceResponse(turn: IceServer[]) {
  return {
    ice_servers: [STUN, ...turn],
    turn: turn.length > 0,
    expires_in: TURN_SECONDS,
  };
}
