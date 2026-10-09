from __future__ import annotations

import io
import json
import os
import secrets
import threading
from pathlib import Path

from fastapi import Depends, FastAPI, File, Form, Header, HTTPException, UploadFile
from fastapi.concurrency import run_in_threadpool
from fastapi.responses import Response
from PIL import Image

from . import config
from .jobs import JobManager, QueueFull, Runner
from .verify import Verifier, clip_verifier

VERSION = "0.1.0"
MAX_UPLOAD_BYTES = 15 * 1024 * 1024
SUPPORTED_STYLES = {"van_gogh"}
MAX_VERIFY_LABELS = 12
MAX_LABEL_CHARS = 80


def ensure_token() -> str:
    """Read the shared token from env/.env, creating one on first run."""
    token = os.environ.get("LOCKET_TOKEN")
    if token:
        return token
    token = secrets.token_urlsafe(24)
    env_file = config.SERVER_ROOT / ".env"
    with open(env_file, "a", encoding="utf-8") as handle:
        handle.write(f"\nLOCKET_TOKEN={token}\n")
    os.environ["LOCKET_TOKEN"] = token
    return token


def default_runner() -> Runner:
    """Real GPU runner. Models load lazily on first use (or warm-up)."""
    state: dict = {}
    lock = threading.Lock()

    def registry_and_cfg():
        with lock:
            if "registry" not in state:
                from .models import load_registry

                state["cfg"] = config.load_yaml("van_gogh.yaml")
                state["registry"] = load_registry(state["cfg"])
            return state["registry"], state["cfg"]

    def run(style, data, params, stage_cb):
        registry, cfg = registry_and_cfg()
        if style == "van_gogh":
            from .van_gogh import stylize_van_gogh

            return stylize_van_gogh(registry, cfg, data, seed=params.get("seed"), stage_cb=stage_cb)
        raise ValueError(f"style '{style}' is not available")

    def warmup() -> None:
        """Load every model (diffusion, lineart, depth, face detector, upscaler) with one
        throw-away job, so the first real photo does not pay 8-12 s of lazy loading."""
        import io

        from PIL import Image

        from .van_gogh import stylize_van_gogh

        registry, cfg = registry_and_cfg()
        buffer = io.BytesIO()
        Image.linear_gradient("L").resize((96, 96)).convert("RGB").save(buffer, format="PNG")
        stylize_van_gogh(registry, cfg, buffer.getvalue(), seed=0)

    run.warmup = warmup  # type: ignore[attr-defined]
    return run


def parse_labels(raw: str, name: str, required: bool) -> list[str]:
    try:
        labels = json.loads(raw)
    except ValueError:
        raise HTTPException(status_code=400, detail=f"{name} must be a JSON list") from None
    if (not isinstance(labels, list) or len(labels) > MAX_VERIFY_LABELS
            or not all(isinstance(label, str) and 0 < len(label.strip()) <= MAX_LABEL_CHARS
                       for label in labels)
            or (required and not labels)):
        raise HTTPException(status_code=400, detail=f"invalid {name}")
    return [label.strip() for label in labels]


