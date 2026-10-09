"""Reads the quest list (positives, negatives) straight from lib/features/quest/quest_catalog.dart."""
from __future__ import annotations

import re
from pathlib import Path

CATALOG = Path(__file__).resolve().parents[2] / "lib/features/quest/quest_catalog.dart"


def read_quests() -> dict[str, tuple[list[str], list[str]]]:
    """quest id -> (positives, negatives)"""
    text = CATALOG.read_text(encoding="utf-8")
    pattern = re.compile(
        r"id: '(\w+)',.*?positives: \[(.*?)\],\s*(?:negatives: \[(.*?)\],\s*)?style:", re.S)
    strings = lambda s: re.findall(r"'([^']+)'", s or "")  # noqa: E731
    return {m[1]: (strings(m[2]), strings(m[3])) for m in pattern.finditer(text)}
