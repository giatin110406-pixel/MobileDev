import io
import time

import pytest
from fastapi.testclient import TestClient
from PIL import Image

from locket_server import jobs
from locket_server.api import create_app

TOKEN = "test-token"
HEADERS = {"X-Locket-Token": TOKEN}


def png_bytes(color=(10, 20, 30), size=(16, 16)) -> bytes:
    buffer = io.BytesIO()
    Image.new("RGB", size, color).save(buffer, format="PNG")
    return buffer.getvalue()


def fake_runner(style, data, params, stage_cb):
    stage_cb("painting", 0.5)
    return Image.new("RGB", (8, 8), (200, 100, 50))


@pytest.fixture
def client():
    with TestClient(create_app(runner=fake_runner, token=TOKEN)) as c:
        yield c


def submit(client, style="van_gogh", data=None):
    return client.post("/v1/jobs", headers=HEADERS, data={"style": style},
                       files={"image": ("a.png", data or png_bytes(), "image/png")})


def wait_done(client, job_id):
    for _ in range(100):
        body = client.get(f"/v1/jobs/{job_id}", headers=HEADERS).json()
        if body["state"] in ("done", "failed"):
            return body
        time.sleep(0.02)
    raise AssertionError("job did not finish")


def test_health_needs_no_token(client):
    body = client.get("/v1/health").json()
    assert body["ok"] is True and "van_gogh" in body["styles"]


def test_wrong_token_rejected(client):
    r = client.post("/v1/jobs", headers={"X-Locket-Token": "nope"}, data={"style": "van_gogh"},
                    files={"image": ("a.png", png_bytes(), "image/png")})
    assert r.status_code == 401
    assert client.get("/v1/jobs/x").status_code == 401


def test_result_can_be_refetched_until_deleted(client):
    job_id = submit(client).json()["job_id"]
    assert wait_done(client, job_id)["state"] == "done"
    for _ in range(2):          # a dropped download must be retryable
        r = client.get(f"/v1/jobs/{job_id}/result", headers=HEADERS)
        assert r.status_code == 200 and r.headers["content-type"] == "image/png"
        assert Image.open(io.BytesIO(r.content)).size == (8, 8)
    assert client.delete(f"/v1/jobs/{job_id}", headers=HEADERS).status_code == 204
    assert client.get(f"/v1/jobs/{job_id}", headers=HEADERS).status_code == 404
    assert client.delete(f"/v1/jobs/{job_id}").status_code == 401


def test_rejects_unknown_style_and_non_image(client):
    assert submit(client, style="oil_paint").status_code == 400
    assert submit(client, style="pixel_art").status_code == 400  # removed: 8-bit is on-device
    assert submit(client, data=b"not an image").status_code == 400


def test_failed_job_reports_error():
    def boom(*_):
        raise RuntimeError("gpu on fire")

    with TestClient(create_app(runner=boom, token=TOKEN)) as c:
        job_id = submit(c).json()["job_id"]
        body = wait_done(c, job_id)
        assert body["state"] == "failed" and "gpu on fire" in body["error"]
        assert c.get(f"/v1/jobs/{job_id}/result", headers=HEADERS).status_code == 500


def test_queue_full_returns_429():
    release = []

    def slow(*_):
        while not release:
            time.sleep(0.01)
        return Image.new("RGB", (4, 4))

    with TestClient(create_app(runner=slow, token=TOKEN)) as c:
        codes = [submit(c).status_code for _ in range(jobs.MAX_QUEUED + 1)]
        release.append(True)
        assert codes[:jobs.MAX_QUEUED] == [202] * jobs.MAX_QUEUED
        assert codes[-1] == 429


def test_jobs_expire(monkeypatch):
    monkeypatch.setattr(jobs, "JOB_TTL_SECONDS", 0)
    with TestClient(create_app(runner=fake_runner, token=TOKEN)) as c:
        job_id = submit(c).json()["job_id"]
        time.sleep(0.05)
        assert c.get(f"/v1/jobs/{job_id}", headers=HEADERS).status_code == 404


def test_verify_passes_labels_to_verifier():
    from locket_server.verify import VerifyResult

    calls = []

    def fake_verifier(data, positives, negatives):
        calls.append((positives, negatives))
        return VerifyResult(match=True, score=0.91, top=positives[0])

    with TestClient(create_app(runner=fake_runner, token=TOKEN, verifier=fake_verifier)) as c:
        r = c.post("/v1/verify", headers=HEADERS,
                   data={"positives": '["a bunch of grapes", "grapes"]', "negatives": '["blueberries"]'},
                   files={"image": ("a.png", png_bytes(), "image/png")})
        assert r.status_code == 200
        assert r.json() == {"match": True, "score": 0.91, "top": "a bunch of grapes"}
        assert calls == [(["a bunch of grapes", "grapes"], ["blueberries"])]


def test_verify_rejects_bad_input():
    def never(*_):
        raise AssertionError("verifier must not run")

    with TestClient(create_app(runner=fake_runner, token=TOKEN, verifier=never)) as c:
        def post(positives, data=None, headers=HEADERS):
            return c.post("/v1/verify", headers=headers, data={"positives": positives},
                          files={"image": ("a.png", data or png_bytes(), "image/png")})

        assert post('["grapes"]', headers={"X-Locket-Token": "nope"}).status_code == 401
        assert post("grapes").status_code == 400            # not JSON
        assert post("[]").status_code == 400                # no positives
        assert post('[""]').status_code == 400
        assert post('["grapes"]', data=b"not an image").status_code == 400


def test_verify_decision_rules():
    from locket_server.verify import build_labels, decide

    labels = build_labels(["a dog", "a puppy"], ["a wolf", "A DOG"])
    assert labels[:3] == ["a dog", "a puppy", "a wolf"]
    assert labels.count("a dog") == 1 and "A DOG" not in labels
    # Top label is a positive -> match.
    assert decide([0.4, 0.1, 0.5 - 0.2, 0.2], ["a dog", "a puppy", "a wolf", "a cat"], 2).match
    # Positives share the win -> match once they add up.
    assert decide([0.3, 0.25, 0.45], ["a dog", "a puppy", "a wolf"], 2).match
    # A distractor clearly wins -> no match, and we report what it looked like.
    result = decide([0.1, 0.05, 0.85], ["a dog", "a puppy", "a wolf"], 2)
    assert not result.match and result.top == "a wolf"
