import json

import pytest

from locket_server.query_parser import ParseRequest, QueryParser
from locket_server.search_lexicon import lookup


def request(**changes):
    values = dict(text='x', visual_text='x', now='2026-10-29T12:00:00+07:00', friends=[],
                  rules=dict(terms=[]))
    values.update(changes)
    return ParseRequest.model_validate(values)


@pytest.mark.parametrize('text,terms', [
    ('ly nước suối', ['water']),
    ('chai nước', ['bottle']),
    ('cà phê', ['coffee']),
    ('ly cà phê', ['coffee']),
    ('bữa uống cà phê ở quán', ['coffee']),
    ('ảnh con chó', ['dog']),
    ('ảnh cái bàn và cái ghế', ['table', 'chair']),
])
def test_everyday_words_need_no_model(text, terms):
    found, left = lookup(text)
    assert found == terms and left == ''


@pytest.mark.parametrize('text', ['ảnh bạn bè', 'ảnh Bình', 'ảnh Ly', 'du lịch', 'ảnh Hoa'])
def test_names_and_other_words_are_not_objects(text):
    found, _ = lookup(text)
    assert found == []


def never(_):
    raise AssertionError('model must not be called')


def test_lexicon_answers_without_calling_model():
    result = QueryParser(never).parse(request(text='ly nước suối', visual_text='ly nước suối'))
    assert result['query']['terms'] == ['water'] and not result['declined']


def test_unexplained_words_still_go_to_the_model_and_keep_lexicon_terms():
    seen = []
    def model(prompt):
        seen.append(prompt)
        return json.dumps(dict(friend=None, from_time=None, until_time=None, mine=False,
                               terms=['skateboard'], name_only=False))
    result = QueryParser(model).parse(request(text='cà phê và ván trượt', visual_text='cà phê và ván trượt'))
    assert result['query']['terms'] == ['coffee', 'skateboard']
    assert 'van truot' in seen[0] and 'ca phe' not in seen[0]
