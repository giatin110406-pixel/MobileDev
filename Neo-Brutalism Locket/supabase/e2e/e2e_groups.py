"""End-to-end check of groups, Ink and the shared canvas, from the outside.

Creates four throw-away accounts in the project named in env/dev.json:

    O  the group's owner (friends with F and S)
    F  a member, friend of O
    S  a member, friend of O, but NOT a friend of F (the privacy case)
    X  somebody outside the group

Drives groups, chat, Ink and the canvas through the same RPC calls the app makes,
checks what must work and what must be refused, then deletes the accounts.

    python supabase/e2e/e2e_groups.py

Uses only the publishable key. Needs "Confirm email" turned off, like e2e_check.py.
The dissolved test groups cannot be deleted with that key (nobody can delete a
group from the app); they are named "E2E ..." so they are easy to find and remove
in the Supabase dashboard.
"""
from __future__ import annotations

import base64
import sys
import threading
import time

import e2e_check as h

PASSWORD_NOTE = "e2e"


def run_quest(user) -> int:
    """Completes today's quest; returns the Ink the server says it paid."""
    status, state = h.rpc(user["token"], "get_player_state")
    today = state["today"]
    h.rpc(user["token"], "record_quest_attempt", {"p_passed": True, "p_photo_id": "e2e"})
    status, payload = h.rpc(user["token"], "complete_quest",
                            {"p_day": today, "p_quest_id": "vg_grapes"})
    return payload.get("ink", -1) if status == 200 else -1


def pixels_of(canvas: dict) -> bytes:
    return base64.b64decode(canvas["pixels"])


