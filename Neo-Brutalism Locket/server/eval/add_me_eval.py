"""Run `add_me` on real pairs and write a side-by-side sheet per pair.

Put pairs in server/eval/add_me_pairs/ as NAME_1.jpg (group, holder missing) and NAME_2.jpg
(holder standing in). Then:  python -m eval.add_me_eval
Output goes to server/eval/out/add_me/: NAME.jpg = [shot 1 | shot 2 | result] or the refusal
reason on the sheet, plus summary.txt. Look at the sheets; the verdict is whether you can spot the join.
"""
from __future__ import annotations

import sys
from pathlib import Path

import cv2
import numpy as np

from eval.add_me import add_me

HERE = Path(__file__).parent
PAIRS = HERE / "add_me_pairs"
OUT = HERE / "out" / "add_me"


def _panel(img: np.ndarray, height: int = 480) -> np.ndarray:
    scale = height / img.shape[0]
    return cv2.resize(img, (round(img.shape[1] * scale), height), interpolation=cv2.INTER_AREA)


def main() -> int:
    firsts = sorted(PAIRS.glob("*_1.jpg"))
    if not firsts:
        print(f"No pairs in {PAIRS}. See docs/HUONG_DAN_CHUP_CAP_ANH.md.")
        return 1
    OUT.mkdir(parents=True, exist_ok=True)
    lines = []
    for first in firsts:
        name = first.name[:-6]
        second = PAIRS / f"{name}_2.jpg"
        if not second.exists():
            lines.append(f"{name}: missing {second.name}")
            continue
        a, b = cv2.imread(str(first)), cv2.imread(str(second))
        result = add_me(a, b)
        third = result.image if result.ok else np.zeros_like(a)
        sheet = np.hstack([_panel(a), _panel(b), _panel(third)])
        if not result.ok:
            cv2.putText(sheet, f"REFUSED: {result.reason}", (sheet.shape[1] - 460, 260),
                        cv2.FONT_HERSHEY_SIMPLEX, 0.9, (255, 255, 255), 2)
        cv2.imwrite(str(OUT / f"{name}.jpg"), sheet)
        keep = {k: (round(v, 3) if isinstance(v, float) else v) for k, v in result.info.items()}
        lines.append(f"{name}: {'ok' if result.ok else 'refused ' + str(result.reason)}  {keep}")
    (OUT / "summary.txt").write_text("\n".join(lines) + "\n", encoding="utf-8")
    print("\n".join(lines))
    return 0


if __name__ == "__main__":
    sys.exit(main())
