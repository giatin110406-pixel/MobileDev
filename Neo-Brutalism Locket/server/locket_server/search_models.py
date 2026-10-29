"""One lazy local Qwen2-VL instance shared by searches and the background tagger."""
from __future__ import annotations

import io
import os
from pathlib import Path
import threading
import tempfile

from .search_service import SearchBusy
from .search_v2 import TAG_PROMPT, check_prompt


class SingleSearchProcess:
    """Local OS lease: API and standalone worker cannot each load a model on the 6 GB GPU."""
    def __init__(self, path=None):
        self.path = Path(path) if path else Path(tempfile.gettempdir())/'locket-search-gpu.lock'
        self.handle = None

    def __enter__(self):
        handle = self.path.open('a+b')
        handle.seek(0, 2)
        if handle.tell() == 0:
            handle.write(b'0')
            handle.flush()
        handle.seek(0)
        try:
            if os.name == 'nt':
                import msvcrt
                msvcrt.locking(handle.fileno(), msvcrt.LK_NBLCK, 1)
            else:
                import fcntl
                fcntl.flock(handle.fileno(), fcntl.LOCK_EX | fcntl.LOCK_NB)
        except OSError:
            handle.close()
            raise RuntimeError('Another local search process owns the GPU') from None
        self.handle = handle
        return self

    def __exit__(self, *_):
        if self.handle is not None:
            self.handle.seek(0)
            if os.name == 'nt':
                import msvcrt
                msvcrt.locking(self.handle.fileno(), msvcrt.LK_UNLCK, 1)
            else:
                import fcntl
                fcntl.flock(self.handle.fileno(), fcntl.LOCK_UN)
            self.handle.close()
            self.handle = None


class LocalVlm:
    def __init__(self, name='Qwen/Qwen2-VL-2B-Instruct', tag_prompt=TAG_PROMPT):
        self.name, self.tag_prompt = name, tag_prompt
        self.lock = threading.Lock()
        self.model = None

    def _load(self):
        if self.model is not None:
            return
        import torch
        from transformers import AutoModelForImageTextToText, AutoProcessor
        if not torch.cuda.is_available():
            raise RuntimeError('Search v2 requires the local CUDA GPU')
        cache = os.environ.get('LOCKET_SEARCH_MODEL_CACHE', str(Path.home()/'.cache/huggingface/hub'))
        kwargs = dict(cache_dir=cache, local_files_only=True)
        self.tag_processor = AutoProcessor.from_pretrained(
            self.name, min_pixels=128*28*28, max_pixels=448*28*28, **kwargs)
        self.check_processor = AutoProcessor.from_pretrained(
            self.name, min_pixels=128*28*28, max_pixels=320*28*28, **kwargs)
        for proc in (self.tag_processor, self.check_processor):
            proc.tokenizer.padding_side = 'left'
        model = AutoModelForImageTextToText.from_pretrained(self.name, dtype=torch.bfloat16, **kwargs)
        self.model = model.cuda().eval()
        tok = self.check_processor.tokenizer
        self.yes = list(dict.fromkeys(tok.encode(w, add_special_tokens=False)[0] for w in ('Yes', 'yes')))
        self.no = list(dict.fromkeys(tok.encode(w, add_special_tokens=False)[0] for w in ('No', 'no')))

    @staticmethod
    def _images(values):
        from PIL import Image, ImageOps
        images = []
        for data in values:
            with Image.open(io.BytesIO(data)) as source:
                if source.width * source.height > 40_000_000:
                    raise ValueError('photo dimensions exceed search limit')
                images.append(ImageOps.exif_transpose(source).convert('RGB'))
        return images

    def _inputs(self, proc, images, prompts):
        texts = [proc.apply_chat_template([{'role': 'user', 'content': [
            {'type': 'image'}, {'type': 'text', 'text': prompt}]}], add_generation_prompt=True)
                 for prompt in prompts]
        return proc(text=texts, images=images, padding=True, return_tensors='pt').to('cuda')

    def check(self, data, terms):
        if len(data) != len(terms):
            raise ValueError('one term is required per photo')
        if not data:
            return []
        if not self.lock.acquire(blocking=False):
            raise SearchBusy()
        try:
            import torch
            self._load()
            answers = []
            with torch.inference_mode():
                for start in range(0, len(data), 8):
                    inputs = self._inputs(self.check_processor, self._images(data[start:start+8]),
                                          [check_prompt(t) for t in terms[start:start+8]])
                    logits = self.model(**inputs, logits_to_keep=1,
                                        use_cache=False).logits[:, -1, :].float()
                    lp = torch.log_softmax(logits, dim=-1)
                    py = torch.logsumexp(lp[:, self.yes], dim=-1)
                    pn = torch.logsumexp(lp[:, self.no], dim=-1)
                    answers.extend(torch.sigmoid(py-pn).cpu().tolist())
            return answers
        finally:
            self.lock.release()

    def tag(self, data):
        if not self.lock.acquire(blocking=False):
            raise SearchBusy()
        try:
            import torch
            self._load()
            with torch.inference_mode():
                inputs = self._inputs(self.tag_processor, self._images([data]), [self.tag_prompt])
                out = self.model.generate(**inputs, max_new_tokens=220, do_sample=False)
                return self.tag_processor.batch_decode(
                    out[:, inputs['input_ids'].shape[1]:], skip_special_tokens=True)[0].strip()
        finally:
            self.lock.release()
