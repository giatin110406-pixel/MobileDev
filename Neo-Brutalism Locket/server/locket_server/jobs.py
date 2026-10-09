"""In-memory job queue with a single GPU worker thread. Images are never written to disk
unless DEBUG_SAVE=1."""
from __future__ import annotations

import io
import os
import queue
import threading
import time
import uuid
from dataclasses import dataclass, field
from pathlib import Path
from typing import Callable

from PIL import Image

from .config import SERVER_ROOT

JOB_TTL_SECONDS = 600
MAX_QUEUED = 4

# runner(style, image_bytes, params, stage_cb) -> PIL image
Runner = Callable[[str, bytes, dict, Callable[[str, float], None]], Image.Image]


@dataclass
class Job:
    id: str
    style: str
    data: bytes | None
    params: dict
    state: str = "queued"          # queued | running | done | failed
    stage: str = "queued"
    progress: float = 0.0
    error: str | None = None
    result: bytes | None = None
    created: float = field(default_factory=time.time)
    finished: float | None = None


class QueueFull(Exception):
    pass


class JobManager:
    def __init__(self, runner: Runner) -> None:
        self._runner = runner
        self._jobs: dict[str, Job] = {}
        self._lock = threading.Lock()
        self._queue: queue.Queue[str] = queue.Queue()
        self._worker = threading.Thread(target=self._work, daemon=True, name="gpu-worker")
        self._worker.start()

    def submit(self, style: str, data: bytes, params: dict) -> str:
        with self._lock:
            self._expire()
            pending = sum(1 for j in self._jobs.values() if j.state in ("queued", "running"))
            if pending >= MAX_QUEUED:
                raise QueueFull
            job = Job(id=uuid.uuid4().hex, style=style, data=data, params=params)
            self._jobs[job.id] = job
        self._queue.put(job.id)
        return job.id

    def get(self, job_id: str) -> Job | None:
        with self._lock:
            self._expire()
            return self._jobs.get(job_id)

    def get_result(self, job_id: str) -> bytes | None:
        """Return the PNG without consuming it, so a dropped download can be retried."""
        with self._lock:
            job = self._jobs.get(job_id)
            if job is None or job.state != "done" or job.result is None:
                return None
            return job.result

    def delete(self, job_id: str) -> bool:
        """Forget a job (the client calls this once it has the image)."""
        with self._lock:
            return self._jobs.pop(job_id, None) is not None

    @property
    def busy(self) -> bool:
        with self._lock:
            return any(j.state in ("queued", "running") for j in self._jobs.values())

    def _expire(self) -> None:
        now = time.time()
        for job_id in [k for k, j in self._jobs.items() if now - j.created > JOB_TTL_SECONDS]:
            del self._jobs[job_id]

    def _work(self) -> None:
        while True:
            job_id = self._queue.get()
            job = self.get(job_id)
            if job is None:
                continue
            job.state = "running"
            try:
                def stage_cb(stage: str, fraction: float) -> None:
                    job.stage, job.progress = stage, max(job.progress, min(1.0, fraction))

                image = self._runner(job.style, job.data, job.params, stage_cb)
                buffer = io.BytesIO()
                image.save(buffer, format="PNG")
                job.result = buffer.getvalue()
                if os.environ.get("DEBUG_SAVE") == "1":
                    self._debug_save(job)
                job.progress, job.stage, job.state = 1.0, "done", "done"
            except Exception as error:  # noqa: BLE001 - report any failure to the client
                job.state, job.error = "failed", f"{type(error).__name__}: {error}"
                if "CUDA error" in str(error):
                    # A CUDA fault (e.g. illegal memory access) poisons the whole process:
                    # every later job would fail. Exit after the client has seen the failure;
                    # run_server.ps1 restarts the server.
                    threading.Timer(3.0, lambda: os._exit(3)).start()
            finally:
                job.data = None          # drop the source photo from memory
                job.finished = time.time()

    @staticmethod
    def _debug_save(job: Job) -> None:
        out = SERVER_ROOT / "eval" / "captured"
        out.mkdir(parents=True, exist_ok=True)
        if job.data:
            (out / f"{job.id}_{job.style}_original.jpg").write_bytes(job.data)
        if job.result:
            (out / f"{job.id}_{job.style}.png").write_bytes(job.result)
