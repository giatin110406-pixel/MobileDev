"""Opt-in HTTP interface. No model or Supabase client is created merely by importing it."""
from __future__ import annotations

import secrets

from fastapi import APIRouter, Header, HTTPException
import httpx

from .search_service import SearchBusy, SearchRequest
from .query_parser import ParseRequest


def search_router(service, token, parser=None):
    router = APIRouter()

    @router.post('/search/parse')
    def parse(query: ParseRequest, authorization: str | None = Header(default=None),
              x_locket_token: str | None = Header(default=None)):
        if x_locket_token is None or not secrets.compare_digest(x_locket_token, token):
            raise HTTPException(401, 'invalid token')
        scheme, _, jwt = (authorization or '').partition(' ')
        if scheme.lower() != 'bearer' or not jwt.strip():
            raise HTTPException(401, 'Supabase bearer token required')
        if service is None or parser is None:
            raise HTTPException(503, 'query parser is not configured')
        try:
            service.store.user_id(jwt.strip())
            return parser.parse(query)
        except SearchBusy:
            raise HTTPException(429, 'query parser busy') from None
        except (httpx.HTTPError, ValueError, RuntimeError, OSError):
            raise HTTPException(503, 'query parser unavailable') from None

    @router.post('/search')
    def search(query: SearchRequest, authorization: str | None = Header(default=None),
               x_locket_token: str | None = Header(default=None)):
        if x_locket_token is None or not secrets.compare_digest(x_locket_token, token):
            raise HTTPException(401, 'invalid token')
        scheme, _, jwt = (authorization or '').partition(' ')
        if scheme.lower() != 'bearer' or not jwt.strip():
            raise HTTPException(401, 'Supabase bearer token required')
        if service is None:
            raise HTTPException(503, 'Search v2 is not configured')
        try:
            return service.run(jwt.strip(), query)
        except SearchBusy:
            raise HTTPException(429, 'search busy, try again shortly') from None
        except httpx.HTTPStatusError as error:
            status = 401 if error.response.status_code in (401, 403) else 503
            raise HTTPException(status, 'search backend unavailable or session expired') from None
        except (httpx.RequestError, RuntimeError, ValueError):
            raise HTTPException(503, 'search backend unavailable') from None

    return router
