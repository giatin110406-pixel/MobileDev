"""Sums up integration_test/sensitive_eval_test.dart: per kind, how many photos that show it were
caught (recall), and how many photos were flagged for something they do not show. Usage:

    python -m eval.sensitive_report D:/clip_eval_tmp/sensitive_eval_emulator.log
"""
from __future__ import annotations

import json
import statistics
import sys
from collections import Counter


def main(path: str) -> None:
    rows = [json.loads(line.split("SENSITIVE_ROW ", 1)[1]) for line in open(path, encoding="utf-8")
            if "SENSITIVE_ROW " in line]
    kinds = sorted({k for r in rows for k in r["expected"]})
    print(f"{len(rows)} photos, median {statistics.median(r['ms'] for r in rows):.0f} ms each "
          f"(max {max(r['ms'] for r in rows)} ms)")
    for kind in kinds:
        with_it = [r for r in rows if kind in r["expected"]]
        caught = sum(kind in r["found"] for r in with_it)
        print(f"  {kind:11s} caught {caught}/{len(with_it)}")
    clean = [r for r in rows if not r["expected"]]
    flagged = [r for r in clean if r["found"]]
    print(f"  clean photos flagged: {len(flagged)}/{len(clean)}")
    wrong = Counter(k for r in rows for k in r["found"] if k not in r["expected"])
    print(f"  extra kinds on any photo: {dict(wrong)}")
    for r in rows:
        missed = [k for k in r["expected"] if k not in r["found"]]
        extra = [k for k in r["found"] if k not in r["expected"]]
        if missed or extra:
            print(f"    {r['name']}: missed {missed} extra {extra} read {r['read']}")


if __name__ == "__main__":
    main(sys.argv[1])
