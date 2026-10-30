"""Local Qwen3 query parser, with typed output and client rules as the validator."""
from __future__ import annotations

import json
import os
from pathlib import Path
import threading
from datetime import datetime
from uuid import UUID

from pydantic import BaseModel, ConfigDict, Field, StrictBool

from .search_service import SearchRequest, SearchBusy
from .search_lexicon import lookup
from .search_terms import SYNONYMS


class Friend(BaseModel):
    id: UUID
    name: str = Field(min_length=1, max_length=100)


class ParseRequest(BaseModel):
    model_config = ConfigDict(extra='forbid')
    text: str = Field(min_length=1, max_length=500)
    visual_text: str = Field(max_length=500)
    now: datetime
    friends: list[Friend] = Field(default_factory=list, max_length=100)
    my_names: list[str] = Field(default_factory=list, max_length=8)
    rules: SearchRequest


class ModelQuery(BaseModel):
    model_config = ConfigDict(extra='forbid')
    friend: str | None
    from_time: str | None
    until_time: str | None
    mine: StrictBool
    terms: list[str] = Field(max_length=8)
    name_only: StrictBool


def prompt_for(request: ParseRequest):
    return (
        'Parse this photo search into JSON only. Translate visible objects to English. '
        'Use canonical terms where possible: '+', '.join(SYNONYMS)+'. '
        'friend is a supplied friend id or null. from_time/until_time are ISO dates with timezone '
        '(start inclusive, end exclusive) or null. mine and name_only are booleans. '
        'terms is a list of visible objects, never people names or time words. '
        'Do not invent objects. Use this exact schema: '
        '{"friend":null,"from_time":null,"until_time":null,"mine":false,"terms":[],"name_only":false}.\n'
        +json.dumps(dict(text=request.text, visual_text=request.visual_text, now=request.now.isoformat(),
                         friends=[dict(id=str(f.id), name=f.name) for f in request.friends],
                         rules=request.rules.model_dump(mode='json')), ensure_ascii=False))


class QueryParser:
    def __init__(self, generate=None):
        self.generate = generate or LocalQueryModel()

    def parse(self, request: ParseRequest):
        # Nothing visual, or a name already identified by rules: no vision inference needed.
        if request.rules.name_only or not request.visual_text.strip():
            return dict(query=request.rules.model_dump(mode='json'), declined=False)
        # Negation cannot prove absence with a tagger that misses objects. Fail closed for now.
        import re
        if re.search(r'\b(không có|khong co|without|not showing|không phải|khong phai)\b', request.text.lower()):
            return dict(query=request.rules.model_dump(mode='json'), declined=True)
        # Everyday words come from the lexicon (instant, no guessing); only what it cannot
        # explain is left to the model.
        known, unexplained = lookup(request.visual_text)
        if known and not unexplained:
            values = request.rules.model_dump()
            values.update(terms=known[:8], name_only=False)
            return dict(query=SearchRequest.model_validate(values).model_dump(mode='json'), declined=False)
        if known:
            request = request.model_copy(update=dict(visual_text=unexplained))
        output = ModelQuery.model_validate(json.loads(self.generate(prompt_for(request))))
        values = request.rules.model_dump()
        valid_friends = {str(f.id) for f in request.friends}
        if values['friend_id'] is None and output.friend in valid_friends:
            values['friend_id'] = output.friend
        # Existing rules win when they recognized a filter. New model dates must validate together.
        if values['from_time'] is None and values['until_time'] is None:
            try:
                dates = SearchRequest(from_time=output.from_time, until_time=output.until_time)
                values.update(from_time=dates.from_time, until_time=dates.until_time)
            except ValueError:
                pass
        values['mine'] = values['mine'] or output.mine
        # The model cannot turn an object query into "all photos" or assert a person's name.
        if output.name_only:
            return dict(query=request.rules.model_dump(mode='json'), declined=True)
        values['terms'] = list(dict.fromkeys([*known, *output.terms]))[:8]
        values['name_only'] = False
        query = SearchRequest.model_validate(values)
        if not query.terms:
            return dict(query=query.model_dump(mode='json'), declined=True)
        return dict(query=query.model_dump(mode='json'), declined=False)


class LocalQueryModel:
    """CPU parser leaves the 6 GB GPU available for the VLM. Adapter is opt-in until evaluated."""
    def __init__(self):
        self.model = None
        self.lock = threading.Lock()

    def __call__(self, prompt):
        if not self.lock.acquire(blocking=False):
            raise SearchBusy()
        try:
            import torch
            from transformers import AutoModelForCausalLM, AutoTokenizer
            if self.model is None:
                torch.set_num_threads(int(os.environ.get('LOCKET_QUERY_THREADS', '4')))
                cache = os.environ.get('LOCKET_SEARCH_MODEL_CACHE', str(Path.home()/'.cache/huggingface/hub'))
                kwargs = dict(cache_dir=cache, local_files_only=True)
                self.tokenizer = AutoTokenizer.from_pretrained('Qwen/Qwen3-0.6B', **kwargs)
                model = AutoModelForCausalLM.from_pretrained('Qwen/Qwen3-0.6B', dtype=torch.float32, **kwargs)
                default_adapter = Path('D:/clip_eval_tmp/search_v2/query_parser_lora')
                adapter = os.environ.get('LOCKET_QUERY_ADAPTER') or (
                    str(default_adapter) if (default_adapter/'adapter_config.json').exists() else None)
                if adapter:
                    from peft import PeftModel
                    model = PeftModel.from_pretrained(model, adapter)
                self.model = model.eval()
            text = self.tokenizer.apply_chat_template([dict(role='user', content=prompt)],
                        tokenize=False, add_generation_prompt=True, enable_thinking=False)
            inputs = self.tokenizer(text, return_tensors='pt')
            with torch.inference_mode():
                out = self.model.generate(**inputs, max_new_tokens=180, do_sample=False)
            return self.tokenizer.decode(out[0, inputs['input_ids'].shape[1]:], skip_special_tokens=True).strip()
        finally:
            self.lock.release()
