"""`add_me` on synthetic pairs: a clean pair merges; pairs the method cannot honestly handle are
refused with a reason. Real hair/clothes quality is measured on real pairs, not here."""
import numpy as np
import pytest

cv2 = pytest.importorskip("cv2")

from eval import add_me as am  # noqa: E402
from eval.add_me_synth import make_pair  # noqa: E402


@pytest.mark.parametrize("seed", range(4))
def test_clean_pair_merges_close_to_truth(seed):
    pair = make_pair(seed)
    result = am.add_me(pair.shot_1, pair.shot_2)
    assert result.ok, (result.reason, result.info)
    err = np.abs(result.image.astype(np.float32) - pair.truth.astype(np.float32)).mean(axis=2)
    inside = pair.holder > 0
    assert err[~inside].mean() < 4.0  # the group and background stay as in shot 1
    assert err[inside].mean() < 12.0  # the holder arrives from shot 2


def test_holder_is_actually_added():
    pair = make_pair(1)
    result = am.add_me(pair.shot_1, pair.shot_2)
    inside = pair.holder > 0
    before = np.abs(pair.shot_1.astype(np.float32) - pair.truth.astype(np.float32)).mean(axis=2)[inside].mean()
    after = np.abs(result.image.astype(np.float32) - pair.truth.astype(np.float32)).mean(axis=2)[inside].mean()
    assert before > 30 and after < before / 3


def test_two_unrelated_scenes_are_refused():
    a = make_pair(10).shot_1
    b = make_pair(11).shot_1
    result = am.add_me(a, b)
    assert not result.ok and result.reason == am.REASON_ALIGN


def test_same_scene_without_a_new_person_is_refused():
    pair = make_pair(2)
    result = am.add_me(pair.shot_1, pair.shot_1)
    assert not result.ok and result.reason == am.REASON_NO_PERSON


def test_background_that_changed_is_refused():
    pair = make_pair(3)
    changed = pair.shot_2.copy()
    h, w = changed.shape[:2]
    for x0 in (0.05, 0.3, 0.55):  # something else moved in the scene: big patches differ too
        a, b = int(w * x0), int(w * (x0 + 0.15))
        changed[int(h * 0.05):int(h * 0.45), a:b] = 255 - changed[int(h * 0.05):int(h * 0.45), a:b]
    result = am.add_me(pair.shot_1, changed)
    assert not result.ok and result.reason == am.REASON_BACKGROUND


def test_seed_picks_the_person():
    pair = make_pair(4)
    result = am.add_me(pair.shot_1, pair.shot_2, seed=(0.85, 0.6))
    assert result.ok
