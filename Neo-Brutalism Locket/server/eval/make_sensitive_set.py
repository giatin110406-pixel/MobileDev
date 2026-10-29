"""Make the labelled photo set the "check before posting" feature (session E) is measured on.

Until ~100 real photos are collected this stands in for them: Vietnamese private details drawn
the way they appear in photos (an ID card on a table, a phone number on a shop sign, a car or
motorbike plate, a house-number plate, a bank card) on the AI-made empty scenes in
gen_ai_photos_test/background, plus photos that must NOT be flagged (the scenes and portraits as
they are, and signs with prices, opening hours, dates and wifi names). Every positive is pasted
at a random size, tilt and place, then blurred, lit and JPEG-compressed like a phone photo.

All names and numbers are made up. CCCD numbers start with a real province prefix so they have
the right shape, bank card numbers pass the Luhn check like real ones do.

Output: <out>/<name>.jpg and <out>/manifest.json = {name: [expected kinds]}; kinds are the Dart
SensitiveKind names. Usage, from server/:

    .venv/Scripts/python.exe -m eval.make_sensitive_set --photos ../gen_ai_photos_test --out D:/clip_eval_tmp/sensitive_set
"""
from __future__ import annotations

import argparse
import json
import random
from pathlib import Path

from PIL import Image, ImageDraw, ImageEnhance, ImageFilter, ImageFont

FONT = "C:/Windows/Fonts/arial.ttf"
BOLD = "C:/Windows/Fonts/arialbd.ttf"
SIDE = 1024
PER_KIND = 10

SURNAMES = ["NGUYỄN", "TRẦN", "LÊ", "PHẠM", "HOÀNG", "VŨ", "ĐẶNG", "BÙI"]
NAMES = ["VĂN AN", "THỊ BÌNH", "MINH CHÂU", "QUỐC DŨNG", "THU HÀ", "GIA HUY", "NGỌC LAN"]
STREETS = ["Phố Huế", "Lê Lợi", "Nguyễn Trãi", "Hai Bà Trưng", "Lý Thường Kiệt", "Trần Phú"]
SHOPS = ["TIỆM BÁNH MÌ", "SỬA XE MÁY", "CƠM TẤM", "TẠP HÓA", "PHỞ BÒ", "CẮT TÓC"]


def font(size: int, bold: bool = False) -> ImageFont.FreeTypeFont:
    return ImageFont.truetype(BOLD if bold else FONT, size)


def luhn_number(rng: random.Random) -> str:
    digits = [4] + [rng.randrange(10) for _ in range(14)]
    total = 0
    for i, d in enumerate(reversed(digits)):
        if i % 2 == 0:
            d *= 2
            d -= 9 if d > 9 else 0
        total += d
    digits.append((10 - total % 10) % 10)
    s = "".join(map(str, digits))
    return " ".join(s[i:i + 4] for i in range(0, 16, 4))


def phone(rng: random.Random) -> str:
    n = rng.choice(["09", "08", "07", "03"]) + "".join(str(rng.randrange(10)) for _ in range(8))
    return rng.choice([f"{n[:4]} {n[4:7]} {n[7:]}", f"{n[:4]}.{n[4:7]}.{n[7:]}", n])


def id_card(rng: random.Random) -> Image.Image:
    card = Image.new("RGB", (856, 540), (232, 240, 236))
    d = ImageDraw.Draw(card)
    d.rectangle([0, 0, 855, 539], outline=(120, 140, 130), width=4)
    d.text((428, 30), "CỘNG HÒA XÃ HỘI CHỦ NGHĨA VIỆT NAM", font=font(30, True), fill=(20, 20, 20), anchor="mt")
    d.text((428, 70), "Độc lập - Tự do - Hạnh phúc", font=font(24), fill=(20, 20, 20), anchor="mt")
    d.text((470, 115), "CĂN CƯỚC CÔNG DÂN", font=font(40, True), fill=(170, 30, 30), anchor="mt")
    number = "0" + rng.choice(["01", "79", "48", "31"]) + "".join(str(rng.randrange(10)) for _ in range(9))
    d.text((300, 180), f"Số / No.: {number}", font=font(32, True), fill=(20, 20, 20))
    d.rectangle([40, 170, 260, 450], fill=(190, 200, 205))  # the photo
    name = f"{rng.choice(SURNAMES)} {rng.choice(NAMES)}"
    rows = ["Họ và tên / Full name:", name, f"Ngày sinh / Date of birth: {rng.randint(1, 28):02d}/{rng.randint(1, 12):02d}/{rng.randint(1970, 2006)}",
            "Quốc tịch / Nationality: Việt Nam"]
    for i, row in enumerate(rows):
        d.text((300, 240 + i * 50), row, font=font(26, i == 1), fill=(20, 20, 20))
    return card


def shop_sign(rng: random.Random, with_phone: bool) -> Image.Image:
    colours = [(200, 40, 40), (30, 90, 170), (240, 200, 40), (30, 130, 70)]
    bg = rng.choice(colours)
    fg = (20, 20, 20) if bg == (240, 200, 40) else (250, 250, 250)
    sign = Image.new("RGB", (900, 320), bg)
    d = ImageDraw.Draw(sign)
    d.text((450, 60), rng.choice(SHOPS), font=font(80, True), fill=fg, anchor="mt")
    line = f"ĐT: {phone(rng)}" if with_phone else rng.choice(
        ["Giờ mở cửa 7:00 - 22:00", "Cà phê sữa 25.000đ", "Ngày 29/10/2026", "Wifi: cafe2026", "Giảm giá 20%"])
    d.text((450, 200), line, font=font(62, True), fill=fg, anchor="mt")
    return sign


