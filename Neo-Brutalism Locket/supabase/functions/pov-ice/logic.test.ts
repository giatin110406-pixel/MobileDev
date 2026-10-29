// Run with:  node --test supabase/functions/pov-ice/logic.test.ts
import assert from "node:assert/strict";
import test from "node:test";
import {
  bearerToken,
  iceDecision,
  iceResponse,
  MAX_ICE_CALLS,
  STUN,
  turnFromMetered,
} from "./logic.ts";
import type { PovSession } from "./logic.ts";

const A = "11111111-1111-4111-8111-111111111111";
const B = "22222222-2222-4222-8222-222222222222";
const C = "33333333-3333-4333-8333-333333333333";
const NOW = Date.parse("2026-10-29T10:00:00Z");

function session(over: Partial<PovSession> = {}): PovSession {
  return {
    id: "s1",
    viewer_id: A,
    host_id: B,
    status: "accepted",
    expires_at: "2026-10-29T10:00:45Z",
    ice_calls: 0,
    ...over,
  };
}

test("the two people of an accepted session may have credentials", () => {
  assert.equal(iceDecision(session(), A, NOW), "ok");
  assert.equal(iceDecision(session(), B, NOW), "ok");
});

test("a request still waiting counts, an old one does not", () => {
  assert.equal(iceDecision(session({ status: "pending" }), B, NOW), "ok");
  const old = session({ status: "pending", expires_at: "2026-10-29T09:59:00Z" });
  assert.equal(iceDecision(old, B, NOW), "not_in_session");
});

test("somebody else, no session, or a finished session get nothing", () => {
  assert.equal(iceDecision(session(), C, NOW), "not_in_session");
  assert.equal(iceDecision(null, A, NOW), "not_in_session");
  assert.equal(iceDecision(undefined, A, NOW), "not_in_session");
  for (const status of ["declined", "cancelled", "expired", "ended"]) {
    assert.equal(iceDecision(session({ status }), A, NOW), "not_in_session", status);
  }
});

test("one session may ask only so many times", () => {
  assert.equal(iceDecision(session({ ice_calls: MAX_ICE_CALLS - 1 }), A, NOW), "ok");
  assert.equal(iceDecision(session({ ice_calls: MAX_ICE_CALLS }), A, NOW), "too_many");
});

test("bearerToken reads the header and nothing else", () => {
  assert.equal(bearerToken("Bearer abc.def.ghi"), "abc.def.ghi");
  assert.equal(bearerToken("bearer abc"), "abc");
  assert.equal(bearerToken("Basic abc"), null);
  assert.equal(bearerToken("Bearer"), null);
  assert.equal(bearerToken("Bearer a b"), null);
  assert.equal(bearerToken(null), null);
  assert.equal(bearerToken(undefined), null);
});

test("Metered's servers are kept, rubbish is dropped", () => {
  const raw = [
    { urls: "stun:stun.relay.metered.ca:80" },
    { urls: "turn:global.relay.metered.ca:80", username: "u", credential: "p" },
    { urls: ["turn:a:443?transport=tcp", "turns:a:443"], username: "u", credential: "p" },
    { urls: "turn:no-credentials:80" },
    { urls: 42 },
    "nope",
    null,
  ];
  const kept = turnFromMetered(raw);
  assert.equal(kept.length, 3);
  assert.deepEqual(kept[1], {
    urls: "turn:global.relay.metered.ca:80",
    username: "u",
    credential: "p",
  });
  assert.equal(kept[0].username, undefined);
});

test("an answer that is not a list gives no servers", () => {
  assert.deepEqual(turnFromMetered({ message: "bad key" }), []);
  assert.deepEqual(turnFromMetered(undefined), []);
});

test("the answer always starts with STUN and says whether there is a relay", () => {
  const without = iceResponse([]);
  assert.deepEqual(without.ice_servers, [STUN]);
  assert.equal(without.turn, false);
  const turn = { urls: "turn:x:80", username: "u", credential: "p" };
  const withTurn = iceResponse([turn]);
  assert.deepEqual(withTurn.ice_servers, [STUN, turn]);
  assert.equal(withTurn.turn, true);
  assert.equal(withTurn.expires_in, 1800);
});
