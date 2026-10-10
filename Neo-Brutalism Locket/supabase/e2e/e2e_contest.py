"""End-to-end check of the weekly contest and the Gallery, from the outside.

Creates seven throw-away accounts in the project named in env/dev.json:

    A1 A2   group A (A1 owns it)      B1 B2   group B (B1 owns it)
    C1 C2   group C (C1 owns it)      X       somebody outside every group

and two private test contests (named "E2E-..." and dated 2020, so they never
show up as the real current contest). The contests' clock is moved with SQL run
through the Supabase CLI (`supabase db query --linked`), the way the project
owner could do it; everything else goes through the same RPC calls the app makes.

    python supabase/e2e/e2e_contest.py

Needs "Confirm email" turned off (like e2e_check.py) and the CLI logged in and
linked. It deletes the test contests, the accounts and the temporary banned word at
the end. The test groups (named "E2E ...") are removed too, through the CLI.
"""
from __future__ import annotations

import json
import os
import secrets
import subprocess
import threading
import sys
import time

import e2e_check as h

ROOT = h.ROOT


def dump(name: str, payload) -> None:
    """With E2E_DUMP=<dir>, saves a real server answer so the Dart tests can read it."""
    folder = os.environ.get("E2E_DUMP")
    if not folder:
        return
    path = ROOT / folder
    path.mkdir(parents=True, exist_ok=True)
    (path / f"{name}.json").write_text(
        json.dumps(payload, ensure_ascii=False, indent=1), encoding="utf-8")


def sql(statement: str):
    """Runs SQL as the project owner through the CLI; returns the rows."""
    result = subprocess.run(
        ["npx.cmd", "supabase", "db", "query", "--linked", statement],
        capture_output=True, text=True, cwd=ROOT, encoding="utf-8",
    )
    out = result.stdout
    start = out.find("{")
    if result.returncode != 0 or start < 0:
        raise RuntimeError(f"SQL failed: {statement}\n{result.stderr}\n{out}")
    return json.loads(out[start:out.rfind("}") + 1]).get("rows", [])


def make_friends(a, b):
    h.rpc(a["token"], "send_friend_request", {"p_username": b["username"]})
    status, rows = h.select(b["token"], "friend_requests", "select=id&status=eq.pending")
    h.rpc(b["token"], "respond_friend_request", {"p_id": rows[0]["id"], "p_accept": True})


def make_group(owner, member, name):
    status, gid = h.rpc(owner["token"], "create_group",
                        {"p_name": name, "p_rules": "", "p_max_members": 4})
    assert status == 200, gid
    h.rpc(owner["token"], "invite_to_group", {"p_group": gid, "p_user": member["id"]})
    status, invites = h.select(member["token"], "group_invites", "select=id&status=eq.pending")
    h.rpc(member["token"], "respond_group_invite", {"p_id": invites[0]["id"], "p_accept": True})
    return gid


def new_contest(tag: str, max_entries: int, opens: str, closes: str, ends: str) -> str:
    rows = sql(
        "insert into public.contests (week_key, theme_id, starts_at, opens_at, submit_closes_at, "
        "ends_at, max_entries) select 'E2E-" + tag + "-" + secrets.token_hex(3) + "', id, "
        "'2020-01-01', " + opens + ", " + closes + ", " + ends + ", " + str(max_entries) +
        " from public.contest_themes order by ord limit 1 returning id")
    return rows[0]["id"]


