// Run with:  node --test supabase/functions/notify/logic.test.ts
import assert from "node:assert/strict";
import { generateKeyPairSync, createVerify } from "node:crypto";
import test from "node:test";
import {
  asLocale,
  base64Url,
  base64ToBytes,
  buildNotification,
  buildWidgetData,
  decodeServiceAccount,
  fcmDataMessage,
  fcmMessage,
  isDeadToken,
  parseEvent,
  prefKey,
  sameSecret,
  signServiceAccountJwt,
  wants,
  widgetImagePath,
} from "./logic.ts";

const A = "11111111-1111-4111-8111-111111111111";
const B = "22222222-2222-4222-8222-222222222222";
const P = "33333333-3333-4333-8333-333333333333";

test("events: good ones are accepted, malformed ones are not", () => {
  assert.ok(parseEvent({ type: "new_post", post_id: P, to: B }));
  assert.ok(parseEvent({ type: "message", from: A, to: B, body: "hi" }));
  assert.ok(parseEvent({ type: "reaction", post_id: P, from: B, emoji: "🔥" }));
  assert.ok(parseEvent({ type: "friend_request", from: A, to: B }));
  assert.ok(parseEvent({ type: "friend_accepted", from: A, to: B }));

  assert.equal(parseEvent(null), null);
  assert.equal(parseEvent("x"), null);
  assert.equal(parseEvent({ type: "launch_missiles", from: A, to: B }), null);
  assert.equal(parseEvent({ type: "new_post", to: B }), null, "needs a post");
  assert.equal(parseEvent({ type: "message", from: A, to: B }), null, "needs text");
  assert.equal(parseEvent({ type: "message", from: "not-a-uuid", to: B, body: "x" }), null);
  assert.equal(parseEvent({ type: "reaction", post_id: P, from: B }), null, "needs an emoji");
});

test("events: long text is cut", () => {
  const event = parseEvent({ type: "message", from: A, to: B, body: "x".repeat(500) });
  assert.equal(event?.body?.length, 140);
});

test("each kind of push has its own setting", () => {
  assert.equal(prefKey("new_post"), "new_post");
  assert.equal(prefKey("message"), "messages");
  assert.equal(prefKey("reaction"), "reactions");
  assert.equal(prefKey("friend_request"), "friend_requests");
  assert.equal(prefKey("friend_accepted"), "friend_requests");
});

test("settings: on unless switched off", () => {
  assert.equal(wants(null, "message"), true, "nothing saved yet");
  assert.equal(wants({}, "reaction"), true);
  assert.equal(wants({ messages: false }, "message"), false);
  assert.equal(wants({ messages: false }, "reaction"), true, "other kinds unaffected");
  assert.equal(wants({ friend_requests: false }, "friend_accepted"), false);
});

test("text, in both languages", () => {
  const post = parseEvent({ type: "new_post", post_id: P, to: B })!;
  assert.equal(buildNotification(post, "Ava", "vi").body, "đã gửi cho bạn một ảnh");
  assert.equal(buildNotification(post, "Ava", "en").body, "sent you a photo");
  assert.equal(buildNotification(post, "Ava", "en").title, "Ava");

  const message = parseEvent({ type: "message", from: A, to: B, body: "  hi there " })!;
  assert.equal(buildNotification(message, "Ava", "en").body, "hi there");

  const reaction = parseEvent({ type: "reaction", post_id: P, from: B, emoji: "😍" })!;
  assert.equal(buildNotification(reaction, "Bo", "vi").body, "đã thả 😍 vào ảnh của bạn");
  assert.equal(buildNotification(reaction, "Bo", "en").body, "reacted 😍 to your photo");

  const request = parseEvent({ type: "friend_request", from: A, to: B })!;
  assert.equal(buildNotification(request, "Ava", "vi").body, "muốn kết bạn với bạn");
  const accepted = parseEvent({ type: "friend_accepted", from: A, to: B })!;
  assert.equal(buildNotification(accepted, "Ava", "en").body, "accepted your friend request");
});