def car_plate(rng: random.Random) -> Image.Image:
    plate = Image.new("RGB", (520, 115), (245, 245, 245))
    d = ImageDraw.Draw(plate)
    d.rectangle([0, 0, 519, 114], outline=(10, 10, 10), width=6)
    text = f"{rng.randint(11, 99)}{rng.choice('ABCDEFGHKLM')}-{rng.randint(100, 999)}.{rng.randint(10, 99)}"
    d.text((260, 58), text, font=font(84, True), fill=(10, 10, 10), anchor="mm")
    return plate


def bike_plate(rng: random.Random) -> Image.Image:
    plate = Image.new("RGB", (300, 220), (245, 245, 245))
    d = ImageDraw.Draw(plate)
    d.rectangle([0, 0, 299, 219], outline=(10, 10, 10), width=6)
    top = f"{rng.randint(11, 99)}-{rng.choice('ABCDEFGHKLMNPSTUVX')}{rng.randint(1, 9)}"
    d.text((150, 60), top, font=font(78, True), fill=(10, 10, 10), anchor="mm")
    d.text((150, 160), f"{rng.randint(100, 999)}.{rng.randint(10, 99)}", font=font(78, True), fill=(10, 10, 10), anchor="mm")
    return plate


def house_plate(rng: random.Random) -> Image.Image:
    plate = Image.new("RGB", (560, 300), (20, 70, 160))
    d = ImageDraw.Draw(plate)
    d.rectangle([8, 8, 551, 291], outline=(250, 250, 250), width=5)
    d.text((280, 110), f"SỐ NHÀ {rng.randint(1, 199)}", font=font(76, True), fill=(250, 250, 250), anchor="mm")
    d.text((280, 215), f"Ngõ {rng.randint(2, 99)} {rng.choice(STREETS)}", font=font(46, True), fill=(250, 250, 250), anchor="mm")
    return plate


def bank_card(rng: random.Random) -> Image.Image:
    card = Image.new("RGB", (856, 540), (30, 50, 110))
    d = ImageDraw.Draw(card)
    d.text((60, 60), "NGÂN HÀNG TMCP", font=font(40, True), fill=(240, 240, 240))
    d.rectangle([60, 170, 180, 260], fill=(210, 180, 90))  # chip
    d.text((60, 320), luhn_number(rng), font=font(64, True), fill=(240, 240, 240))
    d.text((60, 430), f"{rng.choice(SURNAMES)} {rng.choice(NAMES)}", font=font(36), fill=(240, 240, 240))
    return card


def paste(scene: Image.Image, thing: Image.Image, rng: random.Random, width: tuple[float, float]) -> Image.Image:
    """Put `thing` somewhere in `scene` at a random size (fraction of the photo width) and tilt."""
    w = int(SIDE * rng.uniform(*width))
    h = int(thing.height * w / thing.width)
    thing = thing.resize((w, h), Image.LANCZOS).convert("RGBA")
    thing = thing.rotate(rng.uniform(-8, 8), expand=True, resample=Image.BICUBIC)
    x = rng.randint(0, max(0, SIDE - thing.width))
    y = rng.randint(0, max(0, SIDE - thing.height))
    out = scene.copy()
    out.paste(thing, (x, y), thing)
    return out


def camera(img: Image.Image, rng: random.Random) -> Image.Image:
    img = img.filter(ImageFilter.GaussianBlur(rng.uniform(0, 1.2)))
    img = ImageEnhance.Brightness(img).enhance(rng.uniform(.7, 1.15))
    img = ImageEnhance.Contrast(img).enhance(rng.uniform(.85, 1.1))
    return img


def main() -> None:
    ap = argparse.ArgumentParser()
    ap.add_argument("--photos", type=Path, required=True)
    ap.add_argument("--out", type=Path, required=True)
    ap.add_argument("--seed", type=int, default=7)
    args = ap.parse_args()
    rng = random.Random(args.seed)
    args.out.mkdir(parents=True, exist_ok=True)
    scenes = [Image.open(p).convert("RGB").resize((SIDE, SIDE), Image.LANCZOS)
              for p in sorted((args.photos / "background").glob("*.jpg"))]
    people = [Image.open(p).convert("RGB").resize((SIDE, SIDE), Image.LANCZOS)
              for p in sorted((args.photos / "person").glob("*.jpg"))]
    manifest: dict[str, list[str]] = {}

    def save(name: str, img: Image.Image, kinds: list[str]) -> None:
        camera(img, rng).save(args.out / f"{name}.jpg", quality=rng.randint(80, 92))
        manifest[name] = kinds

    makers = [
        ("idcard", id_card, (.55, .9), ["idDocument", "idNumber"]),
        ("phone", lambda r: shop_sign(r, True), (.5, .85), ["phone"]),
        ("carplate", car_plate, (.3, .55), ["plate"]),
        ("bikeplate", bike_plate, (.22, .4), ["plate"]),
        ("house", house_plate, (.35, .6), ["address"]),
        ("bankcard", bank_card, (.5, .85), ["card"]),
    ]
    for prefix, make, width, kinds in makers:
        for i in range(PER_KIND):
            save(f"{prefix}_{i:02d}", paste(rng.choice(scenes), make(rng), rng, width), kinds)
    for i, scene in enumerate(scenes):
        save(f"clean_scene_{i:02d}", scene, [])
    for i, person in enumerate(people):
        save(f"clean_person_{i:02d}", person, [])
    for i in range(PER_KIND):
        save(f"clean_sign_{i:02d}", paste(rng.choice(scenes), shop_sign(rng, False), rng, (.5, .85)), [])
    (args.out / "manifest.json").write_text(json.dumps(manifest, ensure_ascii=False, indent=1), encoding="utf-8")
    print(f"{len(manifest)} photos -> {args.out}")


if __name__ == "__main__":
    main()
