"""Single-laptop background tagging; posting never waits for this worker."""
from __future__ import annotations

import logging
import threading

from .search_service import SearchBusy

log = logging.getLogger(__name__)


class TagWorker:
    def __init__(self, store, tag, owner: str | None):
        self.store, self.tag, self.owner = store, tag, owner
        self.stop = threading.Event()
        self._run_lock = threading.Lock()

    def run_once(self, limit=20):
        if not 1 <= limit <= 20:
            raise ValueError('backfill batch must contain 1 to 20 posts')
        if not self._run_lock.acquire(blocking=False):
            return 0
        try:
            processed = 0
            for post in self.store.pending(self.owner, limit):
                if self.stop.is_set():
                    break
                try:
                    tags = self.tag(self.store.image(post))
                    if not isinstance(tags, str) or not tags.strip():
                        raise ValueError('tagger returned empty tags')
                except SearchBusy:
                    break  # another GPU operation is running; do not spend a retry
                except Exception as error:
                    log.warning('Tagging failed for post %s (%s)', post['id'], type(error).__name__)
                    self.store.finish_tag(post)
                else:
                    self.store.finish_tag(post, tags.strip())
                processed += 1
            return processed
        finally:
            self._run_lock.release()

    def poll(self):
        while not self.stop.is_set():
            try:
                self.run_once()
            except Exception as error:
                # A transient DB/network error must not terminate the background worker.
                log.warning('Tag worker poll failed (%s)', type(error).__name__)
            self.stop.wait(5)


def main():
    import argparse
    from uuid import UUID
    from . import config  # loads server/.env, never prints credentials
    from .search_models import LocalVlm, SingleSearchProcess
    from .search_store import SupabaseSearchStore

    parser = argparse.ArgumentParser(description='Tag only the specified owner posts, 20 per run')
    parser.add_argument('--owner', type=UUID, required=True)
    args = parser.parse_args()
    with SingleSearchProcess():
        store = SupabaseSearchStore.from_env()
        try:
            worker = TagWorker(store, LocalVlm().tag, str(args.owner))
            print(f'Processed {worker.run_once()} posts')
        finally:
            store.client.close()


if __name__ == '__main__':
    main()