test("a missing name falls back to a neutral word", () => {
  const request = parseEvent({ type: "friend_request", from: A, to: B })!;
  assert.equal(buildNotification(request, "  ", "en").title, "Someone");
  assert.equal(buildNotification(request, "", "vi").title, "Ai đó");
});

test("the data tells the app where to go, and is all strings", () => {
  const reaction = parseEvent({ type: "reaction", post_id: P, from: B, emoji: "🔥" })!;
  const { data } = buildNotification(reaction, "Bo", "en");
  assert.deepEqual(data, { type: "reaction", post_id: P, from_id: B });
  for (const value of Object.values(data)) assert.equal(typeof value, "string");
});

// FCM rejects a message (HTTP 400) whose data uses one of these keys.
function reservedByFcm(key: string): boolean {
  return (
    ["from", "notification", "message_type", "collapse_key"].includes(key) ||
    key.startsWith("google.") ||
    key.startsWith("gcm.")
  );
}

test("no kind of push uses a data key FCM reserves", () => {
  const events = [
    parseEvent({ type: "new_post", post_id: P, to: B })!,
    parseEvent({ type: "message", from: A, to: B, body: "hi" })!,
    parseEvent({ type: "reaction", post_id: P, from: B, emoji: "🔥" })!,
    parseEvent({ type: "friend_request", from: A, to: B })!,
    parseEvent({ type: "friend_accepted", from: A, to: B })!,
  ];
  for (const event of events) {
    for (const key of Object.keys(buildNotification(event, "Ava", "vi").data)) {
      assert.ok(!reservedByFcm(key), `${event.type} uses reserved key "${key}"`);
    }
  }
  const widget = buildWidgetData(
    events[0],
    { kind: "photo", media_path: "a/p.jpg", thumb_path: null, caption: "", created_at: "2026-10-08T00:00:00Z" },
    "Ava",
    "https://x/y.jpg",
  );
  for (const key of Object.keys(widget)) assert.ok(!reservedByFcm(key), key);
});

test("language falls back to Vietnamese", () => {
  assert.equal(asLocale("en"), "en");
  assert.equal(asLocale("vi"), "vi");
  assert.equal(asLocale(null), "vi");
  assert.equal(asLocale("fr"), "vi");
});

test("the service-account secret is read back from base64", () => {
  const account = { client_email: "x@y.iam", private_key: "k", project_id: "demo" };
  const encoded = Buffer.from(JSON.stringify(account)).toString("base64");
  assert.deepEqual(decodeServiceAccount(encoded), account);
  assert.deepEqual(decodeServiceAccount(`  ${encoded}\n`), account, "tolerates whitespace");
  assert.throws(() => decodeServiceAccount(Buffer.from("{}").toString("base64")));
});

test("the JWT is a valid RS256 token Google would accept", async () => {
  const { privateKey, publicKey } = generateKeyPairSync("rsa", { modulusLength: 2048 });
  const account = {
    client_email: "push@demo.iam.gserviceaccount.com",
    private_key: privateKey.export({ type: "pkcs8", format: "pem" }).toString(),
    project_id: "demo",
  };
  const jwt = await signServiceAccountJwt(account, 1_800_000_000);
  const [header, claims, signature] = jwt.split(".");
  assert.deepEqual(JSON.parse(Buffer.from(header, "base64url").toString()), {
    alg: "RS256",
    typ: "JWT",
  });
  const payload = JSON.parse(Buffer.from(claims, "base64url").toString());
  assert.equal(payload.iss, account.client_email);
  assert.equal(payload.scope, "https://www.googleapis.com/auth/firebase.messaging");
  assert.equal(payload.aud, "https://oauth2.googleapis.com/token");
  assert.equal(payload.iat, 1_800_000_000);
  assert.equal(payload.exp, 1_800_003_600);

  const verifier = createVerify("RSA-SHA256");
  verifier.update(`${header}.${claims}`);
  assert.equal(
    verifier.verify(publicKey, Buffer.from(signature, "base64url")),
    true,
    "signature checks out against the public key",
  );
  assert.ok(!jwt.includes("=") && !jwt.includes("+") && !jwt.includes("/"), "base64url");
});