def create_app(runner: Runner | None = None, token: str | None = None,
               verifier: Verifier | None = None) -> FastAPI:
    token = token or ensure_token()
    runner = runner or default_runner()
    verifier = verifier or clip_verifier()
    manager = JobManager(runner)
    app = FastAPI(title="Locket stylize server", version=VERSION)
    app.state.manager = manager
    app.state.verifier = verifier
    app.state.models_ready = False
    app.state.gpu_info = {}

    @app.on_event("startup")
    def warm_up() -> None:
        warmup = getattr(runner, "warmup", None)
        if warmup is None:
            app.state.models_ready = True
            return

        def load() -> None:
            try:
                warmup()
                app.state.models_ready = True
            except Exception as error:  # noqa: BLE001
                print("warm-up failed:", error, flush=True)

        threading.Thread(target=load, daemon=True, name="warmup").start()

    def require_token(x_locket_token: str | None = Header(default=None)) -> None:
        if x_locket_token is None or not secrets.compare_digest(x_locket_token, token):
            raise HTTPException(status_code=401, detail="invalid token")

    @app.get("/v1/health")
    def health() -> dict:
        info: dict = {"ok": True, "version": VERSION, "models_ready": app.state.models_ready,
                      "styles": sorted(SUPPORTED_STYLES), "verify": True, "gpu": None, "vram_free_mb": None}
        # Never touch CUDA while a job runs: it can stall and make the phone time out.
        if manager.busy:
            info.update(app.state.gpu_info)
            return info
        try:
            import torch

            if torch.cuda.is_available():
                app.state.gpu_info = {
                    "gpu": torch.cuda.get_device_name(0),
                    "vram_free_mb": int(torch.cuda.mem_get_info()[0] / 1024 / 1024),
                }
                info.update(app.state.gpu_info)
        except Exception:  # noqa: BLE001 - health must never fail
            pass
        return info

    @app.post("/v1/jobs", status_code=202, dependencies=[Depends(require_token)])
    async def create_job(
        image: UploadFile = File(...),
        style: str = Form(...),
        seed: int | None = Form(default=None),
    ) -> dict:
        if style not in SUPPORTED_STYLES:
            raise HTTPException(status_code=400, detail=f"unsupported style '{style}'")
        data = await image.read(MAX_UPLOAD_BYTES + 1)
        if len(data) > MAX_UPLOAD_BYTES:
            raise HTTPException(status_code=413, detail="image too large (max 15 MB)")
        try:
            Image.open(io.BytesIO(data)).verify()
        except Exception:  # noqa: BLE001
            raise HTTPException(status_code=400, detail="not a valid image") from None
        try:
            job_id = manager.submit(style, data, {"seed": seed})
        except QueueFull:
            raise HTTPException(status_code=429, detail="server busy, try again shortly") from None
        return {"job_id": job_id}

    @app.post("/v1/verify", dependencies=[Depends(require_token)])
    async def verify(
        image: UploadFile = File(...),
        positives: str = Form(...),
        negatives: str = Form(default="[]"),
    ) -> dict:
        """Daily quest check: is the photo one of `positives` (JSON list of short English
        descriptions) rather than an everyday distractor or one of `negatives`?"""
        wanted = parse_labels(positives, "positives", required=True)
        unwanted = parse_labels(negatives, "negatives", required=False)
        data = await image.read(MAX_UPLOAD_BYTES + 1)
        if len(data) > MAX_UPLOAD_BYTES:
            raise HTTPException(status_code=413, detail="image too large (max 15 MB)")
        try:
            Image.open(io.BytesIO(data)).verify()
        except Exception:  # noqa: BLE001
            raise HTTPException(status_code=400, detail="not a valid image") from None
        result = await run_in_threadpool(verifier, data, wanted, unwanted)
        return {"match": result.match, "score": result.score, "top": result.top}

    @app.get("/v1/jobs/{job_id}", dependencies=[Depends(require_token)])
    def job_status(job_id: str) -> dict:
        job = manager.get(job_id)
        if job is None:
            raise HTTPException(status_code=404, detail="unknown or expired job")
        return {"state": job.state, "stage": job.stage,
                "progress": round(job.progress, 3), "error": job.error}

    @app.get("/v1/jobs/{job_id}/result", dependencies=[Depends(require_token)])
    def job_result(job_id: str) -> Response:
        job = manager.get(job_id)
        if job is None:
            raise HTTPException(status_code=404, detail="unknown or expired job")
        if job.state == "failed":
            raise HTTPException(status_code=500, detail=job.error or "job failed")
        png = manager.get_result(job_id)
        if png is None:
            raise HTTPException(status_code=409, detail="result not ready")
        return Response(content=png, media_type="image/png")

    @app.delete("/v1/jobs/{job_id}", status_code=204, dependencies=[Depends(require_token)])
    def job_delete(job_id: str) -> Response:
        manager.delete(job_id)
        return Response(status_code=204)

    return app


def app_factory() -> FastAPI:
    token = ensure_token()
    print(f"\n  Locket server token: {token}\n", flush=True)
    app = create_app(token=token)
    warm_up_verifier(app.state.verifier)
    return app


def warm_up_verifier(verifier: Verifier) -> None:
    """Load CLIP in the background so the first quest photo is not slow."""
    warmup = getattr(verifier, "warmup", None)
    if warmup is None:
        return

    def load() -> None:
        try:
            warmup()
        except Exception as error:  # noqa: BLE001
            print("verifier warm-up failed:", error, flush=True)

    threading.Thread(target=load, daemon=True, name="verify-warmup").start()
