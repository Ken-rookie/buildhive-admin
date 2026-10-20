-- BUILDHIVE Admin panel access setup
-- Run in Supabase SQL Editor as project owner. Review your existing RLS policies first.

-- The customer app's profiles table may not have an admin role column yet.
alter table public.profiles
  add column if not exists role text not null default 'customer';

create or replace function public.is_buildhive_admin()
returns boolean
language sql
stable
security definer
set search_path = ''
as $$
  select exists (
    select 1 from public.profiles p
    where p.id = (select auth.uid()) and p.role = 'admin'
  );
$$;

revoke all on function public.is_buildhive_admin() from public;
grant execute on function public.is_buildhive_admin() to authenticated;

create or replace function public.prevent_profile_role_escalation()
returns trigger
language plpgsql
security definer
set search_path = ''
as $$
begin
  if new.role is distinct from old.role
     and auth.uid() is not null
     and not public.is_buildhive_admin() then
    raise exception 'Only administrators can change profile roles';
  end if;
  return new;
end;
$$;

drop trigger if exists prevent_profile_role_escalation on public.profiles;
create trigger prevent_profile_role_escalation
  before update of role on public.profiles
  for each row execute function public.prevent_profile_role_escalation();

drop policy if exists "BUILDHIVE admins upload product images" on storage.objects;
create policy "BUILDHIVE admins upload product images"
  on storage.objects for insert to authenticated
  with check (bucket_id = 'product-images' and (select public.is_buildhive_admin()));


do $$
declare t text;
begin
  foreach t in array array['products','categories','orders','order_items','profiles','payments'] loop
    if to_regclass('public.' || t) is not null then
      execute format('alter table public.%I enable row level security', t);
      -- Replace only this script's previous admin policy; preserve customer policies.
      execute format('drop policy if exists %I on public.%I', 'BUILDHIVE admins manage records', t);
      execute format(
        'create policy %I on public.%I for all to authenticated using ((select public.is_buildhive_admin())) with check ((select public.is_buildhive_admin()))',
        'BUILDHIVE admins manage records', t
      );
    end if;
  end loop;
end $$;

