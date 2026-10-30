"""Compare old/detailed tags with full bf16 checks, without a retrieval top-K cap.

From server/: PYTHONPATH=.eval_tools .venv/Scripts/python.exe -m eval.compare_tags
Resumable caches fingerprint data, prompts, model and generation settings.
Legacy fp16 check caches are deliberately not reused.
"""
from __future__ import annotations

import argparse
import hashlib
import json
import math
import re
import time
from pathlib import Path

import torch  # before pyarrow on Windows
import numpy as np

from eval import search_fp_eval as ev
from eval.index_tags import PROMPT as OLD_PROMPT, describe, load_vlm
from eval.vlm_recheck import pool_indices, load_vlm as load_checker, p_yes
from locket_server.search_terms import has_term
from locket_server.search_v2 import REVISED_TAG_PROMPT, CHECK_PROMPT, THRESHOLD


def fingerprint(value) -> str:
    return hashlib.sha256(json.dumps(value, sort_keys=True).encode()).hexdigest()[:16]


def save(path: Path, value) -> None:
    temp = path.with_suffix('.tmp')
    temp.write_text(json.dumps(value, ensure_ascii=False, allow_nan=False), encoding='utf-8')
    temp.replace(path)


def tag_matrix(tags):
    return np.array([[has_term(text.lower(), ev.CATEGORIES[c][0]) for c in ev.IDS]
                     for text in tags], dtype=bool)


def metrics(truth, shown, libraries):
    """Baseline accounting: tiny-only queries are excluded, not labelled absent."""
    shown_n = wrong_n = pos_n = miss_n = qneg = qempty = qpos = qwrong = 0
    for idx in libraries:
        t, s = truth[idx], shown[idx]
        for ci, c in enumerate(ev.IDS):
            has, absent = t[:, c] >= ev.MIN_AREA, t[:, c] == 0
            if not has.any():
                if absent.all():
                    qneg += 1
                    qempty += int(not s[:, ci].any())
                continue
            qpos += 1
            wrong = int((s[:, ci] & absent).sum())
            shown_n += int(s[:, ci].sum())
            wrong_n += wrong
            qwrong += int(wrong > 0)
            pos_n += int(has.sum())
            miss_n += int((has & ~s[:, ci]).sum())
    return dict(wrong=wrong_n / shown_n if shown_n else None,
                missed=miss_n / pos_n if pos_n else None,
                empty=qempty / qneg if qneg else None,
                q_wrong=qwrong / qpos if qpos else None,
                shown=shown_n, wrong_count=wrong_n, positives=pos_n,
                missed_count=miss_n, queries=qpos, no_answer=qneg, empty_count=qempty)


def absent_stress(truth, shown, size=None, draws=30, seed=7):
    """Deliberately absent queries, including common categories random draws rarely omit.

size=None uses every completely negative photo for each term, so library sizes vary.
This is a stress test, separate from the randomly sampled baseline protocol.
"""
    rng = np.random.default_rng(seed)
    queries = empty = 0
    sizes = []
    failed = set()
    for ci, c in enumerate(ev.IDS):
        negatives = np.flatnonzero(truth[:, c] == 0)
        if not len(negatives) or (size is not None and len(negatives) < size):
            continue
        libraries = ([negatives] if size is None else
                     [rng.choice(negatives, size, replace=False) for _ in range(draws)])
        for idx in libraries:
            queries += 1
            sizes.append(len(idx))
            if shown[idx, ci].any():
                failed.add(ev.CATEGORIES[c][0])
            else:
                empty += 1
    return dict(empty=empty / queries if queries else None, queries=queries,
                empty_count=empty, failed_terms=sorted(failed),
                min_size=min(sizes) if sizes else None, max_size=max(sizes) if sizes else None)


