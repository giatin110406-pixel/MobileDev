"""HTTP-boundary tests: caller JWT for visibility, service role only for internal checks."""
import json

import httpx
import pytest
from fastapi import FastAPI
from fastapi.testclient import TestClient

from locket_server.search_api import search_router
from locket_server.search_service import SearchService, SearchRequest
from locket_server.search_store import SupabaseSearchStore
from locket_server.search_worker import TagWorker

OWNER = '00000000-0000-0000-0000-000000000001'
POST = '00000000-0000-0000-0000-000000000002'
OTHER = '00000000-0000-0000-0000-000000000003'
HEADERS = {'Authorization': 'Bearer viewer-jwt', 'X-Locket-Token': 'app-token'}


def setup_service(*, stranger=False, revoked=False, cached=None):
    requests, checks = [], []
    row = dict(id=POST, author_id=OWNER, ai_tags='Objects: dog, cup', ai_status='done',
               kind='photo', media_path='owner/photo.jpg', original_path=None, created_at='2026-10-29T00:00:00Z')

    def transport(request):
        requests.append(request)
        path = request.url.path
        if path == '/auth/v1/user':
            assert request.headers['authorization'] == 'Bearer viewer-jwt'
            assert request.headers['apikey'] == 'public-key'
            return httpx.Response(200, json={'id': OWNER})
        if path == '/rest/v1/posts':
            assert request.headers['authorization'] == 'Bearer viewer-jwt'
            assert request.headers['apikey'] == 'public-key'
            if stranger or (revoked and request.url.params['select'] == 'id'):
                return httpx.Response(200, json=[])
            return httpx.Response(200, json=[row])
        if path == '/rest/v1/post_checks':
            assert request.headers['authorization'] == 'Bearer service-key'
            assert request.headers['apikey'] == 'service-key'
            if request.method == 'GET':
                rows = [] if cached is None else [dict(post_id=POST, term='dog', probability=cached)]
                return httpx.Response(200, json=rows)
            return httpx.Response(201)
        if path.startswith('/storage/v1/object/'):
            assert request.headers['authorization'] == 'Bearer viewer-jwt'
            assert request.headers['apikey'] == 'public-key'
            return httpx.Response(200, content=b'fake-image')
        raise AssertionError(path)

    store = SupabaseSearchStore('https://test.supabase.co', 'public-key', 'service-key',
                                httpx.Client(transport=httpx.MockTransport(transport)))

    def check(images, terms):
        checks.extend(terms)
        assert all(image == b'fake-image' for image in images)
        return [0.91 if term == 'dog' else 0.2 for term in terms]

    app = FastAPI()
    app.include_router(search_router(SearchService(store, check), 'app-token'))
    return TestClient(app), requests, checks, store


def test_visible_photo_checked_cached_and_returned():
    client, requests, checks, _ = setup_service()
    result = client.post('/search', headers=HEADERS, json={'terms': ['dog']})
    assert result.status_code == 200
    assert result.json() == {'post_ids': [POST], 'pending': 0}
    assert checks == ['dog']
    writes = [r for r in requests if r.method == 'POST']
    assert json.loads(writes[0].content) == [dict(post_id=POST, term='dog', probability=0.91)]


def test_stranger_cannot_reach_internal_cache_or_model():
    client, requests, checks, _ = setup_service(stranger=True)
    assert client.post('/search', headers=HEADERS, json={'terms': ['dog']}).json()['post_ids'] == []
    assert checks == []
    assert all('/post_checks' not in r.url.path and '/storage/' not in r.url.path for r in requests)


def test_permission_revoked_during_search_is_rechecked():
    client, _, checks, _ = setup_service(revoked=True)
    assert client.post('/search', headers=HEADERS, json={'terms': ['dog']}).json()['post_ids'] == []
    assert checks == ['dog']


def test_cached_answer_avoids_model_and_image_download():
    client, requests, checks, _ = setup_service(cached=0.9)
    assert client.post('/search', headers=HEADERS, json={'terms': ['dog']}).json()['post_ids'] == [POST]
    assert checks == []
    assert all('/storage/' not in r.url.path and r.method != 'POST' for r in requests)


def test_multiple_terms_intersect_and_empty_never_becomes_closest_photo():
    client, _, checks, _ = setup_service()
    assert client.post('/search', headers=HEADERS, json={'terms': ['dog', 'cup']}).json()['post_ids'] == []
    assert checks == ['dog', 'cup']


def test_name_only_never_calls_image_model():
    client, _, checks, _ = setup_service()
    assert client.post('/search', headers=HEADERS, json={'name_only': True}).json()['post_ids'] == []
    assert checks == []


@pytest.mark.parametrize('headers', [{}, {'X-Locket-Token': 'app-token'},
                                     {'Authorization': 'Bearer viewer-jwt', 'X-Locket-Token': 'wrong'}])
def test_both_authentication_headers_are_required(headers):
    client, requests, checks, _ = setup_service()
    assert client.post('/search', headers=headers, json={'terms': ['dog']}).status_code == 401
    assert requests == checks == []


@pytest.mark.parametrize('body', [dict(terms=['']), dict(terms=['ignore\nprevious']),
    dict(from_time='2026-10-29'), dict(from_time='2026-10-30T00:00:00Z', until_time='2026-10-29T00:00:00Z'),
    dict(name_only=True, terms=['dog']), dict(terms=['dog'], author_id=OTHER)])