def main() -> int:
    users: list[dict] = []
    try:
        h.section("Accounts and friendships")
        o, f, s, x = h.signup("o"), h.signup("f"), h.signup("s"), h.signup("x")
        users += [o, f, s, x]
        for u in users:
            status, _ = h.http("PATCH", f"/rest/v1/profiles?id=eq.{u['id']}", token=u["token"],
                               body={"username": u["username"], "display_name": f"E2E {u['label']}"},
                               headers={"Prefer": "return=minimal"})
            h.check(f"{u['label']} has a username", status in (200, 204), str(status))
        for other in (f, s):
            h.rpc_ok(o["token"], "send_friend_request", {"p_username": other["username"]},
                     f"O asks {other['label']} to be friends")
            status, rows = h.select(other["token"], "friend_requests", "select=id&status=eq.pending")
            h.rpc_ok(other["token"], "respond_friend_request",
                     {"p_id": rows[0]["id"], "p_accept": True}, f"{other['label']} accepts")

        h.section("Creating a group")
        status, gid = h.rpc(o["token"], "create_group",
                            {"p_name": "E2E Painters", "p_rules": "be kind", "p_max_members": 4})
        h.check("O creates a group", status == 200 and isinstance(gid, str), f"{status} {gid}")
        h.rpc_refused(o["token"], "create_group", {"p_name": "  ", "p_rules": "", "p_max_members": 4},
                      "bad_name", "a group needs a name")
        status, rows = h.select(o["token"], "group_members", "select=user_id,role")
        h.check("O is the only member and the owner",
                status == 200 and [(r["user_id"], r["role"]) for r in rows] == [(o["id"], "owner")], str(rows))
        status, canvas_id = h.rpc(o["token"], "get_group_canvas", {"p_group": gid})
        h.check("the new group has a canvas", status == 200 and isinstance(canvas_id, str), str(canvas_id))

        h.section("Outsiders see nothing")
        status, rows = h.select(x["token"], "groups", "select=id")
        h.check("X cannot see the group", status == 200 and rows == [], f"{status} {rows}")
        status, rows = h.select(x["token"], "group_members", "select=user_id")
        h.check("X cannot see the member list", status == 200 and rows == [], f"{rows}")
        h.rpc_refused(x["token"], "get_group_canvas", {"p_group": gid}, "not_found",
                      "X cannot find the group's canvas")
        h.rpc_refused(x["token"], "send_group_message", {"p_group": gid, "p_body": "hi"},
                      "not_member", "X cannot write in the chat")

        h.section("Inviting")
        h.rpc_refused(o["token"], "invite_to_group", {"p_group": gid, "p_user": x["id"]}, "not_found",
                      "O cannot invite someone who is not a friend")
        h.rpc_ok(o["token"], "invite_to_group", {"p_group": gid, "p_user": f["id"]}, "O invites F")
        status, rows = h.select(f["token"], "groups", "select=id,name")
        h.check("an invited person can read the group's name (migration 004)",
                status == 200 and [r["name"] for r in rows] == ["E2E Painters"], f"{status} {rows}")
        status, rows = h.select(f["token"], "group_members", "select=user_id")
        h.check("but not the member list until they join", status == 200 and rows == [], f"{rows}")
        h.rpc_refused(o["token"], "invite_to_group", {"p_group": gid, "p_user": f["id"]},
                      "already_invited", "the same person cannot be invited twice")
        status, invites = h.select(f["token"], "group_invites", "select=id&status=eq.pending")
        h.rpc_ok(f["token"], "respond_group_invite", {"p_id": invites[0]["id"], "p_accept": True},
                 "F accepts")
        h.rpc_ok(o["token"], "invite_to_group", {"p_group": gid, "p_user": s["id"]}, "O invites S")
        status, invites = h.select(s["token"], "group_invites", "select=id&status=eq.pending")
        h.rpc_ok(s["token"], "respond_group_invite", {"p_id": invites[0]["id"], "p_accept": True},
                 "S accepts")
        status, rows = h.select(f["token"], "group_members", "select=user_id")
        h.check("members see all 3 members", status == 200 and len(rows) == 3, f"{rows}")
        status, rows = h.select(x["token"], "groups", "select=id")
        h.check("X still sees nothing", rows == [], f"{rows}")

        h.section("Only the owner controls the group")
        h.rpc_refused(f["token"], "update_group",
                      {"p_group": gid, "p_name": "Mine", "p_rules": "", "p_max_members": 4},
                      "not_owner", "a member cannot edit the group")
        h.rpc_refused(f["token"], "invite_to_group", {"p_group": gid, "p_user": x["id"]},
                      "not_owner", "a member cannot invite")
        h.rpc_refused(f["token"], "kick_member", {"p_group": gid, "p_user": s["id"]},
                      "not_owner", "a member cannot kick")
        h.rpc_refused(f["token"], "new_canvas", {"p_group": gid, "p_size": 16, "p_palette": "eightbit"},
                      "not_owner", "a member cannot start a new canvas")
        h.rpc_refused(f["token"], "dissolve_group", {"p_group": gid}, "not_owner",
                      "a member cannot dissolve the group")
        status, _ = h.http("POST", "/rest/v1/group_members", token=f["token"],
                           body={"group_id": gid, "user_id": x["id"]})
        h.check("clients cannot write members directly", status in (401, 403), str(status))
        h.rpc_ok(o["token"], "update_group",
                 {"p_group": gid, "p_name": "E2E Painters", "p_rules": "be kind", "p_max_members": 5},
                 "the owner can edit the group")

        h.section("Family friendly")
        h.rpc_refused(o["token"], "create_group", {"p_name": "Fuck Team", "p_rules": "", "p_max_members": 4},
                      "blocked_word", "a rude group name is refused")
        h.rpc_refused(o["token"], "create_group", {"p_name": "Nice", "p_rules": "dit me tat ca", "p_max_members": 4},
                      "blocked_word", "so are rude rules (even without accents)")
        h.rpc_refused(o["token"], "update_group",
                      {"p_group": gid, "p_name": "Big bitch club", "p_rules": "", "p_max_members": 5},
                      "blocked_word", "renaming a group to something rude is refused")
        h.rpc_ok(o["token"], "update_group",
                 {"p_group": gid, "p_name": "E2E Painters", "p_rules": "Class pass, du lich ok", "p_max_members": 5},
                 "ordinary words that contain a rude word's letters pass ('class', 'du lich')")

        h.section("Chat")
        h.rpc_ok(f["token"], "send_group_message", {"p_group": gid, "p_body": "hello team"},
                 "F writes to the group")
        status, rows = h.select(s["token"], "group_messages", "select=body,kind&kind=eq.text")
        h.check("S reads it", status == 200 and [r["body"] for r in rows] == ["hello team"], f"{rows}")
        status, rows = h.select(x["token"], "group_messages", "select=body")
        h.check("X does not", rows == [], f"{rows}")
        h.rpc_refused(f["token"], "send_group_message", {"p_group": gid, "p_body": "x" * 501},
                      "too_long", "messages are at most 500 characters")
        h.rpc_refused(f["token"], "send_group_message", {"p_group": gid, "p_body": "   "},
                      "empty", "an empty message is refused")
        h.rpc_refused(f["token"], "send_group_message", {"p_group": gid, "p_body": "you are a bitch"},
                      "blocked_word", "a rude message is refused")
        h.rpc_refused(f["token"], "send_group_message", {"p_group": gid, "p_body": "Địt mẹ"},
                      "blocked_word", "also in Vietnamese")
        h.rpc_ok(f["token"], "send_group_message", {"p_group": gid, "p_body": "Buổi sáng, đi du lịch nhé!"},
                 "a friendly message with ordinary Vietnamese passes")

        h.section("Same group is not friends")
        post_id = h._uuid()
        h.rpc_ok(f["token"], "create_post",
                 {"p_id": post_id, "p_kind": "photo", "p_media_path": f"{f['id']}/e2e.jpg",
                  "p_thumb_path": None, "p_caption": "private", "p_style": None, "p_quest_id": None,
                  "p_overlay": None, "p_recipients": None}, "F posts a photo to their friends")
        status, rows = h.select(o["token"], "posts", "select=id")
        h.check("O (F's friend) sees the post", status == 200 and len(rows) == 1, f"{rows}")
        status, rows = h.select(s["token"], "posts", "select=id")
        h.check("S (same group, not a friend) does not", status == 200 and rows == [], f"{rows}")
        status, rows = h.select(s["token"], "post_recipients", "select=post_id")
        h.check("S cannot see recipient rows either", rows == [], f"{rows}")
        h.rpc_refused(s["token"], "send_message", {"p_to": f["id"], "p_body": "hey"}, "not_found",
                      "S cannot message F directly")
        status, rows = h.select(s["token"], "profiles", f"select=id,username&id=eq.{f['id']}")
        h.check("S can still see F's public card", status == 200 and len(rows) == 1, f"{rows}")
        status, rows = h.select(s["token"], "player_state", f"select=user_id&user_id=eq.{f['id']}")
        h.check("S cannot see F's quest state", rows == [], f"{rows}")
        status, payload = h.rpc(s["token"], "send_friend_request", {"p_username": f["username"]})
        h.check("S can send F a friend request from the group", status == 200 and payload == "sent",
                f"{status} {payload}")

        h.section("Ink")
        h.rpc_refused(s["token"], "paint_pixels",
                      {"p_canvas": canvas_id, "p_batch": h._uuid(), "p_pixels": [{"x": 0, "y": 0, "c": 1}]},
                      "insufficient_ink", "S has no Ink yet, so cannot paint")
        for u in (o, f, s):
            paid = run_quest(u)
            h.check(f"{u['label']} completes the daily quest and gets 10 Ink", paid == 10, f"ink={paid}")
            status, balance = h.rpc(u["token"], "get_ink_balance")
            h.check(f"{u['label']}'s wallet shows 10", status == 200 and balance == 10, f"{balance}")
        status, payload = h.rpc(o["token"], "complete_quest", {"p_day": 0, "p_quest_id": "vg_grapes"})
        status, balance = h.rpc(o["token"], "get_ink_balance")
        h.check("a second quest the same day pays nothing more", balance == 10, f"{balance}")
        status, state = h.rpc(o["token"], "get_player_state")
        h.check("get_player_state carries ink_balance", state.get("ink_balance") == 10, str(state.get("ink_balance")))
        status, rows = h.select(o["token"], "ink_ledger", "select=amount,reason")
        h.check("the Ink ledger records the quest", status == 200 and len(rows) == 1 and rows[0]["amount"] == 10,
                f"{rows}")
        status, _ = h.http("PATCH", f"/rest/v1/ink_wallets?user_id=eq.{o['id']}", token=o["token"],
                           body={"balance": 999}, headers={"Prefer": "return=minimal"})
        h.check("nobody can edit their own wallet", status in (401, 403), str(status))

        h.section("Canvas")
        status, canvas = h.rpc(o["token"], "get_canvas", {"p_canvas": canvas_id})
        h.check("O reads the canvas",
                status == 200 and canvas["width"] == 32 and len(pixels_of(canvas)) == 1024
                and len(canvas["palette"]) == 16 and canvas["ink_balance"] == 10, str(canvas)[:200])
        h.rpc_refused(x["token"], "get_canvas", {"p_canvas": canvas_id}, "not_found",
                      "X cannot read the canvas")
        h.rpc_refused(x["token"], "paint_pixels",
                      {"p_canvas": canvas_id, "p_batch": h._uuid(), "p_pixels": [{"x": 0, "y": 0, "c": 1}]},
                      "not_found", "X cannot paint")

        batch = h._uuid()
        three = [{"x": 0, "y": 0, "c": 5}, {"x": 1, "y": 0, "c": 6}, {"x": 2, "y": 0, "c": 7}]
        status, result = h.rpc(o["token"], "paint_pixels",
                               {"p_canvas": canvas_id, "p_batch": batch, "p_pixels": three})
        h.check("O paints 3 pixels for 3 Ink",
                status == 200 and result["painted"] == 3 and result["ink_balance"] == 7, f"{status} {result}")
        status, again = h.rpc(o["token"], "paint_pixels",
                              {"p_canvas": canvas_id, "p_batch": batch, "p_pixels": three})
        h.check("sending the same batch again does not charge twice",
                status == 200 and again["repeat"] is True and again["ink_balance"] == 7, f"{again}")
        status, same = h.rpc(o["token"], "paint_pixels",
                             {"p_canvas": canvas_id, "p_batch": h._uuid(), "p_pixels": [three[0]]})
        h.check("painting the colour already there costs nothing",
                status == 200 and same["painted"] == 0 and same["ink_balance"] == 7, f"{same}")
        for label, pixels, code in [
            ("a pixel outside the canvas", [{"x": 32, "y": 0, "c": 1}], "bad_pixel"),
            ("a colour outside the palette", [{"x": 0, "y": 1, "c": 16}], "bad_pixel"),
            ("a negative coordinate", [{"x": -1, "y": 0, "c": 1}], "bad_pixel"),
            ("11 pixels in one batch", [{"x": i, "y": 3, "c": 1} for i in range(11)], "too_many_pixels"),
            ("an empty batch", [], "bad_pixel"),
        ]:
            h.rpc_refused(o["token"], "paint_pixels",
                          {"p_canvas": canvas_id, "p_batch": h._uuid(), "p_pixels": pixels}, code,
                          f"{label} is refused")
        status, balance = h.rpc(o["token"], "get_ink_balance")
        h.check("refused batches cost nothing", balance == 7, f"{balance}")
        status, _ = h.http("PATCH", f"/rest/v1/canvases?id=eq.{canvas_id}", token=o["token"],
                           body={"version": 0}, headers={"Prefer": "return=minimal"})
        h.check("nobody can write the canvas directly", status in (401, 403), str(status))

        h.section("Two people, one cell")
        results = {}

        def paint(user, color):
            results[user["label"]] = h.rpc(
                user["token"], "paint_pixels",
                {"p_canvas": canvas_id, "p_batch": h._uuid(), "p_pixels": [{"x": 5, "y": 5, "c": color}]})

        threads = [threading.Thread(target=paint, args=(f, 2)), threading.Thread(target=paint, args=(s, 3))]
        for t in threads:
            t.start()
        for t in threads:
            t.join()
        h.check("both painters are accepted and both pay",
                all(r[0] == 200 and r[1]["painted"] == 1 and r[1]["ink_balance"] == 9 for r in results.values()),
                str(results))
        status, events = h.rpc(o["token"], "get_canvas_events", {"p_canvas": canvas_id, "p_since_version": 0})
        versions = [e["version"] for e in events]
        h.check("every change has its own consecutive version",
                status == 200 and versions == list(range(1, len(versions) + 1)) and len(versions) == 5,
                f"{versions}")
        last = [e for e in events if (e["x"], e["y"]) == (5, 5)][-1]
        status, canvas = h.rpc(o["token"], "get_canvas", {"p_canvas": canvas_id})
        h.check("the cell shows the colour of the later paint",
                pixels_of(canvas)[5 * 32 + 5] == last["color"], f"{pixels_of(canvas)[5 * 32 + 5]} vs {last}")
        status, tail = h.rpc(o["token"], "get_canvas_events", {"p_canvas": canvas_id, "p_since_version": 3})
        h.check("events can be fetched from a version on", status == 200 and [e["version"] for e in tail] == [4, 5],
                f"{tail}")

        h.section("Owner clean-up tools")
        loser = f if last["user_id"] == s["id"] else s
        winner = s if loser is f else f
        h.rpc_refused(f["token"], "rollback_user_events",
                      {"p_canvas": canvas_id, "p_user": winner["id"], "p_since": "2020-01-01T00:00:00Z"},
                      "not_owner", "a member cannot roll anyone back")
        status, restored = h.rpc(o["token"], "rollback_user_events",
                                 {"p_canvas": canvas_id, "p_user": loser["id"],
                                  "p_since": "2020-01-01T00:00:00Z"})
        h.check("rolling back someone whose pixel was painted over restores nothing",
                status == 200 and restored == 0, f"{restored}")
        status, restored = h.rpc(o["token"], "rollback_user_events",
                                 {"p_canvas": canvas_id, "p_user": winner["id"],
                                  "p_since": "2020-01-01T00:00:00Z"})
        h.check("rolling back the latest painter restores their pixel", status == 200 and restored == 1,
                f"{status} {restored}")
        status, canvas = h.rpc(o["token"], "get_canvas", {"p_canvas": canvas_id})
        h.check("the cell goes back to what the other painter painted",
                pixels_of(canvas)[5 * 32 + 5] == (2 if loser is f else 3), f"{pixels_of(canvas)[5 * 32 + 5]}")
        status, balance = h.rpc(f["token"], "get_ink_balance")
        h.check("a rollback does not refund Ink", balance == 9, f"{balance}")

        status, new_id = h.rpc(o["token"], "new_canvas",
                               {"p_group": gid, "p_size": 16, "p_palette": "vangogh"})
        h.check("the owner starts a new 16x16 canvas", status == 200 and isinstance(new_id, str), str(new_id))
        h.rpc_refused(o["token"], "paint_pixels",
                      {"p_canvas": canvas_id, "p_batch": h._uuid(), "p_pixels": [{"x": 9, "y": 9, "c": 1}]},
                      "canvas_locked", "the old canvas is archived and cannot be painted")
        status, fresh = h.rpc(o["token"], "get_canvas", {"p_canvas": new_id})
        h.check("the new canvas is empty and 16x16",
                status == 200 and fresh["width"] == 16 and set(pixels_of(fresh)) == {0}, str(fresh)[:120])
        status, active = h.rpc(o["token"], "get_group_canvas", {"p_group": gid})
        h.check("the group's active canvas is the new one", active == new_id, f"{active}")

        h.section("Blocking inside a group")
        h.rpc_ok(s["token"], "block_user", {"p_user": f["id"]}, "S blocks F")
        status, rows = h.select(s["token"], "group_messages", "select=body&kind=eq.text")
        h.check("S no longer sees F's messages", status == 200 and rows == [], f"{rows}")
        status, rows = h.select(o["token"], "group_messages", "select=body&kind=eq.text")
        h.check("O still does", len(rows) == 2, f"{rows}")
        h.rpc_ok(s["token"], "unblock_user", {"p_user": f["id"]}, "S unblocks F")

        h.section("Leaving, handing over and closing")
        h.rpc_refused(o["token"], "leave_group", {"p_group": gid}, "owner_must_transfer",
                      "the owner cannot leave without handing over")
        h.rpc_refused(o["token"], "transfer_ownership", {"p_group": gid, "p_user": x["id"]},
                      "not_member", "ownership can only go to a member")
        h.rpc_ok(o["token"], "transfer_ownership", {"p_group": gid, "p_user": f["id"]}, "O hands over to F")
        status, rows = h.select(o["token"], "group_members", "select=user_id,role&role=eq.owner")
        h.check("F is the only owner", status == 200 and [r["user_id"] for r in rows] == [f["id"]], f"{rows}")
        h.rpc_refused(o["token"], "kick_member", {"p_group": gid, "p_user": s["id"]}, "not_owner",
                      "the old owner cannot kick any more")
        h.rpc_ok(o["token"], "leave_group", {"p_group": gid}, "O leaves")
        status, rows = h.select(o["token"], "groups", "select=id")
        h.check("O no longer sees the group", status == 200 and rows == [], f"{rows}")
        status, rows = h.select(o["token"], "group_messages", "select=body")
        h.check("O can no longer read the chat", rows == [], f"{rows}")
        h.rpc_refused(o["token"], "get_canvas", {"p_canvas": new_id}, "not_found",
                      "O can no longer read the canvas")
        h.rpc_ok(f["token"], "kick_member", {"p_group": gid, "p_user": s["id"]}, "F kicks S")
        status, rows = h.select(s["token"], "groups", "select=id")
        h.check("S no longer sees the group", rows == [], f"{rows}")
        h.rpc_ok(f["token"], "dissolve_group", {"p_group": gid}, "F dissolves the group")
        status, rows = h.select(f["token"], "groups", "select=id")
        h.check("a dissolved group disappears", rows == [], f"{rows}")
    finally:
        h.section("Cleanup")
        for user in users:
            status, payload = h.rpc(user["token"], "delete_my_account")
            h.check(f"{user['label']} deleted their account", status in (200, 204),
                    f"-> {status} {h.error_text(payload)}")

    print(f"\n{h.passed} checks passed, {len(h.failed)} failed")
    for name in h.failed:
        print(f"  - {name}")
    return 1 if h.failed else 0


if __name__ == "__main__":
    sys.exit(main())
