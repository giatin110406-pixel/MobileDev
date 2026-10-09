"""End-to-end check of the Supabase backend, from the outside, like the app.

Creates three throw-away accounts (A, B, C) in the project named in
env/dev.json, drives every feature through the same REST / RPC / Storage calls
the app makes, checks both what must work and what must be refused (row-level
security), and deletes the accounts at the end.

    python supabase/e2e/e2e_check.py

Uses only the public (publishable) key: nothing here can do more than a user of
the app could. Needs "Confirm email" turned off (Authentication > Providers >
Email), otherwise sign-up does not return a session.
"""
from __future__ import annotations

import base64
import json
import secrets
import sys
import time
import urllib.error
import urllib.parse
import urllib.request
from pathlib import Path

ROOT = Path(__file__).resolve().parents[2]
CONFIG = json.loads((ROOT / "env" / "dev.json").read_text(encoding="utf-8"))
URL = CONFIG["SUPABASE_URL"].rstrip("/")
KEY = CONFIG["SUPABASE_PUBLISHABLE_KEY"]

# A valid 1x1 PNG.
PNG = base64.b64decode(
    "iVBORw0KGgoAAAANSUhEUgAAAAEAAAABCAYAAAAfFcSJAAAADUlEQVR42mP8z8BQDwAEhQGAhKmMIQAAAABJRU5ErkJggg=="
)

passed = 0
failed: list[str] = []


def http(method, path, *, token=None, body=None, raw=None, headers=None, base=None):
    """Returns (status, parsed-json-or-bytes)."""
    url = (base or URL) + path
    data = raw if raw is not None else (json.dumps(body).encode() if body is not None else None)
    request = urllib.request.Request(url, data=data, method=method)
    request.add_header("apikey", KEY)
    if token:
        request.add_header("Authorization", f"Bearer {token}")
    if body is not None:
        request.add_header("Content-Type", "application/json")
    for key, value in (headers or {}).items():
        request.add_header(key, value)
    try:
        with urllib.request.urlopen(request, timeout=30) as response:
            payload = response.read()
            status = response.status
    except urllib.error.HTTPError as error:
        payload = error.read()
        status = error.code
    try:
        return status, json.loads(payload) if payload else None
    except ValueError:
        return status, payload


def rpc(token, name, params=None):
    return http("POST", f"/rest/v1/rpc/{name}", token=token, body=params or {})


def select(token, table, query=""):
    return http("GET", f"/rest/v1/{table}?{query}", token=token)


def error_text(payload) -> str:
    if isinstance(payload, dict):
        return str(payload.get("message") or payload.get("msg") or payload.get("error") or payload)
    return str(payload)


def check(name: str, ok: bool, detail: str = "") -> bool:
    global passed
    if ok:
        passed += 1
        print(f"  ok    {name}")
    else:
        failed.append(name)
        print(f"  FAIL  {name}  {detail}")
    return ok


def rpc_ok(token, name, params=None, label=None):
    status, payload = rpc(token, name, params)
    check(label or f"{name} works", status in (200, 204), f"-> {status} {error_text(payload)}")
    return payload


def rpc_refused(token, name, params, code, label):
    status, payload = rpc(token, name, params)
    check(label, status >= 400 and error_text(payload) == code,
          f"-> {status} {error_text(payload)!r}, wanted {code!r}")


def signup(label: str):
    email = f"e2e-{label}-{secrets.token_hex(4)}@example.com"
    password = secrets.token_urlsafe(16)
    status, payload = http("POST", "/auth/v1/signup", body={"email": email, "password": password})
    if status != 200 or not isinstance(payload, dict) or "access_token" not in payload:
        sys.exit(
            f"Sign-up failed ({status}): {error_text(payload)}\n"
            "If it says the email must be confirmed, turn off Authentication > Providers > Email > "
            "'Confirm email' for the test."
        )
    return {
        "label": label.upper(),
        "token": payload["access_token"],
        "id": payload["user"]["id"],
        "username": f"e2e{label}{secrets.token_hex(3)}",
        "email": email,
    }


def section(title: str):
    print(f"\n{title}")


