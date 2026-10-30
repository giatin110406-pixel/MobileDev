from locket_server import search_v2
from locket_server.search_terms import has_term
import pytest


def fake_ask(answers):
    """A model stand-in: returns the given probability per pair and records every question."""
    asked = []

    def ask(pairs):
        asked.extend(pairs)
        return [answers.get(pair) for pair in pairs]
    return ask, asked


def test_tag_words_match_the_term_and_its_synonyms():
    assert has_term("objects: bike, cup. scene: a street", "bicycle")
    assert has_term("objects: sofa, lamp", "couch")
    assert not has_term("objects: bicycles-shaped rack", "car")  # whole words only


def test_shown_only_when_tags_match_and_check_is_confident():
    tags = {"a": "objects: cup, table", "b": "objects: plate", "c": "objects: cup"}
    ask, asked = fake_ask({("a", "cup"): 0.95, ("c", "cup"): 0.5})
    shown = search_v2.search("cup", tags, search_v2.CheckCache(), ask)
    assert shown == ["a"]
    assert asked == [("a", "cup"), ("c", "cup")]   # "b" is never asked: its tags do not name a cup


def test_threshold_is_inclusive_and_nan_or_missing_never_shows():
    assert search_v2.check_shows(True, 0.8)
    assert not search_v2.check_shows(True, 0.79)
    assert not search_v2.check_shows(True, float("nan"))
    assert not search_v2.check_shows(True, None)
    assert not search_v2.check_shows(False, 0.99)


def test_each_pair_is_asked_once_across_searches():
    tags = {"a": "objects: dog, bench", "b": "objects: dog"}
    ask, asked = fake_ask({("a", "dog"): 0.9, ("b", "dog"): 0.9})
    cache = search_v2.CheckCache()
    assert search_v2.search("dog", tags, cache, ask) == ["a", "b"]
    assert search_v2.search("dog", tags, cache, ask) == ["a", "b"]
    assert len(asked) == 2


def test_a_model_that_cannot_answer_hides_the_photo():
    tags = {"a": "objects: dog"}
    ask, _ = fake_ask({("a", "dog"): None})
    assert search_v2.search("dog", tags, search_v2.CheckCache(), ask) == []


def test_no_tag_matches_means_no_question_and_no_result():
    ask, asked = fake_ask({})
    assert search_v2.search("elephant", {"a": "objects: cup"}, search_v2.CheckCache(), ask) == []
    assert asked == []


def test_prompts_name_the_term_and_the_format():
    assert "Is there a boat clearly visible" in search_v2.check_prompt("boat")
    assert "Objects:" in search_v2.TAG_PROMPT


@pytest.mark.parametrize('probability', [float('inf'), -float('inf'), 1.1, -0.1])
def test_invalid_probabilities_never_show_a_photo(probability):
    assert not search_v2.check_shows(True, probability)


@pytest.mark.parametrize('threshold', [float('nan'), float('inf'), -0.1, 1.1])
def test_invalid_threshold_is_rejected(threshold):
    with pytest.raises(ValueError):
        search_v2.check_shows(True, 0.9, threshold)


def test_wrong_number_of_answers_is_not_partially_cached():
    cache = search_v2.CheckCache()
    with pytest.raises(ValueError):
        cache.ensure([('a', 'dog'), ('b', 'dog')], lambda _: [0.9])
    assert cache.answers == {}


def test_nonpositive_batch_is_rejected():
    with pytest.raises(ValueError):
        search_v2.CheckCache().ensure([('a', 'dog')], lambda _: [0.9], batch=0)