test("FCM request body", () => {
  const body = fcmMessage("tok", { title: "T", body: "B", data: { type: "message" } });
  assert.deepEqual(body, {
    message: {
      token: "tok",
      notification: { title: "T", body: "B" },
      data: { type: "message" },
      android: { priority: "HIGH" },
    },
  });
});

test("dead tokens are recognised", () => {
  assert.equal(isDeadToken(404, null), true);
  assert.equal(
    isDeadToken(400, { error: { details: [{ errorCode: "UNREGISTERED" }] } }),
    true,
  );
  assert.equal(isDeadToken(400, { error: { details: [{ errorCode: "INVALID_ARGUMENT" }] } }), false);
  assert.equal(isDeadToken(500, null), false, "a server hiccup is not a dead token");
  assert.equal(isDeadToken(200, {}), false);
});

test("secret comparison", () => {
  assert.equal(sameSecret("abc123", "abc123"), true);
  assert.equal(sameSecret("abc123", "abc124"), false);
  assert.equal(sameSecret("abc", "abcd"), false);
  assert.equal(sameSecret(null, "abc"), false);
  assert.equal(sameSecret("", ""), false, "an empty secret never matches");
});

test("base64url helpers round-trip", () => {
  const bytes = Uint8Array.from([250, 251, 252, 253, 254, 255, 0, 1]);
  assert.deepEqual(base64ToBytes(base64Url(bytes)), bytes);
});

const post = {
  kind: "photo",
  caption: "Lunch",
  thumb_path: `${A}/p_thumb.jpg`,
  media_path: `${A}/p.png`,
  created_at: "2026-10-07T12:00:00Z",
};

test("widget: the thumbnail is shown; a photo without one shows the picture itself", () => {
  assert.equal(widgetImagePath(post), `${A}/p_thumb.jpg`);
  assert.equal(widgetImagePath({ ...post, thumb_path: null }), `${A}/p.png`);
});

test("widget: a video with no still has nothing to show", () => {
  assert.equal(
    widgetImagePath({ ...post, kind: "video", thumb_path: null, media_path: "a.mp4" }),
    null,
  );
  assert.equal(widgetImagePath({ ...post, kind: "video" }), post.thumb_path);
});

test("widget data: everything the phone needs, all strings", () => {
  const event = parseEvent({ type: "new_post", post_id: P, to: B })!;
  const data = buildWidgetData(event, post, "  Ava ", "https://x/img?token=1");
  assert.deepEqual(data, {
    type: "widget_update",
    post_id: P,
    name: "Ava",
    caption: "Lunch",
    image_url: "https://x/img?token=1",
    created_at: String(Date.parse("2026-10-07T12:00:00Z")),
  });
  for (const value of Object.values(data)) assert.equal(typeof value, "string");
});

test("widget data: long captions are cut, bad dates become 0", () => {
  const event = parseEvent({ type: "new_post", post_id: P, to: B })!;
  const data = buildWidgetData(
    event,
    { ...post, caption: "x".repeat(200), created_at: "nonsense" },
    "A",
    "u",
  );
  assert.equal(data.caption.length, 80);
  assert.equal(data.created_at, "0");
  assert.equal(buildWidgetData(event, { ...post, caption: null }, "A", "u").caption, "");
});

test("a widget message has no notification part, so the phone shows nothing", () => {
  const message = fcmDataMessage("tok", { type: "widget_update" });
  assert.deepEqual(message, {
    message: { token: "tok", data: { type: "widget_update" }, android: { priority: "HIGH" } },
  });
  assert.equal("notification" in message.message, false);
});
