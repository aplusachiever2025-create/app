-- Supervisor-only read access for the Operations Cockpit.
-- Run this once in Supabase SQL Editor / migration workflow.
-- It does NOT expose admin data to anon users.
drop policy if exists "admins read platform admins" on public.platform_admins;
create policy "admins read platform admins"
on public.platform_admins
for select to authenticated
using (
  exists (
    select 1
    from public.platform_admins me
    where me.user_id = (select auth.uid())
      and me.active = true
  )
);

create index if not exists match_case_notes_admin_created_idx
  on public.match_case_notes(admin_user_id, created_at desc);

create index if not exists match_cases_last_contacted_idx
  on public.match_cases(last_contacted_at)
  where last_contacted_at is not null;