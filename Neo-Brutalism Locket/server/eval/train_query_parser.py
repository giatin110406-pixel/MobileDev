"""Synthetic Vietnamese parser corpus and local LoRA training. Never sends queries to an API."""
from __future__ import annotations
import argparse
import json
from pathlib import Path
import random
import time

import torch  # before the eval's optional pyarrow import

from eval.search_fp_eval import CATEGORIES, CACHE
from locket_server.query_parser import ParseRequest, prompt_for

FRIENDS = [dict(id=f'00000000-0000-0000-0000-{i:012d}', name=name)
           for i, name in enumerate(['Lan', 'Minh', 'Hoa'], 1)]


def corpus():
    train, heldout = [], []
    for i, (en, vi) in enumerate(dict(CATEGORIES).values()):
        for variant in range(2):
            rules = dict(terms=[], friend_id=None, mine=False, from_time=None, until_time=None, name_only=False)
            text, visual = f'tìm ảnh có {vi}', vi
            if variant:
                kind = i % 4
                if kind == 0:
                    friend = FRIENDS[i % len(FRIENDS)]
                    text = f'cho mình xem ảnh {vi} với {friend["name"]}'
                    rules['friend_id'] = friend['id']
                elif kind == 1:
                    text = f'ảnh có {vi} hôm qua'
                    rules.update(from_time='2026-10-28T00:00:00+07:00', until_time='2026-10-29T00:00:00+07:00')
                elif kind == 2:
                    text = f'mình muốn tìm {vi} của tôi'
                    rules['mine'] = True
                else:
                    text = f'mình muốn xem lại những tấm hình có {vi} trong đó'
                    visual = text
            request = ParseRequest(text=text, visual_text=visual, now='2026-10-29T12:00:00+07:00',
                                   friends=FRIENDS, rules=rules)
            expected = dict(friend=rules['friend_id'], from_time=rules['from_time'],
                            until_time=rules['until_time'], mine=rules['mine'], terms=[en], name_only=False)
            row = dict(request=request.model_dump(mode='json'), expected=expected)
            (heldout if variant and i % 2 else train).append(row)
    assert len(train) == 120 and len(heldout) == 40
    assert not ({r['request']['text'] for r in train} & {r['request']['text'] for r in heldout})
    return train, heldout


def main():
    ap = argparse.ArgumentParser()
    ap.add_argument('--epochs', type=int, default=3)
    ap.add_argument('--output', type=Path, default=CACHE/'query_parser_lora')
    args = ap.parse_args()
    from transformers import AutoModelForCausalLM, AutoTokenizer
    from peft import LoraConfig, get_peft_model
    torch.manual_seed(13)
    random.seed(13)
    train, heldout = corpus()
    args.output.mkdir(parents=True, exist_ok=True)
    (args.output/'corpus.json').write_text(json.dumps(dict(train=train, heldout=heldout),
                                                    ensure_ascii=False, indent=2), encoding='utf-8')
    kwargs = dict(cache_dir=str(Path.home()/'.cache/huggingface/hub'), local_files_only=True)
    tok = AutoTokenizer.from_pretrained('Qwen/Qwen3-0.6B', **kwargs)
    model = AutoModelForCausalLM.from_pretrained('Qwen/Qwen3-0.6B', dtype=torch.bfloat16, **kwargs).cuda()
    model.config.use_cache = False
    model = get_peft_model(model, LoraConfig(r=16, lora_alpha=32, target_modules=['q_proj', 'v_proj'],
                                            lora_dropout=0.05, task_type='CAUSAL_LM'))
    model.gradient_checkpointing_enable()
    model.enable_input_require_grads()
    examples = []
    for row in train:
        prompt = prompt_for(ParseRequest.model_validate(row['request']))
        prefix = tok.apply_chat_template([dict(role='user', content=prompt)], tokenize=False,
                                         add_generation_prompt=True, enable_thinking=False)
        start = tok(prefix, add_special_tokens=False)['input_ids']
        end = tok(json.dumps(row['expected'], ensure_ascii=False)+tok.eos_token,
                  add_special_tokens=False)['input_ids']
        assert len(start)+len(end) <= 2048
        ids = torch.tensor([start+end], device='cuda')
        labels = ids.clone()
        labels[:, :len(start)] = -100
        examples.append((ids, labels))
    optim = torch.optim.AdamW((p for p in model.parameters() if p.requires_grad), lr=2e-4)
    start_time = time.monotonic()
    model.train()
    step = 0
    for epoch in range(args.epochs):
        random.shuffle(examples)
        optim.zero_grad(set_to_none=True)
        for n, (ids, labels) in enumerate(examples):
            loss = model(input_ids=ids, labels=labels).loss / 8
            loss.backward()
            if (n+1) % 8 == 0 or n+1 == len(examples):
                torch.nn.utils.clip_grad_norm_(model.parameters(), 1.0)
                optim.step()
                optim.zero_grad(set_to_none=True)
                step += 1
                if step % 5 == 0:
                    print(f'epoch {epoch+1} update {step} loss {loss.item()*8:.3f} elapsed {time.monotonic()-start_time:.0f}s', flush=True)
    model.save_pretrained(args.output)
    tok.save_pretrained(args.output)
    print(f'Saved adapter to {args.output}; 40 held-out queries not used in training. Accuracy gate pending.', flush=True)


if __name__ == '__main__':
    main()