def main() -> int:
    users: list[dict] = []
    uploaded: list[tuple[dict, str]] = []
    try:
        section("Accounts")
        a, b, c = signup("a"), signup("b"), signup("c")
        users += [a, b, c]
        check("three accounts created and signed in", True)
        for u in users:
            status, rows = select(u["token"], "profiles", f"select=id,username&id=eq.{u['id']}")
            check(f"profile row for {u['label']} was created by the sign-up trigger",
                  status == 200 and len(rows) == 1, f"{status} {rows}")
            status, _ = http("PATCH", f"/rest/v1/profiles?id=eq.{u['id']}", token=u["token"],
                             body={"username": u["username"], "display_name": f"Tester {u['label']}"},
                             headers={"Prefer": "return=minimal"})
            check(f"{u['label']} can set own username and name", status in (200, 204), str(status))

        status, payload = http("PATCH", f"/rest/v1/profiles?id=eq.{a['id']}", token=a["token"],
                               body={"frame_id": "frame_sunflower"})
        check("a user cannot give themselves a shop frame directly",
              status >= 400, f"-> {status} {payload}")
        status, payload = http("PATCH", f"/rest/v1/profiles?id=eq.{b['id']}", token=a["token"],
                               body={"display_name": "hacked"}, headers={"Prefer": "return=representation"})
        check("a user cannot edit someone else's profile",
              status in (200, 204) and not payload, f"-> {status} {payload}")
        status, payload = http("PATCH", f"/rest/v1/profiles?id=eq.{b['id']}", token=b["token"],
                               body={"username": a["username"]})
        check("usernames are unique", status == 409, f"-> {status} {payload}")

        section("Friends")
        rpc_refused(a["token"], "send_friend_request", {"p_username": a["username"]}, "self",
                    "cannot add yourself")
        rpc_refused(a["token"], "send_friend_request", {"p_username": "nobodyatall99"}, "not_found",
                    "unknown username")
        status, payload = rpc(a["token"], "send_friend_request", {"p_username": b["username"]})
        check("A asks B", status == 200 and payload == "sent", f"{status} {payload}")
        rpc_refused(a["token"], "send_friend_request", {"p_username": b["username"]}, "already_sent",
                    "same request twice is refused")
        status, rows = select(b["token"], "friend_requests", "select=id,from_id,status")
        check("B sees the request", status == 200 and len(rows) == 1 and rows[0]["from_id"] == a["id"],
              f"{status} {rows}")
        request_id = rows[0]["id"] if status == 200 and rows else None
        status, rows = select(c["token"], "friend_requests", "select=id")
        check("a stranger sees no requests", status == 200 and rows == [], f"{status} {rows}")
        status, found = rpc(c["token"], "search_profiles", {"p_query": b["username"][:6]})
        check("search finds people by username prefix",
              status == 200 and any(p["id"] == b["id"] for p in found), f"{status} {found}")
        status, payload = http("POST", "/rest/v1/friendships", token=a["token"],
                               body={"user_a": min(a["id"], b["id"]), "user_b": max(a["id"], b["id"])})
        check("friendships cannot be written directly", status >= 400, f"-> {status}")
        rpc_ok(b["token"], "respond_friend_request", {"p_id": request_id, "p_accept": True},
               "B accepts")
        for u in (a, b):
            status, rows = select(u["token"], "friendships", "select=user_a,user_b")
            check(f"{u['label']} sees the friendship", status == 200 and len(rows) == 1, f"{status} {rows}")
        status, rows = select(c["token"], "friendships", "select=user_a")
        check("a stranger sees no friendships", status == 200 and rows == [], f"{status} {rows}")
        rpc_refused(a["token"], "send_friend_request", {"p_username": b["username"]}, "already_friends",
                    "friends cannot send each other requests")

        section("Posts and pictures")
        post_id = _uuid()
        path = f"{a['id']}/{post_id}.png"
        thumb = f"{a['id']}/{post_id}_thumb.jpg"
        for target, content_type in ((path, "image/png"), (thumb, "image/jpeg")):
            status, payload = http("POST", f"/storage/v1/object/media/{target}", token=a["token"], raw=PNG,
                                   headers={"Content-Type": content_type, "x-upsert": "true"})
            check(f"A uploads {target.split('/')[-1]}", status in (200, 201), f"-> {status} {payload}")
            uploaded.append((a, target))
        status, payload = http("POST", f"/storage/v1/object/media/{b['id']}/sneaky.png", token=a["token"],
                               raw=PNG, headers={"Content-Type": "image/png"})
        check("A cannot upload into B's folder", status >= 400, f"-> {status} {payload}")
        status, payload = http("POST", f"/storage/v1/object/media/{a['id']}/x.exe", token=a["token"],
                               raw=b"MZ", headers={"Content-Type": "application/x-msdownload"})
        check("only picture/video file types are accepted", status >= 400, f"-> {status} {payload}")

        params = {"p_id": post_id, "p_kind": "photo", "p_media_path": path, "p_thumb_path": thumb,
                  "p_caption": "hello from e2e", "p_style": "pixel8bit", "p_quest_id": None,
                  "p_overlay": {"time": "09:41", "place": "Huế"}, "p_recipients": None}
        status, payload = rpc(a["token"], "create_post", params)
        check("A creates a post for all friends", status == 200 and payload == post_id, f"{status} {payload}")
        status, payload = rpc(a["token"], "create_post", params)
        check("sending the same post again changes nothing", status == 200 and payload == post_id,
              f"{status} {payload}")
        status, rows = select(a["token"], "post_recipients", f"select=user_id&post_id=eq.{post_id}")
        check("exactly one recipient (B) despite the retry",
              status == 200 and [r["user_id"] for r in rows] == [b["id"]], f"{status} {rows}")
        bad = dict(params, p_id=_uuid(), p_media_path=f"{b['id']}/x.png", p_thumb_path=None)
        rpc_refused(a["token"], "create_post", bad, "bad_path", "cannot point a post at someone else's folder")
        long_caption = dict(params, p_id=_uuid(), p_caption="x" * 81)
        status, payload = rpc(a["token"], "create_post", long_caption)
        check("captions over 80 characters are refused", status >= 400, f"{status} {payload}")

        status, rows = select(b["token"], "posts", "select=id,caption,overlay,style")
        check("B sees A's post, with its labels",
              status == 200 and len(rows) == 1 and rows[0]["overlay"].get("place") == "Huế"
              and rows[0]["style"] == "pixel8bit", f"{status} {rows}")
        status, rows = select(c["token"], "posts", "select=id")
        check("a stranger sees no posts", status == 200 and rows == [], f"{status} {rows}")
        status, payload = http("POST", f"/storage/v1/object/sign/media/{path}", token=b["token"],
                               body={"expiresIn": 120})
        ok = status == 200 and isinstance(payload, dict) and "signedURL" in payload
        check("B can get a signed link to the picture", ok, f"-> {status} {payload}")
        if ok:
            status, content = http("GET", payload["signedURL"], base=URL + "/storage/v1")
            check("the signed link returns the same picture", status == 200 and content == PNG,
                  f"-> {status}")
        status, payload = http("POST", f"/storage/v1/object/sign/media/{path}", token=c["token"],
                               body={"expiresIn": 120})
        check("a stranger cannot get a link to it", status >= 400, f"-> {status} {payload}")

        section("Reactions, views and chat")
        rpc_refused(a["token"], "react_to_post", {"p_post": post_id, "p_emoji": "🔥"}, "not_found",
                    "the author cannot react to their own post")
        rpc_refused(c["token"], "react_to_post", {"p_post": post_id, "p_emoji": "🔥"}, "not_found",
                    "a stranger cannot react")
        rpc_ok(b["token"], "react_to_post", {"p_post": post_id, "p_emoji": "🔥"}, "B reacts")
        rpc_ok(b["token"], "react_to_post", {"p_post": post_id, "p_emoji": "😍"}, "B changes the reaction")
        status, rows = select(a["token"], "post_reactions", "select=emoji,user_id")
        check("A sees one reaction (the latest)", status == 200 and [r["emoji"] for r in rows] == ["😍"],
              f"{status} {rows}")
        status, rows = select(c["token"], "post_reactions", "select=emoji")
        check("a stranger sees no reactions", status == 200 and rows == [], f"{status} {rows}")
        rpc_ok(b["token"], "mark_post_viewed", {"p_post": post_id}, "B marks it seen")
        status, rows = select(a["token"], "post_views", "select=viewer_id")
        check("A sees B looked", status == 200 and [r["viewer_id"] for r in rows] == [b["id"]],
              f"{status} {rows}")
        rpc_refused(c["token"], "send_message", {"p_to": a["id"], "p_body": "hi"}, "not_found",
                    "cannot message a non-friend")
        rpc_refused(b["token"], "send_message", {"p_to": a["id"], "p_body": "   "}, "empty",
                    "empty messages are refused")
        rpc_refused(b["token"], "send_message", {"p_to": a["id"], "p_body": "x" * 501}, "too_long",
                    "messages over 500 characters are refused")
        rpc_ok(b["token"], "send_message", {"p_to": a["id"], "p_body": "nice one", "p_post": post_id},
               "B replies to the post")
        status, rows = select(a["token"], "messages", "select=body,post_id,read_at")
        check("A receives it, unread, linked to the post",
              status == 200 and len(rows) == 1 and rows[0]["post_id"] == post_id and rows[0]["read_at"] is None,
              f"{status} {rows}")
        rpc_ok(a["token"], "mark_thread_read", {"p_with": b["id"]}, "A reads the chat")
        status, rows = select(a["token"], "messages", "select=read_at")
        check("the message is now marked read", status == 200 and rows[0]["read_at"] is not None, f"{rows}")
        status, rows = select(c["token"], "messages", "select=id")
        check("a stranger reads no messages", status == 200 and rows == [], f"{status} {rows}")

        section("Quest, Sunbit and shop")
        status, state = rpc(c["token"], "get_player_state")
        check("a new player starts with 0 Sunbit",
              status == 200 and state["balance"] == 0 and state["streak"] == 0, f"{status} {state}")
        today = state["today"]
        rpc_refused(c["token"], "complete_quest", {"p_day": today, "p_quest_id": "vg_grapes"}, "not_passed",
                    "no reward without a passed photo")
        for i in range(3):
            rpc_ok(c["token"], "record_quest_attempt", {"p_passed": False}, f"miss {i + 1} costs a try")
        rpc_refused(c["token"], "record_quest_attempt", {"p_passed": False}, "no_attempts",
                    "no 4th try today")
        status, payload = http("PATCH", f"/rest/v1/player_state?user_id=eq.{c['id']}", token=c["token"],
                               body={"balance": 9999})
        check("Sunbit cannot be edited directly", status >= 400, f"-> {status} {payload}")
        status, payload = http("POST", "/rest/v1/inventory", token=c["token"],
                               body={"user_id": c["id"], "item_id": "banner_starry_night"})
        check("items cannot be added directly", status >= 400, f"-> {status} {payload}")

        rpc_ok(b["token"], "record_quest_attempt", {"p_passed": True, "p_photo_id": "photo-1"},
               "B's photo passes the check")
        rpc_refused(b["token"], "complete_quest", {"p_day": today - 1, "p_quest_id": "vg_grapes"}, "expired",
                    "yesterday's quest has expired")
        status, reward = rpc(b["token"], "complete_quest", {"p_day": today, "p_quest_id": "vg_grapes"})
        check("posting the quest pays 25 and starts a streak",
              status == 200 and reward["base"] == 25 and reward["bonus"] == 0 and reward["streak"] == 1
              and reward["state"]["balance"] == 25, f"{status} {reward}")
        rpc_refused(b["token"], "complete_quest", {"p_day": today, "p_quest_id": "vg_grapes"}, "already_done",
                    "only one reward per day")
        rpc_refused(b["token"], "record_quest_attempt", {"p_passed": True}, "already_done",
                    "no more tries once finished")
        rpc_refused(b["token"], "buy_item", {"p_item": "frame_pixel"}, "insufficient_funds",
                    "25 Sunbit cannot buy a 50 Sunbit frame")
        rpc_refused(b["token"], "buy_item", {"p_item": "nonsense"}, "not_found", "unknown item")
        rpc_refused(b["token"], "equip_item", {"p_item": "frame_pixel"}, "not_owned",
                    "cannot wear what is not owned")
        status, state = rpc(b["token"], "get_player_state")
        check("the balance is still 25 after the refused purchases",
              status == 200 and state["balance"] == 25 and state["owned"] == [], f"{state}")
        status, rows = select(a["token"], "player_state", "select=balance")
        # B and C have player rows; A never opened the quest, so A may see none.
        check("one player cannot read another's state", status == 200 and rows == [], f"{status} {rows}")
        status, shop = select(a["token"], "shop_items", "select=id,price&order=price")
        check("the shop lists 10 items from 50 to 500 Sunbit",
              status == 200 and len(shop) == 10 and shop[0]["price"] == 50 and shop[-1]["price"] == 500,
              f"{status} {shop}")

        section("Push registration")
        probe_status, probe = rpc(a["token"], "register_device", {"p_token": "x" * 10})
        if probe_status == 404:
            print("  skipped  (migration 7, push, is not applied yet)")
        else:
            token = "e2e-token-" + secrets.token_hex(16)
            check("a too-short token is refused", probe_status >= 400 and error_text(probe) == "bad_token",
                  f"{probe_status} {probe}")
            rpc_ok(a["token"], "register_device", {"p_token": token, "p_platform": "android"},
                   "A registers a phone")
            status, rows = select(a["token"], "device_tokens", "select=token,user_id")
            check("A sees their phone", status == 200 and [r["token"] for r in rows] == [token], f"{rows}")
            status, rows = select(c["token"], "device_tokens", "select=token")
            check("a stranger sees no phones", status == 200 and rows == [], f"{rows}")
            rpc_refused(a["token"], "register_device", {"p_token": token, "p_platform": "windows"},
                        "bad_platform", "only android / ios platforms")
            rpc_ok(b["token"], "register_device", {"p_token": token}, "B signs in on the same phone")
            status, rows = select(a["token"], "device_tokens", "select=token")
            check("the phone moved to B, A no longer gets B's pushes", status == 200 and rows == [], f"{rows}")
            rpc_ok(a["token"], "unregister_device", {"p_token": token}, "A cannot remove B's phone (no-op)")
            status, rows = select(b["token"], "device_tokens", "select=token")
            check("B still has the phone", status == 200 and len(rows) == 1, f"{rows}")
            rpc_ok(b["token"], "unregister_device", {"p_token": token}, "B signs out of the phone")
            status, rows = select(b["token"], "device_tokens", "select=token")
            check("the phone is gone", status == 200 and rows == [], f"{rows}")

            status, _ = http("POST", "/rest/v1/notification_prefs", token=a["token"],
                             body={"user_id": a["id"], "messages": False},
                             headers={"Prefer": "resolution=merge-duplicates,return=minimal"})
            check("A saves their notification settings", status in (200, 201, 204), str(status))
            status, rows = select(a["token"], "notification_prefs", "select=messages,new_post")
            check("they read back (messages off, the rest on)",
                  status == 200 and rows == [{"messages": False, "new_post": True}], f"{rows}")
            status, rows = select(b["token"], "notification_prefs", "select=messages")
            check("another user cannot read them", status == 200 and rows == [], f"{rows}")
            status, payload = http("POST", "/rest/v1/notification_prefs", token=b["token"],
                                   body={"user_id": a["id"], "messages": True},
                                   headers={"Prefer": "resolution=merge-duplicates"})
            check("another user cannot change them", status >= 400, f"-> {status} {payload}")

        if "--push-probe" in sys.argv:
            section("Push pipeline probe")
            fake = "e2e-fake-token-" + secrets.token_hex(60)
            status, _ = rpc(b["token"], "register_device", {"p_token": fake})
            if status == 404:
                print("  skipped  (migration 7 is not applied)")
            else:
                status, rows = select(b["token"], "device_tokens", "select=token")
                check("B's fake phone is registered before the message is sent",
                      status == 200 and [r["token"] for r in rows] == [fake], f"{status} {rows}")
                import datetime

                sent_at = datetime.datetime.now(datetime.timezone.utc)
                rpc_ok(a["token"], "send_message", {"p_to": b["id"], "p_body": "push probe"},
                       "A sends B a message (B has a fake phone)")
                time.sleep(6)
                print(f"  The message was sent at {sent_at:%Y-%m-%d %H:%M:%S} UTC. In the SQL Editor:")
                print("    select created, status_code, content from net._http_response"
                      f" where created >= '{sent_at:%Y-%m-%d %H:%M:%S}+00' order by created;")
                print("  Healthy: 200 and {\"sent\":0,\"removed\":0,\"rejected\":[400]}")
                print("   (400 = Google accepted our key, then refused the fake phone token).")
                print("  401 = Vault notify_secret differs from the function's NOTIFY_SECRET.")
                print("  500 = see Edge Functions > notify > Logs (usually the Firebase key).")

        section("Blocking and reporting")
        rpc_refused(c["token"], "report_content", {"p_user": None, "p_post": post_id, "p_reason": "spam"},
                    "not_found", "a stranger cannot report a post they never saw")
        rpc_refused(b["token"], "report_content", {"p_user": None, "p_post": post_id, "p_reason": "nonsense"},
                    "bad_reason", "only known report reasons")
        rpc_ok(b["token"], "report_content",
               {"p_user": None, "p_post": post_id, "p_reason": "spam", "p_details": "e2e test"},
               "B reports A's post")
        status, rows = select(b["token"], "reports", "select=id")
        check("reports cannot be read back by users", status >= 400 or rows == [], f"{status} {rows}")
        rpc_refused(a["token"], "block_user", {"p_user": a["id"]}, "self", "cannot block yourself")
        rpc_ok(a["token"], "block_user", {"p_user": b["id"]}, "A blocks B")
        status, rows = select(a["token"], "friendships", "select=user_a")
        check("blocking ends the friendship", status == 200 and rows == [], f"{status} {rows}")
        status, rows = select(b["token"], "posts", "select=id")
        check("B can no longer see A's earlier post", status == 200 and rows == [], f"{status} {rows}")
        rpc_refused(b["token"], "send_message", {"p_to": a["id"], "p_body": "hello?"}, "not_found",
                    "B cannot message A")
        rpc_refused(b["token"], "send_friend_request", {"p_username": a["username"]}, "not_found",
                    "B cannot find A to re-add them")
        status, found = rpc(b["token"], "search_profiles", {"p_query": a["username"][:6]})
        check("A is hidden from B's search", status == 200 and not any(p["id"] == a["id"] for p in found),
              f"{found}")
        status, rows = select(a["token"], "blocks", "select=blocked_id")
        check("A sees who they blocked", status == 200 and [r["blocked_id"] for r in rows] == [b["id"]],
              f"{rows}")
        status, rows = select(b["token"], "blocks", "select=blocked_id")
        check("B cannot see that they were blocked", status == 200 and rows == [], f"{rows}")
        rpc_ok(a["token"], "unblock_user", {"p_user": b["id"]}, "A unblocks B")
        rpc_ok(a["token"], "delete_post", {"p_post": post_id}, "A deletes the post")
        status, rows = select(a["token"], "posts", "select=id")
        check("a deleted post is gone", status == 200 and rows == [], f"{status} {rows}")
    finally:
        section("Cleanup")
        for owner, target in uploaded:
            http("DELETE", "/storage/v1/object/media", token=owner["token"], body={"prefixes": [target]})
        for user in users:
            status, payload = rpc(user["token"], "delete_my_account")
            check(f"{user['label']} deleted their account", status in (200, 204),
                  f"-> {status} {error_text(payload)}")
        if users:
            time.sleep(1)
            status, payload = http("GET", "/auth/v1/user", token=users[0]["token"])
            check("a deleted account's sign-in no longer works", status >= 400, f"-> {status}")

    print(f"\n{passed} checks passed, {len(failed)} failed")
    for name in failed:
        print(f"  - {name}")
    return 1 if failed else 0


def _uuid() -> str:
    import uuid

    return str(uuid.uuid4())


if __name__ == "__main__":
    sys.exit(main())
