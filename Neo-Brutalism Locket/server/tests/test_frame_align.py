"""`frame_align`: which way to move the phone to get back to the locked frame, on pictures made
here (so the answer is known). How it copes with real rooms is measured by
`python -m eval.frame_align_eval` and, later, on real pairs."""
import numpy as np
import pytest

cv2 = pytest.importorskip("cv2")

from eval import frame_align as fa  # noqa: E402
from eval.frame_align_synth import Truth, flat_picture, make_pair  # noqa: E402

SIDE = 480


def scene(seed: int, size: int = 1500) -> np.ndarray:
    """A made-up room: coloured shapes and lines on a gradient, enough corners to match on."""
    rng = np.random.default_rng(seed)
    yy, xx = np.mgrid[0:size, 0:size].astype(np.float32)
    base = np.stack(
        [128 + 60 * np.sin(xx / 170 + seed), 128 + 60 * np.cos(yy / 130), 128 + 40 * np.sin((xx + yy) / 220)],
        axis=2,
    ).astype(np.uint8)
    for _ in range(260):
        colour = tuple(int(c) for c in rng.integers(0, 255, 3))
        x, y = (int(v) for v in rng.integers(0, size, 2))
        kind = rng.integers(0, 3)
        if kind == 0:
            cv2.circle(base, (x, y), int(rng.integers(6, 40)), colour, -1)
        elif kind == 1:
            cv2.rectangle(base, (x, y), (x + int(rng.integers(10, 70)), y + int(rng.integers(10, 70))), colour, -1)
        else:
            cv2.line(base, (x, y), (x + int(rng.integers(-90, 90)), y + int(rng.integers(-90, 90))), colour, 3)
    return cv2.GaussianBlur(base, (0, 0), 0.8)


def estimate(truth: Truth, seed: int = 1, **kw) -> fa.Alignment:
    pair = make_pair(scene(seed), truth, side=SIDE, rng=np.random.default_rng(seed), **kw)
    return fa.estimate(pair.locked, pair.current)


def test_the_same_view_is_aligned():
    pair = make_pair(scene(1), Truth(0, 0, 0, 1), side=SIDE)
    result = fa.estimate(pair.locked, pair.current)
    assert result.ok
    assert fa.guidance(result).state == "aligned"


@pytest.mark.parametrize(
    "truth, horizontal, vertical",
    [
        (Truth(0.15, 0, 0, 1), "right", None),
        (Truth(-0.15, 0, 0, 1), "left", None),
        (Truth(0, 0.15, 0, 1), None, "down"),
        (Truth(0, -0.15, 0, 1), None, "up"),
        (Truth(-0.1, 0.2, 0, 1), "left", "down"),
    ],
)
def test_the_arrow_points_the_way_the_view_must_move(truth, horizontal, vertical):
    result = estimate(truth)
    assert result.ok
    g = fa.guidance(result)
    assert g.state == "adjust"
    assert g.horizontal == horizontal and g.vertical == vertical
    # The numbers are close too, not only the signs.
    assert abs(result.dx - truth.dx) < 0.02 and abs(result.dy - truth.dy) < 0.02


def test_roll_and_distance():
    assert fa.guidance(estimate(Truth(0, 0, 10, 1))).roll == "clockwise"
    assert fa.guidance(estimate(Truth(0, 0, -10, 1))).roll == "counterclockwise"
    # The locked scene looks bigger now: too close, step back.
    assert fa.guidance(estimate(Truth(0, 0, 0, 1.15))).distance == "back"
    assert fa.guidance(estimate(Truth(0, 0, 0, 0.87))).distance == "closer"


def test_a_different_exposure_and_a_little_blur_still_match():
    result = estimate(Truth(0.12, -0.08, 5, 1.05), brightness=0.8, blur=1.2, noise=4, jpeg_quality=60)
    assert result.ok
    g = fa.guidance(result)
    assert (g.horizontal, g.vertical) == ("right", "up")


def test_a_blank_wall_is_not_guessed_at():
    rng = np.random.default_rng(3)
    result = fa.estimate(flat_picture(SIDE, SIDE, rng), flat_picture(SIDE, SIDE, rng))
    assert not result.ok
    assert fa.guidance(result).state == "unsure"


def test_another_scene_is_not_recognised():
    a = scene(1)[: SIDE, : SIDE]
    b = scene(2)[: SIDE, : SIDE]
    result = fa.estimate(a, b)
    assert not result.ok and result.reason in (fa.REASON_NO_MATCH, fa.REASON_FEW_FEATURES)


def test_someone_walking_through_does_not_throw_it_off():
    other = scene(5)
    pair = make_pair(
        scene(1),
        Truth(0.1, 0.1, 0, 1),
        side=SIDE,
        occlusion=0.1,
        mover=0.1,
        intruder=other,
        rng=np.random.default_rng(4),
    )
    result = fa.estimate(pair.locked, pair.current)
    assert result.ok
    g = fa.guidance(result)
    assert (g.horizontal, g.vertical) == ("right", "down")


def test_when_too_much_is_hidden_it_says_unsure_rather_than_pointing_wrong():
    # Over a third of the frame is someone else's: either the arrows are right or it does not say.
    other = scene(5)
    wrong = 0
    for seed in range(8):
        pair = make_pair(
            scene(1),
            Truth(0.15, -0.12, 0, 1),
            side=SIDE,
            occlusion=0.35,
            mover=0.2,
            intruder=other,
            rng=np.random.default_rng(seed),
        )
        result = fa.estimate(pair.locked, pair.current)
        if result.ok:
            g = fa.guidance(result)
            wrong += (g.horizontal, g.vertical) != ("right", "up")
    assert wrong == 0
