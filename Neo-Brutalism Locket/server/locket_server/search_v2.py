"""Photo search, server side (search-v2-plan.md, "Decision on speed").

Two steps, both measured in server/eval (tags AND VLM >= 0.8: 3.6-4.4 % wrong photos on COCO):

1. Tags, written once per photo when it is posted: a vision-language model lists the objects it
   sees and describes the scene. A search term matches a photo when the term (or a synonym) is in
   those words.
2. Check, asked once per (photo, term) and cached: the same model answers "Is there a <term>
   clearly visible?" with a probability. Only photos whose tags match are asked.

A photo is shown when the tags match AND the check is >= THRESHOLD. Nothing is shown otherwise.
The model is injected (a callable), so this module runs without a GPU.
"""
from __future__ import annotations

import math
from dataclasses import dataclass, field
from typing import Callable, Iterable

from locket_server.search_terms import has_term

THRESHOLD = 0.8

# Original detailed prompt is retained for reproducibility. In a partial 88-photo run it
# repeatedly generated one noun until the token budget; see search-v2-plan.md.
DETAILED_TAG_PROMPT = (
    "List every object you can see in this photo as a comma-separated list of common English "
    "nouns. Include people, animals, food, drinks, furniture, vehicles, devices, plants, clothes, "
    "bags, and small items on tables or shelves, even when they are small or partly hidden. "
    "Then write one short sentence describing the scene.\n"
    "Format:\nObjects: a, b, c\nScene: ..."
)

# Revised candidate retained for reproducing the comparison, not selected for app indexing.
REVISED_TAG_PROMPT = (
    "Describe only what is visibly present in this photo. List the visible object types as "
    "common English nouns, including small objects you can identify. Name each object type "
    "only once. Do not guess hidden objects. Then write one short sentence about the scene. "
    "Use exactly two lines:\nObjects: a, b, c\nScene: ..."
)

# The short prompt gave fewer misses (23.3% vs 26.6%) at essentially the same wrong share
# (~4.4% vs ~4.3%) in the fresh bf16 comparison. Keep it as the indexing default.
TAG_PROMPT = (
    "List every object you can see in this photo as a comma-separated list of common "
    "English nouns (people, animals, food, furniture, vehicles, devices, small items too). "
    "Then write one short sentence describing the scene. Format:\n"
    "Objects: a, b, c\nScene: ..."
)

# Asks the model for a probability that the term is clearly visible in the photo.
CHECK_PROMPT = "Is there a {term} clearly visible in this photo? Answer Yes or No."

# (photo_id, term) -> probability, or None when the model could not answer.
Asker = Callable[[list[tuple[str, str]]], list[float | None]]


def check_shows(tagged: bool, probability: float | None, threshold: float = THRESHOLD) -> bool:
    """The rule: tags match AND the check is confident. A NaN or missing answer never shows."""
    if not math.isfinite(threshold) or not 0 <= threshold <= 1:
        raise ValueError('threshold must be a finite probability between 0 and 1')
    if (not tagged or probability is None or not math.isfinite(probability)
            or not 0 <= probability <= 1):
        return False
    return probability >= threshold


@dataclass
class CheckCache:
    """Answers already given, so the model is asked once per (photo, term)."""

    answers: dict[tuple[str, str], float | None] = field(default_factory=dict)

    def ensure(self, pairs: Iterable[tuple[str, str]], ask: Asker, batch: int = 8) -> None:
        if batch < 1:
            raise ValueError('batch must be positive')
        todo = [p for p in dict.fromkeys(pairs) if p not in self.answers]
        for start in range(0, len(todo), batch):
            chunk = todo[start:start + batch]
            values = ask(chunk)
            if len(values) != len(chunk):
                raise ValueError('Asker must return one answer per pair')
            for pair, value in zip(chunk, values):
                self.answers[pair] = value

    def get(self, photo_id: str, term: str) -> float | None:
        return self.answers.get((photo_id, term))


def search(term: str, tags: dict[str, str], cache: CheckCache, ask: Asker,
           threshold: float = THRESHOLD) -> list[str]:
    """Photo ids to show for one search term, in the order of [tags].

    [tags] maps photo id -> the tag text written at posting time. Photos whose tags do not name the
    term are never asked about, which is what keeps a search cheap.
    """
    tagged = [pid for pid, text in tags.items() if has_term(text.lower(), term)]
    cache.ensure(((pid, term) for pid in tagged), ask)
    return [pid for pid in tagged if check_shows(True, cache.get(pid, term), threshold)]


def check_prompt(term: str) -> str:
    return CHECK_PROMPT.format(term=term)
