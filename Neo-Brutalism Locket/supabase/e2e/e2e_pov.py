"""End-to-end check of Omni POV by QR code (a friend watches my camera), from the outside.

Creates four throw-away accounts in the project named in env/dev.json:

    A       opens a code (the person being photographed, who then watches)
    B       scans it (A's friend, the one taking the photos)
    D       another friend of B's
    C       a stranger to both

and drives the codes, the scan, the end and the `pov-ice` function through the same
calls the app makes. The clock is moved with SQL run through the Supabase CLI
(`supabase db query --linked`), like in e2e_contest.py.

    python supabase/e2e/e2e_pov.py

Needs "Confirm email" turned off (like e2e_check.py) and the CLI logged in and linked.
Deletes the accounts at the end (their sessions go with them).

The picture between the phones (WebRTC) and the private channel are not checked here:
they need two phones (see omni-pov-plan.md, step 0).
"""
from __future__ import annotations

import sys

import e2e_check as h
from e2e_contest import make_friends, sql


def ice(token):
    """Calls the pov-ice Edge Function like the app does."""
    return h.http("POST", "/functions/v1/pov-ice", token=token, body={})


def sessions(user):
    status, rows = h.select(user["token"], "pov_sessions",
                            "select=id,status,shots,viewer_id,host_id,code&order=created_at.desc")
    return rows if status == 200 else []


def open_code(user):
    status, payload = h.rpc(user["token"], "create_pov_code")
    ok = status == 200 and isinstance(payload, dict) and "code" in payload
    return ok, payload


