create table public.logs (
  id uuid primary key default gen_random_uuid(),
  user_id uuid not null references auth.users (id) on delete cascade,
  type text not null check (type in ('wake', 'meal', 'study_start', 'study_end')),
  logged_at timestamptz not null default now(),
  updated_at timestamptz not null default now()
);

create index logs_user_id_logged_at_idx on public.logs (user_id, logged_at);

alter table public.logs enable row level security;

create policy "Users can view their own logs"
  on public.logs for select
  using (auth.uid() = user_id);

create policy "Users can insert their own logs"
  on public.logs for insert
  with check (auth.uid() = user_id);

create policy "Users can delete their own logs"
  on public.logs for delete
  using (auth.uid() = user_id);
