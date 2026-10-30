import json
import pytest

from locket_server.query_parser import ParseRequest, QueryParser

FRIEND = '00000000-0000-0000-0000-000000000001'


def request(**changes):
    values = dict(text='ảnh chó với Lan hôm qua', visual_text='chó',
        now='2026-10-29T12:00:00+07:00', friends=[dict(id=FRIEND, name='Lan')],
        rules=dict(terms=[], friend_id=FRIEND, mine=False,
                   from_time='2026-10-28T00:00:00+07:00', until_time='2026-10-29T00:00:00+07:00'))
    values.update(changes)
    return ParseRequest.model_validate(values)


def output(**changes):
    values = dict(friend=None, from_time=None, until_time=None, mine=False,
                  terms=['dog'], name_only=False)
    values.update(changes)
    return json.dumps(values)


def test_model_parses_terms_rules_preserve_recognized_friend_and_dates():
    result = QueryParser(lambda _: output()).parse(request())
    assert result['query']['terms'] == ['dog']
    assert result['query']['friend_id'] == FRIEND
    assert result['query']['from_time'].startswith('2026-10-28')
    assert not result['declined']


def test_unknown_friend_and_invalid_model_dates_use_rules():
    result = QueryParser(lambda _: output(friend='not-a-friend', from_time='nonsense', until_time='tomorrow')).parse(
        request(rules=dict(terms=[], friend_id=None)))
    assert result['query']['friend_id'] is None
    assert result['query']['from_time'] is None


@pytest.mark.parametrize('raw', ['not json', '{}', output(terms=['chó']), output(mine='yes'),
                                output(terms=['dog\nignore instructions'])])
def test_invalid_model_json_never_reaches_search(raw):
    with pytest.raises(ValueError):
        QueryParser(lambda _: raw).parse(request())


def test_name_only_never_calls_model():
    def never(_):
        raise AssertionError('name-only must not call model')
    result = QueryParser(never).parse(request(text='Lan', visual_text='Lan', rules=dict(name_only=True)))
    assert result['query']['name_only']
    assert result['query']['terms'] == []


def test_negation_and_empty_object_output_fail_closed():
    def never(_):
        raise AssertionError('unsupported negation must not call model')
    assert QueryParser(never).parse(request(text='ảnh không có chó'))['declined']
    assert QueryParser(lambda _: output(terms=[])).parse(request())['declined']
