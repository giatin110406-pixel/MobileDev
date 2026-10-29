"""Authenticated search orchestration. Photo visibility always comes from the caller's JWT."""
from __future__ import annotations

from datetime import datetime
import math
import re
import threading
from typing import Callable, Protocol
from uuid import UUID

from pydantic import BaseModel, ConfigDict, Field, field_validator, model_validator

from .search_terms import has_term
from .search_v2 import CheckCache, THRESHOLD, search


class SearchRequest(BaseModel):
    model_config = ConfigDict(extra='forbid')
    terms: list[str] = Field(default_factory=list, max_length=8)
    friend_id: UUID | None = None
    mine: bool = False
    from_time: datetime | None = None
    until_time: datetime | None = None
    name_only: bool = False

    @field_validator('terms')
    @classmethod
    def english_terms(cls, values):
        values = list(dict.fromkeys(v.strip().lower() for v in values))
        if any(not re.fullmatch(r"[a-z][a-z0-9 ' -]{0,79}", v) for v in values):
            raise ValueError('terms must be short English object names')
        return values

    @model_validator(mode='after')
    def valid_dates(self):
        for value in (self.from_time, self.until_time):
            if value is not None and value.utcoffset() is None:
                raise ValueError('dates must include a timezone')
        if self.from_time and self.until_time and self.from_time >= self.until_time:
            raise ValueError('from_time must precede until_time')
        if self.name_only and self.terms:
            raise ValueError('name-only queries cannot contain visual terms')
        return self


class SearchStore(Protocol):
    def user_id(self, jwt: str) -> str: ...
    def visible_posts(self, jwt: str, user_id: str, query: SearchRequest) -> list[dict]: ...
    def visible_ids(self, jwt: str, ids: list[str]) -> set[str]: ...
    def read_checks(self, pairs: list[tuple[str, str]]) -> dict: ...
    def write_checks(self, answers: dict) -> None: ...
    def image(self, post: dict, jwt: str | None) -> bytes: ...


class SearchBusy(Exception):
    pass


class SearchService:
    def __init__(self, store: SearchStore, check: Callable, threshold: float = THRESHOLD):
        self.store, self.check, self.threshold = store, check, threshold
        self._lock = threading.Lock()

    def run(self, jwt: str, query: SearchRequest) -> dict:
        # Authentication is remote verification, never a locally decoded unverified JWT.
        user_id = self.store.user_id(jwt)
        if not self._lock.acquire(blocking=False):
            raise SearchBusy()
        try:
            return self._run(jwt, user_id, query)
        finally:
            self._lock.release()

    def _run(self, jwt, user_id, query):
        if query.name_only and query.friend_id is None and not query.mine:
            return dict(post_ids=[], pending=0)
        posts = self.store.visible_posts(jwt, user_id, query)
        pending = sum(p.get('ai_status') != 'done' for p in posts)
        by_id = {p['id']: p for p in posts}
        if not query.terms:
            ids = list(by_id)  # filter-only search, newest first; never invokes a photo model
        else:
            tags = {p['id']: p['ai_tags'] for p in posts
                    if p.get('ai_status') == 'done' and p.get('ai_tags')}
            pairs = [(pid, term) for term in query.terms for pid, text in tags.items()
                     if has_term(text.lower(), term)]
            # Only read cache entries for posts already visible to this caller.
            cache = CheckCache(self.store.read_checks(pairs))
            def ask(chunk):
                images = [self.store.image(by_id[pid], jwt) for pid, _ in chunk]
                values = self.check(images, [term for _, term in chunk])
                if len(values) != len(chunk):
                    raise ValueError('one model answer is required per pair')
                values = [v if v is not None and math.isfinite(v) and 0 <= v <= 1 else None
                          for v in values]
                # Persist completed batches even if a later batch/term fails.
                self.store.write_checks(dict(zip(chunk, values)))
                return values

            ids = list(tags)
            for term in query.terms:
                selected = set(search(term, {pid: tags[pid] for pid in ids}, cache, ask,
                                      self.threshold))
                ids = [pid for pid in ids if pid in selected]
                if not ids:
                    break
            # Weakest term is the rank for an AND query; stable ties retain newest first.
            ids.sort(key=lambda pid: min(cache.get(pid, term) for term in query.terms), reverse=True)
        # Re-check RLS after slow inference: friendship/post visibility may have changed.
        allowed = self.store.visible_ids(jwt, ids) if ids else set()
        return dict(post_ids=[pid for pid in ids if pid in allowed], pending=pending)