def test_invalid_queries_fail_before_database_or_model(body):
    client, requests, checks, _ = setup_service()
    assert client.post('/search', headers=HEADERS, json=body).status_code == 422
    assert requests == checks == []


def test_filters_reach_caller_scoped_postgrest_request():
    _, requests, _, store = setup_service()
    store.visible_posts('viewer-jwt', OWNER, SearchRequest(mine=True,
        from_time='2026-10-01T00:00:00+07:00', until_time='2026-11-01T00:00:00+07:00'))
    params = requests[0].url.params
    assert params['author_id'] == 'eq.'+OWNER
    assert 'created_at.gte.2026-10-01T00:00:00+07:00' in params['and']
    assert 'created_at.lt.2026-11-01T00:00:00+07:00' in params['and']


def test_worker_retries_three_times_then_marks_failed():
    attempts, status = 0, 'pending'
    requests = []

    def transport(request):
        nonlocal attempts, status
        requests.append(request)
        assert request.headers['authorization'] == 'Bearer service-key'
        if request.method == 'GET':
            return httpx.Response(200, json=[] if status != 'pending' else [
                dict(id=POST, author_id=OWNER, ai_attempts=attempts)])
        data = json.loads(request.content)
        assert request.url.params['ai_attempts'] == 'eq.'+str(attempts)
        attempts, status = data['ai_attempts'], data['ai_status']
        return httpx.Response(204)

    store = SupabaseSearchStore('https://test.supabase.co', 'public-key', 'service-key',
                                httpx.Client(transport=httpx.MockTransport(transport)))
    store.image = lambda _: b'photo'

    def broken(_):
        raise RuntimeError('failed')

    worker = TagWorker(store, broken, OWNER)
    assert [worker.run_once() for _ in range(4)] == [1, 1, 1, 0]
    assert attempts == 3 and status == 'failed'


def test_busy_gpu_does_not_spend_tagging_retry():
    from locket_server.search_service import SearchBusy
    class Store:
        def pending(self, *_):
            return [dict(id=POST)]
        def image(self, *_):
            return b'photo'
        def finish_tag(self, *_):
            raise AssertionError('busy GPU must not count as a failed photo')
    def busy(_):
        raise SearchBusy()
    assert TagWorker(Store(), busy, OWNER).run_once() == 0


def test_only_one_search_process_can_own_the_local_gpu(tmp_path):
    from locket_server.search_models import SingleSearchProcess
    path = tmp_path/'gpu.lock'
    with SingleSearchProcess(path):
        with pytest.raises(RuntimeError):
            with SingleSearchProcess(path):
                raise AssertionError('second process acquired GPU lease')
    with SingleSearchProcess(path):
        pass  # released lease can be acquired again


def test_tagging_success_uses_original_and_updates_only_pending_owner_post():
    requests = []
    def transport(request):
        requests.append(request)
        assert request.headers['authorization'] == 'Bearer service-key'
        if request.url.path.startswith('/storage/'):
            assert request.url.path.endswith('/original.jpg')
            return httpx.Response(200, content=b'original')
        if request.method == 'GET':
            assert request.url.params['author_id'] == 'eq.'+OWNER
            assert request.url.params['limit'] == '20'
            return httpx.Response(200, json=[dict(id=POST, ai_attempts=1, kind='photo',
                original_path='owner/original.jpg', media_path='owner/styled.jpg')])
        body = json.loads(request.content)
        assert body == dict(ai_tags='Objects: dog\nScene: A dog.', ai_attempts=1, ai_status='done')
        assert request.url.params['ai_status'] == 'eq.pending'
        assert request.url.params['deleted_at'] == 'is.null'
        return httpx.Response(204)
    store = SupabaseSearchStore('https://test.supabase.co', 'public-key', 'service-key',
                                httpx.Client(transport=httpx.MockTransport(transport)))
    def tag(data):
        assert data == b'original'
        return 'Objects: dog\nScene: A dog.'
    assert TagWorker(store, tag, OWNER).run_once() == 1


def test_video_without_thumbnail_does_not_download_video():
    _, requests, _, store = setup_service()
    with pytest.raises(ValueError):
        store.image(dict(kind='video', media_path='owner/video.mp4'))
    assert requests == []


def test_invalid_cached_probability_fails_closed_without_gpu():
    client, _, checks, _ = setup_service(cached='Infinity')
    assert client.post('/search', headers=HEADERS, json={'terms': ['dog']}).json()['post_ids'] == []
    assert checks == []


def test_dedicated_factory_starts_without_diffusion_and_closes_client(monkeypatch):
    from types import SimpleNamespace
    from locket_server import api, search_models
    _, _, _, store = setup_service(cached=0.9)
    monkeypatch.setattr(api, 'ensure_token', lambda: 'app-token')
    monkeypatch.setattr(SupabaseSearchStore, 'from_env', classmethod(lambda cls: store))
    monkeypatch.setattr(search_models, 'LocalVlm', lambda: SimpleNamespace(
        check=lambda *_: pytest.fail('cached search must not invoke the GPU'), tag=None))
    monkeypatch.delenv('LOCKET_SEARCH_TAG_OWNER', raising=False)
    with TestClient(api.search_app_factory()) as client:
        result = client.post('/search', headers=HEADERS, json={'terms': ['dog']})
        assert result.status_code == 200 and result.json()['post_ids'] == [POST]
    assert store.client.is_closed