def main():
    ap = argparse.ArgumentParser(description=__doc__)
    ap.add_argument('--vlm', default='Qwen/Qwen2-VL-2B-Instruct')
    ap.add_argument('--batch', type=int, default=8)
    ap.add_argument('--draws', type=int, default=30)
    ap.add_argument('--offline', action='store_true', help='require local model files')
    args = ap.parse_args()
    if args.batch < 1 or args.draws < 1:
        ap.error('batch and draws must be positive')
    if args.offline:
        import os
        os.environ['HF_HUB_OFFLINE'] = '1'
        os.environ['TRANSFORMERS_OFFLINE'] = '1'
    raws, truth = ev.load_coco()
    idx = pool_indices(len(raws))
    truth = truth[idx]
    data_id = fingerprint([hashlib.sha256(raws[i]).hexdigest() for i in idx])
    ev.CACHE.mkdir(parents=True, exist_ok=True)
    tag_sets = {}
    tag_quality = {}
    for label, prompt in [('old', OLD_PROMPT), ('detailed', REVISED_TAG_PROMPT)]:
        # Same generation budget for both prompts: only wording differs.
        meta = dict(data=data_id, model=args.vlm, prompt=prompt, dtype='bf16',
                    max_pixels=448*28*28, max_new_tokens=220, batch=args.batch)
        path = ev.CACHE / f'tags_{label}_{fingerprint(meta)}.json'
        doc = json.loads(path.read_text(encoding='utf-8')) if path.exists() else dict(meta=meta, tags=[])
        if doc['meta'] != meta:
            raise ValueError(f'Cache metadata mismatch: {path}')
        tags = doc['tags']
        if len(tags) < len(idx):
            proc, model = load_vlm(args.vlm)
            start = time.monotonic()
            for b in range(len(tags), len(idx), args.batch):
                images = [ev.pil(raws[i]) for i in idx[b:b+args.batch]]
                generated = describe(proc, model, images, prompt)
                if len(generated) != len(images):
                    raise ValueError('Tagger returned a different number of answers than photos')
                tags.extend(generated)
                save(path, doc)
                print(f'{label} tags {len(tags)}/{len(idx)} elapsed {time.monotonic()-start:.0f}s', flush=True)
            del proc, model
            torch.cuda.empty_cache()
        tag_sets[label] = tag_matrix(tags)
        tag_quality[label] = dict(
            count=len(tags), missing_scene=sum('Scene:' not in text for text in tags),
            repeated_noun=sum(bool(re.search(r'\b(\w+)(?:,\s*\1){5}', text, re.I)) for text in tags))

    required = np.logical_or.reduce(list(tag_sets.values()))
    meta = dict(data=data_id, model=args.vlm, prompt=CHECK_PROMPT, dtype='bf16',
                max_pixels=320*28*28, categories=[ev.CATEGORIES[c][0] for c in ev.IDS])
    path = ev.CACHE / f'checks_bf16_{fingerprint(meta)}.json'
    doc = json.loads(path.read_text(encoding='utf-8')) if path.exists() else dict(meta=meta, answers={})
    if doc['meta'] != meta:
        raise ValueError(f'Cache metadata mismatch: {path}')
    answers = doc['answers']
    pairs = [(int(i), int(ci)) for i, ci in zip(*np.where(required))]
    todo = [(i, ci) for i, ci in pairs if f'{i}:{ci}' not in answers]
    print(f'Checks: {len(pairs)} required, {len(todo)} uncached', flush=True)
    if todo:
        proc, model, yes, no = load_checker(args.vlm)
        start = time.monotonic()
        for b in range(0, len(todo), args.batch):
            chunk = todo[b:b+args.batch]
            values = p_yes(proc, model, yes, no,
                           [ev.pil(raws[idx[i]]) for i, _ in chunk],
                           [ev.CATEGORIES[ev.IDS[ci]][0] for _, ci in chunk])
            if len(values) != len(chunk):
                raise ValueError('Checker returned a different number of answers than questions')
            for (i, ci), value in zip(chunk, values):
                answers[f'{i}:{ci}'] = value if math.isfinite(value) and 0 <= value <= 1 else None
            save(path, doc)
            if b % (args.batch*10) == 0:
                print(f'Checks {b+len(chunk)}/{len(todo)} elapsed {time.monotonic()-start:.0f}s', flush=True)
        del proc, model
        torch.cuda.empty_cache()
    p = np.full(required.shape, np.nan)
    for i, ci in pairs:
        value = answers[f'{i}:{ci}']
        if value is not None:
            p[i, ci] = value
    report = dict(data=data_id, pool=len(idx), draws=args.draws, seed=7,
                  invalid_checks=int((required & ~np.isfinite(p)).sum()),
                  tag_quality=tag_quality,
                  tag_prompts=dict(old=OLD_PROMPT, detailed=REVISED_TAG_PROMPT), results=[])
    report['cold_checks_per_term'] = {
        label: {ev.CATEGORIES[c][0]: int(tagged[:, ci].sum()) for ci, c in enumerate(ev.IDS)}
        for label, tagged in tag_sets.items()}
    report['absent_stress'] = []
    for label, tagged in tag_sets.items():
        for tau in (THRESHOLD, 0.9, 0.95):
            for size in (20, 60, None):
                row = dict(prompt=label, threshold=tau, size=size,
                           **absent_stress(truth, tagged & (p >= tau), size, args.draws))
                report['absent_stress'].append(row)
                print('Absent stress:', json.dumps(row), flush=True)
    print(f'Invalid checks hidden: {report["invalid_checks"]}', flush=True)
    for size in (20, 60, 300):
        rng = np.random.default_rng(7)
        libraries = ([np.arange(len(idx))] if size == len(idx) else
                     [rng.choice(len(idx), size, replace=False) for _ in range(args.draws)])
        for label, tagged in tag_sets.items():
            for tau in (None, THRESHOLD, 0.9, 0.95):
                shown = tagged if tau is None else tagged & (p >= tau)
                row = dict(prompt=label, size=size, threshold=tau, **metrics(truth, shown, libraries))
                report['results'].append(row)
                print(json.dumps(row), flush=True)
    selected = [r for r in report['results'] if r['prompt'] == 'detailed' and r['threshold'] == THRESHOLD]
    full = next(r for r in selected if r['size'] == len(idx))
    report['gates'] = dict(
        detailed_accuracy=full['wrong'] is not None and full['wrong'] <= 0.05
                          and full['missed'] is not None and full['missed'] < 0.266,
        no_answer=all(r['empty'] is not None and r['empty'] >= 0.95 for r in selected),
        no_answer_stress=all(r['empty'] is not None and r['empty'] >= 0.95
                             for r in report['absent_stress']
                             if r['prompt'] == 'detailed' and r['threshold'] == THRESHOLD),
        name_only='see Flutter photo_search_test: name-only never calls the photo encoder',
        vietnamese='not measured', real_photos='not measured')
    report['errors'] = {}
    for label, tagged in tag_sets.items():
        shown = tagged & (p >= THRESHOLD)
        errors = []
        for ci, c in enumerate(ev.IDS):
            for i in range(len(idx)):
                has, absent = truth[i, c] >= ev.MIN_AREA, truth[i, c] == 0
                if (shown[i, ci] and absent) or (has and not shown[i, ci]):
                    errors.append(dict(pool_index=i, coco_row=int(idx[i]), term=ev.CATEGORIES[c][0],
                                       kind='wrong' if absent else 'missed', tagged=bool(tagged[i, ci]),
                                       probability=float(p[i, ci]) if np.isfinite(p[i, ci]) else None))
        report['errors'][label] = errors
    save(ev.CACHE / 'tag_comparison_report.json', report)
    print('Gates:', json.dumps(report['gates']), flush=True)


if __name__ == '__main__':
    main()
