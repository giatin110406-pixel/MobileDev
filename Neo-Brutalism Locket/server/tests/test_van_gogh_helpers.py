import numpy as np
from PIL import Image

from locket_server import face_landmarks, preprocess
from locket_server.van_gogh import color_anchor, match_color, pick_reference

CFG = {
    "references": {"portrait": ["a.jpg", "b.jpg"], "bright_scene": "day.jpg",
                   "dark_scene": ["night.jpg"], "sky": ["sky.jpg"]},
    "dark_luma_threshold": 0.35,
    "sky_threshold": 0.35,
}


def test_pick_reference_by_scene_and_seed():
    assert pick_reference(CFG, True, 0.5, 0) == "a.jpg"
    assert pick_reference(CFG, True, 0.5, 1) == "b.jpg"
    assert pick_reference(CFG, False, 0.2) == "night.jpg"
    assert pick_reference(CFG, False, 0.6, sky=0.5) == "sky.jpg"
    assert pick_reference(CFG, False, 0.6, sky=0.1) == "day.jpg"


def test_sky_only_when_threshold_set():
    cfg = dict(CFG, sky_threshold=None)
    assert pick_reference(cfg, False, 0.6, sky=0.9) == "day.jpg"


def test_color_anchor_pulls_colour_back_keeps_brightness():
    photo = Image.new("RGB", (64, 64), (30, 30, 30))       # black hair
    painted = Image.new("RGB", (64, 64), (20, 40, 160))    # painted cobalt
    out = np.asarray(color_anchor(painted, photo, 1.0, 0.05), np.float32)
    assert abs(out[..., 2].mean() - out[..., 0].mean()) < 20   # no longer blue
    assert out.mean() < 90                                      # still dark


def test_match_color_moves_patch_toward_target():
    patch = Image.new("RGB", (32, 32), (220, 180, 160))
    target = Image.new("RGB", (32, 32), (180, 140, 90))
    out = np.asarray(match_color(patch, target, None, 1.0), np.float32)
    assert np.abs(out.mean(axis=(0, 1)) - (180, 140, 90)).max() < 6


def test_shape_deviation_ignores_pose_and_scale():
    rng = np.random.default_rng(0)
    points = rng.uniform(0, 100, (478, 2)).astype(np.float32)
    angle = 0.3
    rot = np.array([[np.cos(angle), -np.sin(angle)], [np.sin(angle), np.cos(angle)]])
    moved = (points @ rot.T) * 1.7 + 40
    assert face_landmarks.shape_deviation(points, moved) < 1e-3
    bent = points.copy()
    bent[61] += 15   # one mouth corner moved
    assert face_landmarks.shape_deviation(points, bent) > 0.05


def test_sky_fraction():
    sky = Image.new("RGB", (100, 100), (120, 170, 235))
    wall = Image.new("RGB", (100, 100), (200, 120, 60))
    assert preprocess.sky_fraction(sky) > 0.9
    assert preprocess.sky_fraction(wall) == 0.0


def test_output_check_flags_partial_faults_only():
    import numpy as np
    from locket_server import output_check as oc

    rng = np.random.default_rng(1)
    gradient = np.tile(np.linspace(90, 220, 256, dtype=np.uint8), (256, 1))
    photo = Image.fromarray(np.stack([gradient] * 3, axis=2)).resize((512, 512))
    assert not oc.is_broken(photo, photo)
    dark = Image.new("RGB", (512, 512), (4, 4, 4))   # a dark photo that stays dark is fine
    assert not oc.is_broken(dark, dark)

    black = np.asarray(photo).copy()
    black[:320, :320] = 0
    assert oc.is_broken(Image.fromarray(black), photo)
    noisy = np.asarray(photo).copy()
    noisy[:, 400:] = rng.integers(0, 255, (512, 112, 3))
    assert oc.is_broken(Image.fromarray(noisy), photo)


def test_upscale_check_catches_one_garbage_block():
    import numpy as np
    from locket_server import output_check as oc

    rng = np.random.default_rng(2)
    small = Image.fromarray(rng.integers(60, 200, (320, 320, 3), dtype=np.uint8)).filter(
        __import__("PIL.ImageFilter", fromlist=["x"]).GaussianBlur(6))
    big = small.resize((640, 640), Image.BICUBIC)
    assert not oc.upscale_broken(big, small)
    a = np.asarray(big).copy()
    a[440:600, 360:620] = rng.integers(0, 255, (160, 260, 3))
    assert oc.upscale_broken(Image.fromarray(a), small)


def test_phone_scene_replaces_the_rules_but_not_a_face():
    # a lit street at night is "bright" for the rules; the phone saw night
    assert pick_reference(CFG, False, 0.6, scene="night") == "night.jpg"
    assert pick_reference(CFG, False, 0.6, sky=0.1, scene="sky") == "sky.jpg"
    # a white wall at the top looks like sky to the rules; the phone saw a room
    assert pick_reference(CFG, False, 0.6, sky=0.9, scene="day") == "day.jpg"
    # a face found by the server still means the portrait set
    assert pick_reference(CFG, True, 0.2, 0, scene="night") == "a.jpg"
    # portrait/group without a face, unknown or missing values: the old rules
    for scene in ("portrait", "group", "beach", None):
        assert pick_reference(CFG, False, 0.2, scene=scene) == "night.jpg"
