"""End-to-end check of photo-search vectors (20261022000001_post_embeddings.sql), from the
outside, like the app. Run it after that migration is applied to the project in env/dev.json:

    python supabase/e2e/e2e_search.py

Three throw-away accounts: A posts, B is A's friend, C is a stranger. Checks that a vector is
exactly as private as the photo, that only the author writes it, that bad vectors are refused,
and that a deleted post's vector disappears. The accounts are deleted at the end. Uses only the
publishable key, like e2e_check.py (needs "Confirm email" off).
"""
from __future__ import annotations

import base64
import sys
from pathlib import Path

sys.path.insert(0, str(Path(__file__).parent))
import e2e_check as e  # noqa: E402  (shared helpers: http, rpc, check, signup, ...)


def vec(byte: int) -> str:
    return base64.b64encode(bytes([byte]) * 1024).decode()


def main() -> int:
    users: list[dict] = []
    try:
        e.section("Accounts and friendship")
        a, b, c = e.signup("a"), e.signup("b"), e.signup("c")
        users += [a, b, c]
        for u in users:
            e.http("PATCH", f"/rest/v1/profiles?id=eq.{u['id']}", token=u["token"],
                   body={"username": u["username"]}, headers={"Prefer": "return=minimal"})
        e.rpc_ok(a["token"], "send_friend_request", {"p_username": b["username"]}, "A asks B")
        _, requests = e.select(b["token"], "friend_requests", "select=id")
        e.rpc_ok(b["token"], "respond_friend_request",
                 {"p_id": requests[0]["id"], "p_accept": True}, "B accepts")

        e.section("Writing vectors")
        p1, p2, p3 = e._uuid(), e._uuid(), e._uuid()
        base = {"p_kind": "photo", "p_thumb_path": None, "p_caption": "", "p_style": None,
                "p_quest_id": None, "p_overlay": None}
        e.rpc_ok(a["token"], "create_post",
                 {**base, "p_id": p1, "p_media_path": f"{a['id']}/{p1}.jpg", "p_embedding": vec(0x11)},
                 "A posts with a vector")
        e.rpc_ok(a["token"], "create_post",
                 {**base, "p_id": p2, "p_media_path": f"{a['id']}/{p2}.jpg"},
                 "A posts without one (older app)")
        e.rpc_refused(a["token"], "create_post",
                      {**base, "p_id": p3, "p_media_path": f"{a['id']}/{p3}.jpg",
                       "p_embedding": base64.b64encode(b"short").decode()},
                      "bad_embedding", "a vector of the wrong size is refused")
        e.rpc_refused(a["token"], "set_post_embedding", {"p_id": p2, "p_embedding": "not base64!!"},
                      "bad_embedding", "text that is not base64 is refused")
        e.rpc_ok(a["token"], "set_post_embedding", {"p_id": p2, "p_embedding": vec(0x22)},
                 "A fills in the older post (backfill)")
        e.rpc_refused(b["token"], "set_post_embedding", {"p_id": p1, "p_embedding": vec(0x33)},
                      "not_found", "a friend cannot change A's vector")
        e.rpc_refused(c["token"], "set_post_embedding", {"p_id": p1, "p_embedding": vec(0x33)},
                      "not_found", "a stranger cannot either")

        e.section("Reading vectors")
        status, rows = e.rpc(b["token"], "post_embeddings")
        got = {r["id"]: base64.b64decode(r["embedding"]) for r in rows} if status == 200 else {}
        e.check("B gets both vectors, as they were sent",
                got == {p1: bytes([0x11]) * 1024, p2: bytes([0x22]) * 1024}, f"{status} {rows}")
        first = next((r for r in rows if r["id"] == p1), None) if status == 200 else None
        if first:
            status, rows = e.rpc(b["token"], "post_embeddings",
                                 {"p_after": first["embedded_at"], "p_after_id": p1})
            e.check("paging returns only what came after the cursor",
                    status == 200 and [r["id"] for r in rows] == [p2], f"{status} {rows}")
        status, rows = e.rpc(c["token"], "post_embeddings")
        e.check("a stranger gets no vectors", status == 200 and rows == [], f"{status} {rows}")
        status, rows = e.rpc(c["token"], "visible_embedding_ids")
        e.check("not even the ids", status == 200 and rows == [], f"{status} {rows}")
        status, rows = e.select(c["token"], "posts", "select=id,embedding")
        e.check("nor through the posts table", status == 200 and rows == [], f"{status} {rows}")

        e.section("Deleting")
        e.rpc_ok(a["token"], "delete_post", {"p_post": p1}, "A deletes the first post")
        status, rows = e.rpc(b["token"], "visible_embedding_ids")
        e.check("its vector drops out for B", status == 200 and rows == [p2], f"{status} {rows}")
    finally:
        e.section("Cleanup")
        for user in users:
            status, payload = e.rpc(user["token"], "delete_my_account")
            e.check(f"{user['label']} deleted their account", status in (200, 204),
                    f"-> {status} {e.error_text(payload)}")

    print(f"\n{e.passed} checks passed, {len(e.failed)} failed")
    for name in e.failed:
        print(f"  - {name}")
    return 1 if e.failed else 0


if __name__ == "__main__":
    sys.exit(main())
