-- Private, per-user backup of the existing single-file app state.
-- This does not replace the normalized store tables; it provides an initial safe
-- cloud backup/restore path while the full UI is migrated incrementally.
create table if not exists public.user_app_state (
  user_id uuid primary key references auth.users(id) on delete cascade,
  state_json jsonb not null default '{}'::jsonb,
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now(),
  constraint user_app_state_object_check check (jsonb_typeof(state_json) = 'object')
);

alter table public.user_app_state enable row level security;

drop policy if exists "user app state select own" on public.user_app_state;
create policy "user app state select own" on public.user_app_state
  for select to authenticated using (user_id = (select auth.uid()));

drop policy if exists "user app state insert own" on public.user_app_state;
create policy "user app state insert own" on public.user_app_state
  for insert to authenticated with check (user_id = (select auth.uid()));

drop policy if exists "user app state update own" on public.user_app_state;
create policy "user app state update own" on public.user_app_state
  for update to authenticated using (user_id = (select auth.uid()))
  with check (user_id = (select auth.uid()));

drop policy if exists "user app state delete own" on public.user_app_state;
create policy "user app state delete own" on public.user_app_state
  for delete to authenticated using (user_id = (select auth.uid()));

grant select, insert, update, delete on public.user_app_state to authenticated;