def main() -> int:
    users: list[dict] = []
    try:
        h.section("Accounts and friends")
        accounts = {n: h.signup(n) for n in ("a", "b", "c", "d")}
        users += list(accounts.values())
        a, b, c, d = (accounts[n] for n in ("a", "b", "c", "d"))
        for u in users:
            h.http("PATCH", f"/rest/v1/profiles?id=eq.{u['id']}", token=u["token"],
                   body={"username": u["username"], "display_name": f"E2E {u['label']}"},
                   headers={"Prefer": "return=minimal"})
        make_friends(a, b)
        make_friends(d, b)
        h.check("A and B, D and B are friends", True)

        h.section("Opening a code")
        ok, first = open_code(a)
        h.check("A opens a code", ok, str(first))
        code = first["code"] if ok else ""
        h.check("it is long and random", len(code) == 32 and code.isalnum(), code)
        rows = sessions(a)
        h.check("A sees it waiting, with nobody as the photographer yet",
                len(rows) == 1 and rows[0]["status"] == "pending" and rows[0]["host_id"] is None,
                str(rows))
        h.check("nobody else sees it", sessions(b) == [] and sessions(c) == [])
        status, _ = h.http("POST", "/rest/v1/pov_sessions", token=a["token"],
                           body={"viewer_id": a["id"]})
        h.check("clients cannot write sessions directly", status in (401, 403), f"-> {status}")
        ok, second = open_code(a)
        h.check("opening it again gives a new code", ok and second["code"] != code, str(second))
        rows = sessions(a)
        h.check("the old code is closed and only one waits",
                [r["status"] for r in rows].count("pending") == 1
                and [r["status"] for r in rows].count("cancelled") == 1, str(rows))
        h.rpc_refused(b["token"], "join_pov", {"p_code": code}, "not_found",
                      "the old code no longer works")
        code = second["code"]

        h.section("The pov-ice function")
        status, payload = ice(a["token"])
        servers = payload.get("ice_servers") if isinstance(payload, dict) else None
        h.check("A, waiting, gets the ICE servers (STUN first)",
                status == 200 and bool(servers) and "stun:" in str(servers[0].get("urls")),
                f"-> {status} {payload}")
        status, payload = ice(c["token"])
        h.check("a stranger gets nothing", status == 403, f"-> {status} {payload}")
        status, payload = h.http("POST", "/functions/v1/pov-ice", body={})
        h.check("nobody signed in gets nothing", status in (401, 403), f"-> {status} {payload}")

        h.section("Scanning")
        h.rpc_refused(c["token"], "peek_pov_code", {"p_code": code}, "not_friends",
                      "a stranger scanning learns nothing")
        h.rpc_refused(c["token"], "join_pov", {"p_code": code}, "not_friends",
                      "and cannot join")
        h.rpc_refused(a["token"], "join_pov", {"p_code": code}, "self",
                      "A cannot scan their own code")
        h.rpc_refused(b["token"], "peek_pov_code", {"p_code": "nonsense"}, "not_found",
                      "a code that does not exist is not found")
        status, who = h.rpc(b["token"], "peek_pov_code", {"p_code": code})
        h.check("B is told whose code it is before joining",
                status == 200 and who.get("display_name") == "E2E A"
                and who.get("viewer_id") == a["id"], f"-> {status} {who}")
        h.check("looking joins nothing", sessions(a)[0]["status"] == "pending")
        status, joined = h.rpc(b["token"], "join_pov", {"p_code": code})
        h.check("B scans and confirms", status == 200 and joined.get("viewer_id") == a["id"],
                f"-> {status} {joined}")
        session = joined["session_id"] if isinstance(joined, dict) else ""
        rows = sessions(a)
        h.check("A sees it accepted, with B as the photographer",
                rows[0]["status"] == "accepted" and rows[0]["host_id"] == b["id"], str(rows))
        h.check("the code is gone once it is used", rows[0]["code"] is None, str(rows))
        h.rpc_refused(d["token"], "join_pov", {"p_code": code}, "not_found",
                      "a code works once")
        h.rpc_refused(a["token"], "create_pov_code", None, "busy",
                      "A cannot open another code while in a session")

        status, payload = ice(b["token"])
        h.check("B gets the ICE servers too", status == 200, f"-> {status} {payload}")

        h.section("Taking photos")
        h.rpc_ok(b["token"], "pov_shot", {"p_session": session}, "B reports a photo")
        h.rpc_ok(b["token"], "pov_shot", {"p_session": session}, "and another")
        h.rpc_ok(a["token"], "pov_shot", {"p_session": session}, "A reporting one is ignored")
        h.check("A sees 2 photos (only B's count)", sessions(a)[0]["shots"] == 2,
                str(sessions(a)))

        h.section("The end")
        h.rpc_ok(a["token"], "end_pov", {"p_session": session}, "A ends it")
        h.check("it is ended", sessions(b)[0]["status"] == "ended")
        h.rpc_ok(b["token"], "end_pov", {"p_session": session}, "ending it again is harmless")
        status, payload = ice(a["token"])
        h.check("after the end there are no more credentials", status == 403,
                f"-> {status} {payload}")

        h.section("Time running out, and the 30 minutes")
        ok, third = open_code(a)
        h.check("A opens a code again after the first session", ok, str(third))
        sql(f"update public.pov_sessions set expires_at = now() - interval '1 second' "
            f"where id = '{third['session_id']}'")
        h.rpc_refused(b["token"], "peek_pov_code", {"p_code": third["code"]}, "expired",
                      "a code that ran out cannot be looked at")
        h.rpc_refused(b["token"], "join_pov", {"p_code": third["code"]}, "expired",
                      "or scanned")
        ok, fourth = open_code(a)
        h.check("an old code no longer blocks a new one", ok, str(fourth))
        h.rpc_ok(b["token"], "join_pov", {"p_code": fourth["code"]}, "B scans the new one")
        sql(f"update public.pov_sessions set answered_at = now() - interval '31 minutes' "
            f"where id = '{fourth['session_id']}'")
        ok, fifth = open_code(a)
        h.check("a session that ran for 30 minutes is closed by the next code", ok, str(fifth))

        h.section("Friends and blocks")
        h.rpc_ok(b["token"], "join_pov", {"p_code": fifth["code"]}, "B scans")
        h.rpc_ok(a["token"], "end_pov", {"p_session": fifth["session_id"]}, "A ends it")
        ok, sixth = open_code(a)
        h.check("A opens a code", ok, str(sixth))
        h.rpc_ok(b["token"], "block_user", {"p_user": a["id"]}, "B blocks A")
        h.rpc_refused(b["token"], "join_pov", {"p_code": sixth["code"]}, "not_friends",
                      "B cannot scan the code of someone who blocked them or they blocked")

        h.section("The private channel")
        rows = sql("select policyname from pg_policies where schemaname = 'realtime' "
                   "and tablename = 'messages' and policyname like 'pov:%'")
        h.check("both policies of the channel are there", len(rows) == 2, str(rows))
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
