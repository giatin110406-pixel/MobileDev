"""Supabase REST adapter: user reads use JWT; internal checks and tagging use service role."""
from __future__ import annotations

import os
import math
from urllib.parse import quote

import httpx

from .search_service import SearchRequest

PAGE = 200
POST_COLUMNS = 'id,author_id,kind,media_path,original_path,thumb_path,created_at,ai_tags,ai_status,ai_attempts'


def chunks(values, size=100):
    for start in range(0, len(values), size):
        yield values[start:start+size]


class SupabaseSearchStore:
    def __init__(self, url: str, public_key: str, service_key: str, client=None):
        if not url.startswith(('https://', 'http://127.0.0.1:', 'http://localhost:')):
            raise ValueError('Supabase URL must use HTTPS (except local development)')
        self.url, self.public_key, self.service_key = url.rstrip('/'), public_key, service_key
        self.client = client or httpx.Client(timeout=30, follow_redirects=False)

    @classmethod
    def from_env(cls):
        return cls(os.environ['SUPABASE_URL'], os.environ['SUPABASE_ANON_KEY'],
                   os.environ['SUPABASE_SERVICE_ROLE_KEY'])

    def request(self, method, path, jwt=None, *, service=False, **kwargs):
        if not service and not jwt:
            raise ValueError('a caller JWT is required for user reads')
        key = self.service_key if service else self.public_key
        headers = dict(apikey=key, Authorization=f'Bearer {key if service else jwt}')
        headers.update(kwargs.pop('headers', {}))
        response = self.client.request(method, self.url+path, headers=headers, **kwargs)
        response.raise_for_status()
        return response

    def user_id(self, jwt):
        return self.request('GET', '/auth/v1/user', jwt).json()['id']

    def rows(self, table, params, jwt=None, *, service=False):
        out = []
        while True:
            page = self.request('GET', '/rest/v1/'+table, jwt, service=service,
                                params={**params, 'limit': PAGE, 'offset': len(out)}).json()
            out.extend(page)
            if len(page) < PAGE:
                return out

    def visible_posts(self, jwt, user_id, query: SearchRequest):
        params = dict(select=POST_COLUMNS, order='created_at.desc,id.desc', deleted_at='is.null')
        if query.mine:
            params['author_id'] = 'eq.'+user_id
        if query.from_time or query.until_time:
            conditions = []
            if query.from_time:
                conditions.append('created_at.gte.'+query.from_time.isoformat())
            if query.until_time:
                conditions.append('created_at.lt.'+query.until_time.isoformat())
            params['and'] = '('+','.join(conditions)+')'
        posts = self.rows('posts', params, jwt)
        if query.friend_id:
            friend = str(query.friend_id)
            related = {p['id'] for p in posts if p['author_id'] == friend}
            for part in chunks([p['id'] for p in posts]):
                for table in ('post_recipients', 'post_tags'):
                    rows = self.rows(table, dict(select='post_id', user_id='eq.'+friend,
                                                post_id='in.('+','.join(part)+')'), jwt)
                    related.update(r['post_id'] for r in rows)
            posts = [p for p in posts if p['id'] in related]
        return posts

    def visible_ids(self, jwt, ids):
        allowed = set()
        for part in chunks(ids):
            rows = self.rows('posts', dict(select='id', deleted_at='is.null',
                                          id='in.('+','.join(part)+')'), jwt)
            allowed.update(r['id'] for r in rows)
        return allowed

    def read_checks(self, pairs):
        answers = {}
        for term in dict.fromkeys(term for _, term in pairs):
            ids = [pid for pid, t in pairs if t == term]
            for part in chunks(ids):
                rows = self.rows('post_checks', dict(select='post_id,term,probability',
                                 term='eq.'+term, post_id='in.('+','.join(part)+')'), service=True)
                for r in rows:
                    value = r['probability']
                    answers[(r['post_id'], r['term'])] = (
                        value if isinstance(value, (int, float)) and math.isfinite(value)
                        and 0 <= value <= 1 else None)
        return answers

    def write_checks(self, answers):
        rows = [dict(post_id=pid, term=term, probability=value) for (pid, term), value in answers.items()]
        for part in chunks(rows):
            self.request('POST', '/rest/v1/post_checks', service=True,
                         params={'on_conflict': 'post_id,term'}, json=part,
                         headers={'Prefer': 'resolution=merge-duplicates'})

    def image(self, post, jwt=None):
        path = (post.get('thumb_path') if post.get('kind') == 'video' else
                post.get('original_path') or post.get('media_path'))
        if not path:
            raise ValueError('post has no searchable image')
        # Bucket paths only, never arbitrary URLs or redirects. Stream with a size bound.
        key = self.public_key if jwt else self.service_key
        headers = dict(apikey=key, Authorization=f'Bearer {jwt or self.service_key}')
        with self.client.stream('GET', self.url+'/storage/v1/object/authenticated/media/'+quote(path, safe='/'),
                                headers=headers) as response:
            response.raise_for_status()
            data = bytearray()
            for block in response.iter_bytes():
                data.extend(block)
                if len(data) > 15*1024*1024:
                    raise ValueError('photo exceeds 15 MB')
            return bytes(data)

    def pending(self, owner: str | None, limit=20):
        params = dict(select=POST_COLUMNS, ai_status='eq.pending', deleted_at='is.null',
                      order='created_at.asc,id.asc', limit=limit)
        if owner is not None:
            params['author_id'] = 'eq.'+owner
        return self.request('GET', '/rest/v1/posts', service=True,
                            params=params).json()

    def finish_tag(self, post, tags=None):
        attempts = post['ai_attempts'] + int(tags is None)
        data = dict(ai_attempts=attempts,
                    ai_status='done' if tags is not None else ('failed' if attempts >= 3 else 'pending'))
        if tags is not None:
            data['ai_tags'] = tags
        self.request('PATCH', '/rest/v1/posts', service=True,
                     params=dict(id='eq.'+post['id'], ai_status='eq.pending',
                                 ai_attempts='eq.'+str(post['ai_attempts']), deleted_at='is.null'), json=data)
