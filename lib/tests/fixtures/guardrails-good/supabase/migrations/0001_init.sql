create table public.notes (
  id uuid primary key default gen_random_uuid(),
  user_id uuid not null references auth.users (id),
  body text not null
);
alter table public.notes enable row level security;

create policy "owner read" on public.notes
  for select to authenticated
  using ((select auth.uid()) = user_id);

create policy "owner insert" on public.notes
  for insert to authenticated
  with check ((select auth.uid()) = user_id);

create table public.contacts (
  id uuid primary key default gen_random_uuid(),
  owner_id uuid not null references auth.users (id),
  email text,
  phone text,
  consent_at timestamptz not null,
  consent_source text not null,
  unsubscribed_at timestamptz,
  opt_out_at timestamptz
);
alter table public.contacts enable row level security;

create policy "owner contacts" on public.contacts
  for all to authenticated
  using ((select auth.uid()) = owner_id)
  with check ((select auth.uid()) = owner_id);

create view public.my_notes with (security_invoker = true) as
  select * from public.notes;

create function public.touch_updated() returns trigger
language plpgsql as $$
begin
  return new;
end;
$$;

create function public.admin_count() returns bigint
language sql security definer set search_path = '' as $$
  select count(*) from public.notes;
$$;
revoke execute on function public.admin_count() from public, anon;

create trigger notes_notify after insert on public.notes
  for each row execute function supabase_functions.http_request(
    'https://example.supabase.co/functions/v1/notify', 'POST', '{}', '{}', '5000'
  );

create policy "service delete" on public.notes
  for delete to service_role using (true);