def main() -> int:
    users: list[dict] = []
    contests: list[str] = []
    banned = "e2ebadword"
    try:
        h.section("Accounts, friends and three groups")
        names = ["a1", "a2", "b1", "b2", "c1", "c2", "x"]
        accounts = {n: h.signup(n) for n in names}
        users += list(accounts.values())
        a1, a2, b1, b2, c1, c2, x = (accounts[n] for n in names)
        for u in users:
            h.http("PATCH", f"/rest/v1/profiles?id=eq.{u['id']}", token=u["token"],
                   body={"username": u["username"], "display_name": f"E2E {u['label']}"},
                   headers={"Prefer": "return=minimal"})
        for owner, member in ((a1, a2), (b1, b2), (c1, c2)):
            make_friends(owner, member)
        ga = make_group(a1, a2, "E2E Team A")
        gb = make_group(b1, b2, "E2E Team B")
        gc = make_group(c1, c2, "E2E Team C")
        h.check("three groups of two exist", all(isinstance(g, str) for g in (ga, gb, gc)))
        # Test accounts are brand new; the rules want 7-day-old accounts to count ratings.
        sql("update auth.users set created_at = now() - interval '10 days' "
            "where email like 'e2e-%@example.com'")
        # Give each group a drawn canvas (the app would need 100+ Ink to do that).
        sql("update public.canvases set pixels = decode(repeat('01', width * height), 'hex') "
            f"where group_id in ('{ga}', '{gb}', '{gc}') and status = 'active'")

        h.section("The real contest is created by the tick")
        status, current = h.rpc(a1["token"], "get_current_contest")
        cur = current.get("contest") if status == 200 else None
        h.check("get_current_contest returns this week's contest",
                status == 200 and cur and cur["week_key"].startswith("2026-W"), str(current)[:200])
        h.check("it knows the theme and the Vietnam-time schedule",
                current["theme"]["title_en"] and cur["opens_at"] < cur["submit_closes_at"] < cur["ends_at"],
                str(current)[:300])
        h.check("A1 sees A's group as one they can submit",
                [g["id"] for g in current["owner_groups"]] == [ga], str(current["owner_groups"]))
        h.check("a participant flag is false before submitting", current["participant"] is False)
        dump("overview", current)

        h.section("Submitting (an open test contest that takes 3 entries)")
        c1id = new_contest("one", 3, "now() - interval '1 hour'", "now() + interval '1 hour'",
                           "now() + interval '2 hours'")
        contests.append(c1id)
        sub = lambda u, g, cid=None: h.rpc(u["token"], "submit_entry", {"p_group": g, "p_contest": cid})
        h.rpc_refused(a2["token"], "submit_entry", {"p_group": ga, "p_contest": c1id}, "not_owner",
                      "only the owner can submit")
        h.rpc_refused(x["token"], "submit_entry", {"p_group": ga, "p_contest": c1id}, "not_owner",
                      "an outsider cannot submit someone's group")
        h.rpc_refused(a2["token"], "vote_entry", {"p_entry": h._uuid(), "p_score": 3}, "not_found",
                      "rating an entry that does not exist is refused")
        status, first = sub(a1, ga, c1id)
        h.check("A1 submits group A and is number 1", status == 200 and first["seq"] == 1, f"{first}")
        h.rpc_refused(a1["token"], "submit_entry", {"p_group": ga, "p_contest": c1id},
                      "already_submitted", "a group enters once")
        entry_a = first["entry_id"]
        status, second = sub(b1, gb, c1id)
        h.check("B1 submits and is number 2", status == 200 and second["seq"] == 2, f"{second}")
        entry_b = second["entry_id"]
        h.rpc_refused(a1["token"], "vote_entry", {"p_entry": entry_b, "p_score": 4}, "not_judging",
                      "rating is not open while entries are still being accepted")
        status, third = sub(c1, gc, c1id)
        h.check("C1 submits and is number 3", status == 200 and third["seq"] == 3, f"{third}")
        entry_c = third["entry_id"]
        # A group of one outside, only to show the contest is full.
        status, gx = h.rpc(x["token"], "create_group", {"p_name": "E2E Solo", "p_rules": "", "p_max_members": 2})
        h.rpc_refused(x["token"], "submit_entry", {"p_group": gx, "p_contest": c1id}, "contest_full",
                      "the 4th entry is turned away because only 3 fit")
        status, rows = h.rpc(x["token"], "get_gallery", {"p_contest": c1id})
        h.check("the contest moved to judging as soon as it was full",
                status == 200 and rows["phase"] == "judging", str(rows)[:120])

        h.section("The gallery")
        status, page = h.rpc(x["token"], "get_gallery", {"p_contest": c1id})
        entries = page["entries"]
        h.check("anyone signed in can look: 3 entries in the order they were accepted",
                status == 200 and [e["seq"] for e in entries] == [1, 2, 3]
                and [e["group_name"] for e in entries] == ["E2E Team A", "E2E Team B", "E2E Team C"],
                str(page)[:200])
        h.check("each entry carries palette and pixels (no line breaks)",
                all(len(e["palette"]) == 16 and "\n" not in e["pixels"] and e["width"] == 32
                    for e in entries), str(entries[0])[:120])
        h.check("scores stay hidden until the results", all(e["rank"] is None and e["score"] is None
                                                            for e in entries))
        status, page = h.rpc(a1["token"], "get_gallery", {"p_contest": c1id})
        dump("gallery", page)
        h.check("A1's own entry is marked as theirs",
                [e["mine"] for e in page["entries"]] == [True, False, False])
        status, small = h.rpc(x["token"], "get_gallery", {"p_contest": c1id, "p_after": 1, "p_limit": 1})
        h.check("pages follow the order (after 1, limit 1 gives #2)",
                [e["seq"] for e in small["entries"]] == [2] and small["next_after"] == 2, str(small)[:160])
        # A later change to the canvas must not change what was entered.
        sql(f"update public.canvases set pixels = decode(repeat('02', width * height), 'hex') "
            f"where group_id = '{ga}' and status = 'active'")
        status, again = h.rpc(x["token"], "get_gallery", {"p_contest": c1id, "p_limit": 1})
        h.check("an entry is a snapshot: painting afterwards does not change it",
                again["entries"][0]["pixels"] == entries[0]["pixels"])

        h.section("Rating")
        h.rpc_refused(x["token"], "vote_entry", {"p_entry": entry_a, "p_score": 3}, "not_participant",
                      "somebody outside the entering groups cannot rate")
        h.rpc_refused(a1["token"], "vote_entry", {"p_entry": entry_a, "p_score": 5}, "own_entry",
                      "you cannot rate your own group's entry")
        h.rpc_refused(a2["token"], "vote_entry", {"p_entry": entry_a, "p_score": 5}, "own_entry",
                      "nor can your group-mate")
        h.rpc_refused(a1["token"], "vote_entry", {"p_entry": entry_b, "p_score": 6}, "bad_score",
                      "scores are 1 to 5")
        h.rpc_refused(a1["token"], "vote_entry", {"p_entry": entry_b, "p_score": 0}, "bad_score",
                      "0 is not a score")
        votes = [  # (voter, {entry: score}); chosen so the Bayesian result is known
            (a1, {entry_b: 5, entry_c: 3}), (a2, {entry_b: 4, entry_c: 2}),
            (b1, {entry_a: 5, entry_c: 4}), (b2, {entry_a: 4, entry_c: 3}),
            (c1, {entry_a: 3, entry_b: 2}), (c2, {entry_a: 4, entry_b: 3}),
        ]
        ok = True
        for voter, given in votes:
            for entry, score in given.items():
                status, payload = h.rpc(voter["token"], "vote_entry", {"p_entry": entry, "p_score": score})
                ok &= status in (200, 204)
        h.check("the six raters give 12 ratings", ok)
        h.rpc_ok(a1["token"], "vote_entry", {"p_entry": entry_b, "p_score": 1}, "a rating can be changed")
        h.rpc_ok(a1["token"], "vote_entry", {"p_entry": entry_b, "p_score": 5}, "and changed back")
        status, page = h.rpc(a1["token"], "get_gallery", {"p_contest": c1id})
        h.check("A1 sees their own scores (5 for B, 3 for C)",
                [e["my_score"] for e in page["entries"]] == [None, 5, 3], str([e["my_score"] for e in page["entries"]]))
        status, rows = h.select(a1["token"], "entry_votes", "select=score")
        h.check("ratings cannot be read directly", status in (401, 403) or rows == [], f"{status} {rows}")

        h.section("Comments, reactions and reports")
        h.rpc_refused(x["token"], "comment_entry", {"p_entry": entry_b, "p_body": "hi"}, "not_participant",
                      "an outsider cannot comment")
        h.rpc_refused(a1["token"], "comment_entry", {"p_entry": entry_b, "p_body": "   "}, "empty",
                      "an empty comment is refused")
        h.rpc_refused(a1["token"], "comment_entry", {"p_entry": entry_b, "p_body": "x" * 201}, "too_long",
                      "comments are at most 200 characters")
        status, comment_id = h.rpc(a1["token"], "comment_entry", {"p_entry": entry_b, "p_body": "Love the colours"})
        h.check("A1 comments on B", status == 200 and isinstance(comment_id, str), str(comment_id))
        h.rpc_refused(a1["token"], "comment_entry", {"p_entry": entry_c, "p_body": "again"}, "too_fast",
                      "a second comment right away is refused")
        sql(f"insert into public.contest_banned_words (word) values ('{banned}')")
        h.rpc_refused(a2["token"], "comment_entry", {"p_entry": entry_b, "p_body": f"this is {banned}!"},
                      "blocked_word", "a banned word is refused")
        h.rpc_ok(b1["token"], "react_entry", {"p_entry": entry_a, "p_emoji": "🔥"}, "B1 reacts to A")
        h.rpc_refused(x["token"], "react_entry", {"p_entry": entry_a, "p_emoji": "🔥"}, "not_participant",
                      "an outsider cannot react")
        status, detail = h.rpc(c1["token"], "get_entry", {"p_entry": entry_a})
        h.check("an entry shows reaction counts", detail["reactions"] == {"🔥": 1}, str(detail["reactions"]))
        status, detail = h.rpc(c1["token"], "get_entry", {"p_entry": entry_b})
        dump("entry", detail)
        h.check("and the number of comments", detail["comment_count"] == 1)
        status, comments = h.rpc(c1["token"], "get_entry_comments", {"p_entry": entry_b})
        dump("comments", comments)
        h.check("C1 reads A1's comment", status == 200 and [k["body"] for k in comments] == ["Love the colours"]
                and comments[0]["mine"] is False, str(comments))
        h.rpc_refused(a1["token"], "report_gallery",
                      {"p_entry": None, "p_comment": comment_id, "p_reason": "spam"}, "not_found",
                      "you cannot report your own comment")
        h.rpc_refused(b1["token"], "report_gallery",
                      {"p_entry": None, "p_comment": comment_id, "p_reason": "nonsense"}, "bad_reason",
                      "only known report reasons")
        for reporter in (b1, c1, c2):
            h.rpc_ok(reporter["token"], "report_gallery",
                     {"p_entry": None, "p_comment": comment_id, "p_reason": "spam", "p_details": "e2e"},
                     f"{reporter['label']} reports the comment")
        status, comments = h.rpc(a2["token"], "get_entry_comments", {"p_entry": entry_b})
        h.check("three different reporters hide the comment", status == 200 and comments == [], str(comments))
        h.rpc_ok(b2["token"], "report_gallery",
                 {"p_entry": entry_a, "p_comment": None, "p_reason": "other"}, "an entry can be reported")
        status, rows = h.select(b2["token"], "reports", "select=id")
        h.check("reports cannot be read back", status >= 400 or rows == [], f"{status} {rows}")

        h.section("Closing: the Bayesian result")
        sql(f"update public.contests set ends_at = now() - interval '1 minute', "
            f"submit_closes_at = now() - interval '30 minutes' where id = '{c1id}'")
        status, result = h.rpc(a1["token"], "get_contest_results", {"p_contest": c1id})
        winners = result["winners"]
        dump("results", result)
        h.check("the contest is finalized by the next request that touches it",
                status == 200 and result["phase"] == "finalized", str(result)[:160])
        h.check("the order is A, B, C", [w["seq"] for w in winners] == [1, 2, 3], str([w["seq"] for w in winners]))
        h.check("the scores are the Bayesian averages (3.7222, 3.5, 3.2778)",
                [round(float(w["score"]), 4) for w in winners] == [3.7222, 3.5, 3.2778],
                str([w["score"] for w in winners]))
        h.check("each has 4 counted ratings and a rank", [(w["rank"], w["vote_count"]) for w in winners]
                == [(1, 4), (2, 4), (3, 4)], str([(w["rank"], w["vote_count"]) for w in winners]))
        h.rpc_refused(a1["token"], "vote_entry", {"p_entry": entry_b, "p_score": 5}, "not_judging",
                      "no rating after the end")
        h.rpc_refused(a1["token"], "comment_entry", {"p_entry": entry_b, "p_body": "late"}, "not_judging",
                      "no comment after the end")

        h.section("Prizes (once)")
        want = {"A1": (150, 30), "A2": (150, 30), "B1": (100, 20), "B2": (100, 20),
                "C1": (50, 10), "C2": (50, 10), "X": (0, 0)}
        got = {}
        for u in (a1, a2, b1, b2, c1, c2, x):
            status, state = h.rpc(u["token"], "get_player_state")
            got[u["label"]] = (state["balance"], state["ink_balance"])
        h.check("every person of a winning group got Sunbit and Ink (150/100/50, 30/20/10)",
                got == want, str(got))
        h.rpc(x["token"], "get_current_contest")
        sql("select public.contest_tick()")
        status, state = h.rpc(a1["token"], "get_player_state")
        h.check("running the tick again pays nothing twice",
                (state["balance"], state["ink_balance"]) == (150, 30), str(state["balance"]))
        status, page = h.rpc(x["token"], "get_gallery", {"p_contest": c1id})
        h.check("the gallery now shows ranks and scores",
                [(e["rank"], float(e["score"])) for e in page["entries"]] ==
                [(1, 3.7222), (2, 3.5), (3, 3.2778)], str([(e["rank"], e["score"]) for e in page["entries"]]))
        status, hall = h.rpc(x["token"], "get_hall_of_fame", {"p_offset": 0, "p_limit": 30})
        dump("hall", hall)
        h.check("the Hall of Fame lists the three winners",
                status == 200 and {e["id"] for e in hall} >= {entry_a, entry_b, entry_c}, str(hall)[:120])

        h.section("The winning paintings go on sale")
        item_a, item_b, item_c = (f"contest_{e}" for e in (entry_a, entry_b, entry_c))
        status, shelf = h.rpc(x["token"], "get_contest_shop")
        dump("shop", shelf)
        mine = [s for s in shelf if s["id"] in (item_a, item_b, item_c)]
        h.check("the three winners are in the shop, best first, at 300 / 220 / 150 Sunbit",
                status == 200 and [(s["rank"], s["price"]) for s in mine] == [(1, 300), (2, 220), (3, 150)],
                str(mine))
        h.check("100 copies each, none sold, none owned by an outsider",
                all(s["stock"] == 100 and s["sold"] == 0 and s["owned"] is False for s in mine), str(mine))
        h.check("the theme and week are shown with the item",
                all(s["week_key"].startswith("E2E-") and s["title_en"] for s in mine))
        status, state_a2 = h.rpc(a2["token"], "get_player_state")
        h.check("every person of the winning group owns a copy for free",
                item_a in state_a2["owned"], str(state_a2["owned"]))
        status, state_b1 = h.rpc(b1["token"], "get_player_state")
        h.check("the group in second place owns theirs, not the first place's",
                item_b in state_b1["owned"] and item_a not in state_b1["owned"], str(state_b1["owned"]))
        status, art = h.rpc(x["token"], "get_banner_art", {"p_item": item_a})
        dump("banner_art", art)
        h.check("the banner's picture can be fetched by anyone",
                status == 200 and art["width"] == 32 and len(art["pixels"]) > 1000 and "\n" not in art["pixels"]
                and art["group_name"] == "E2E Team A", str(art)[:120])
        h.rpc_refused(x["token"], "get_banner_art", {"p_item": "banner_space"}, "not_found",
                      "an ordinary banner has no painting")
        h.rpc_refused(x["token"], "buy_item", {"p_item": item_a}, "insufficient_funds",
                      "without the Sunbit the purchase is refused")
        sql("update public.player_state set balance = 1000 where user_id in "
            f"('{x['id']}', '{b1['id']}', '{c1['id']}')")
        status, bought = h.rpc(x["token"], "buy_item", {"p_item": item_a})
        h.check("X buys first place for 300", status == 200 and bought["balance"] == 700
                and item_a in bought["owned"], str(bought)[:160])
        h.rpc_refused(x["token"], "buy_item", {"p_item": item_a}, "already_owned", "once only")
        h.rpc_refused(a1["token"], "buy_item", {"p_item": item_a}, "already_owned",
                      "the winners already own it")
        status, state = h.rpc(a1["token"], "get_player_state")
        status2, state2 = h.rpc(a2["token"], "get_player_state")
        h.check("20% of the sale (60) is shared by the winning group: 30 each",
                (state["balance"], state2["balance"]) == (180, 180), f"{state['balance']} {state2['balance']}")
        status, shelf = h.rpc(x["token"], "get_contest_shop")
        sold = {s["id"]: (s["sold"], s["owned"]) for s in shelf}
        h.check("one copy is counted as sold, and X sees it as theirs",
                sold[item_a] == (1, True) and sold[item_b] == (0, False), str(sold))
        h.rpc_ok(x["token"], "equip_item", {"p_item": item_a}, "X puts the painting on their profile")
        status, rows = h.select(x["token"], "profiles", f"select=banner_id&id=eq.{x['id']}")
        h.check("and the profile now points at it", rows == [{"banner_id": item_a}], str(rows))
        h.rpc_refused(x["token"], "buy_item", {"p_item": "contest_00000000-0000-0000-0000-000000000000"},
                      "not_found", "an unknown painting is not found")

        # One copy left, two buyers at the same moment: exactly one gets it.
        sql(f"update public.shop_items set stock = 2 where id = '{item_a}'")
        outcome = {}

        def buy(user):
            outcome[user["label"]] = h.rpc(user["token"], "buy_item", {"p_item": item_a})

        threads = [threading.Thread(target=buy, args=(b1,)), threading.Thread(target=buy, args=(c1,))]
        for t in threads:
            t.start()
        for t in threads:
            t.join()
        wins = [label for label, (status, _) in outcome.items() if status == 200]
        losses = [(label, h.error_text(payload)) for label, (status, payload) in outcome.items() if status != 200]
        h.check("two people buy the last copy at once: one gets it, the other hears it is sold out",
                len(wins) == 1 and len(losses) == 1 and losses[0][1] == "sold_out", str(outcome)[:300])
        status, shelf = h.rpc(x["token"], "get_contest_shop")
        h.check("and the count is exactly 2 of 2", {s["id"]: s["sold"] for s in shelf}[item_a] == 2)
        loser = b1 if losses and losses[0][0] == b1["label"] else c1
        status, state_loser = h.rpc(loser["token"], "get_player_state")
        h.check("whoever lost was not charged", state_loser["balance"] == 1000, str(state_loser["balance"]))
        # The group's total from three sales (300 + 300 + 300): 3 x 60 shared by 2 people.
        status, state = h.rpc(a1["token"], "get_player_state")
        h.check("the royalty comes with each sale (30 + 30 for one more sale)", state["balance"] == 210,
                str(state["balance"]))

        h.section("A smaller contest: two entries, too few ratings to rank")
        c2id = new_contest("two", 100, "now() - interval '1 hour'", "now() + interval '1 hour'",
                           "now() + interval '2 hours'")
        contests.append(c2id)
        status, e2a = sub(a1, ga, c2id)
        status, e2b = sub(b1, gb, c2id)
        h.check("the same groups can enter the next contest", e2a["seq"] == 1 and e2b["seq"] == 2)
        h.rpc_refused(c1["token"], "vote_entry", {"p_entry": e2a["entry_id"], "p_score": 3}, "not_participant",
                      "C is not in this contest, so it cannot rate here")
        sql(f"update public.contests set submit_closes_at = now() - interval '1 minute' where id = '{c2id}'")
        # Both entries get five 5s and a tie-break; C's people are not participants, so only
        # A and B rate each other's entry (2 raters each). One entry gets 2 ratings only.
        h.rpc_ok(b1["token"], "vote_entry", {"p_entry": e2a["entry_id"], "p_score": 5}, "B1 rates A")
        h.rpc_ok(b2["token"], "vote_entry", {"p_entry": e2a["entry_id"], "p_score": 5}, "B2 rates A")
        h.rpc_ok(a1["token"], "vote_entry", {"p_entry": e2b["entry_id"], "p_score": 5}, "A1 rates B")
        h.rpc_ok(a2["token"], "vote_entry", {"p_entry": e2b["entry_id"], "p_score": 5}, "A2 rates B")
        sql(f"update public.contests set ends_at = now() - interval '1 minute' where id = '{c2id}'")
        status, result = h.rpc(a1["token"], "get_contest_results", {"p_contest": c2id})
        h.check("with fewer than 3 ratings per entry nobody is ranked (no winners, no prizes)",
                status == 200 and result["phase"] == "finalized" and result["winners"] == [], str(result)[:200])
    finally:
        h.section("Cleanup")
        try:
            sql("delete from public.contests where week_key like 'E2E-%'")
            sql(f"delete from public.contest_banned_words where word = '{banned}'")
            h.check("test contests and the banned word removed", True)
        except RuntimeError as error:
            h.check("test contests and the banned word removed", False, str(error)[:200])
        for user in users:
            status, payload = h.rpc(user["token"], "delete_my_account")
            h.check(f"{user['label']} deleted their account", status in (200, 204),
                    f"-> {status} {h.error_text(payload)}")

    try:
        sql("delete from public.groups where name like 'E2E %'")
        # Deleting a contest leaves its shop items behind with no painting (nobody
        # owns them now that the accounts are gone), so remove those too.
        sql("delete from public.shop_items where id like 'contest_%' and source_entry_id is null")
        h.check("test groups and shop items removed", True)
    except RuntimeError as error:
        h.check("test groups and shop items removed", False, str(error)[:200])

    print(f"\n{h.passed} checks passed, {len(h.failed)} failed")
    for name in h.failed:
        print(f"  - {name}")
    return 1 if h.failed else 0


if __name__ == "__main__":
    sys.exit(main())
