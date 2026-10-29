"""Guard evaluation accounting before spending GPU time on a new prompt."""
import numpy as np

from eval.compare_tags import absent_stress, metrics, tag_matrix
from eval.search_fp_eval import IDS


def test_no_answer_counts_only_completely_absent_terms():
    truth = np.zeros((2, 91))
    truth[0, IDS[0]] = 0.03
    truth[1, IDS[1]] = 0.01  # tiny-only query: neither positive nor absent
    shown = np.zeros((2, len(IDS)), dtype=bool)
    shown[0, 2] = True  # an incorrect result for an absent category
    result = metrics(truth, shown, [np.arange(2)])
    assert result['queries'] == 1
    assert result['no_answer'] == 78
    assert result['empty_count'] == 77
    assert result['empty'] == 77 / 78
    assert result['missed'] == 1
    assert result['wrong'] is None  # no positive-answer query showed a photo


def test_counts_photo_errors_without_treating_tiny_objects_as_wrong():
    truth = np.zeros((3, 91))
    truth[0, IDS[0]] = 0.03
    truth[1, IDS[0]] = 0.01
    shown = np.zeros((3, len(IDS)), dtype=bool)
    shown[:, 0] = True
    result = metrics(truth, shown, [np.arange(3)])
    assert result['shown'] == 3
    assert result['wrong_count'] == 1
    assert result['wrong'] == 1 / 3
    assert result['missed'] == 0


def test_tag_matching_uses_production_synonyms_and_whole_words():
    matrix = tag_matrix(['Objects: Bike, CUP', 'Objects: carpet'])
    assert matrix[0, 1]  # bicycle
    assert not matrix[1, 2]  # car is not carpet


def test_absent_stress_removes_positive_and_tiny_photos():
    truth = np.zeros((3, 91))
    truth[0, IDS[0]] = 0.03
    truth[1, IDS[0]] = 0.01
    shown = np.zeros((3, len(IDS)), dtype=bool)
    shown[0, 0] = shown[1, 0] = True
    result = absent_stress(truth, shown)
    assert result['queries'] == 80
    assert result['empty'] == 1
    assert result['min_size'] == 1
    assert result['max_size'] == 3
    shown[2, 0] = True
    assert absent_stress(truth, shown)['failed_terms'] == ['person']
