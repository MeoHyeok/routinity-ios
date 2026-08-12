create table public.scores (
  id uuid primary key default gen_random_uuid(),
  user_id uuid not null references auth.users (id) on delete cascade,
  score_date date not null,
  score integer not null check (score >= 0 and score <= 100),
  wake_score integer check (wake_score >= 0 and wake_score <= 100),
  study_score integer check (study_score >= 0 and study_score <= 100),
  updated_at timestamptz not null default now(),
  unique (user_id, score_date)
);

create index scores_user_id_date_idx on public.scores (user_id, score_date);

alter table public.scores enable row level security;

create policy "Users can view their own scores"
  on public.scores for select
  using (auth.uid() = user_id);

create policy "Users can insert their own scores"
  on public.scores for insert
  with check (auth.uid() = user_id);

create policy "Users can update their own scores"
  on public.scores for update
  using (auth.uid() = user_id);
