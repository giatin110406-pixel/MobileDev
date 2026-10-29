-- Photo search v2 (search-v2-plan.md, "Decision on speed").
--
--  * posts.ai_tags: the object list and scene a vision model wrote for the photo when it was posted.
--    Read by whoever can read the post (the existing posts policy), like the caption.
--  * posts.ai_status: 'pending' until the server has written the tags; the server retries on
--    'pending' and gives up on 'failed'. A post is never blocked by this: it is posted first.
--  * post_checks: the model's yes / no probability for "is there a <term> in this photo", asked
--    once per (post, term) and cached. Internal: only the server (service role) reads or writes it,
--    so no policy is created, and RLS being on keeps every client out.

alter table public.posts
  add column if not exists ai_tags text,
  add column if not exists ai_status text not null default 'pending'
    check (ai_status in ('pending', 'done', 'failed')),
  add column if not exists ai_attempts int not null default 0;

create index if not exists posts_ai_pending_idx
  on public.posts (created_at)
  where ai_status = 'pending';

create table if not exists public.post_checks (
  post_id uuid not null references public.posts (id) on delete cascade,
  term text not null,
  probability real,
  checked_at timestamptz not null default now(),
  primary key (post_id, term)
);

alter table public.post_checks enable row level security;
