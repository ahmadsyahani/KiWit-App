-- KiWit: inspection persistence, private photos, and realtime updates.
-- Run once in the Supabase SQL Editor for the project configured in .env.
begin;

create table if not exists public.inspections (
  id uuid primary key,
  user_id uuid not null references auth.users(id) on delete cascade,
  scan_timestamp timestamptz not null,
  saved_at timestamptz not null,
  species_name text not null,
  health_score integer not null check (health_score between 0 and 100),
  risk_status text not null,
  location_address text not null default '',
  latitude double precision check (latitude between -90 and 90),
  longitude double precision check (longitude between -180 and 180),
  inspector_name text not null default '',
  rayon text not null default '',
  notes text not null default '',
  payload jsonb not null check (jsonb_typeof(payload) = 'object'),
  photo_path text not null,
  created_at timestamptz not null default now(),
  constraint inspection_photo_matches_owner check (
    photo_path = user_id::text || '/' || id::text || '.jpg'
  )
);

create index if not exists inspections_user_scan_idx
  on public.inspections (user_id, scan_timestamp desc, id);

alter table public.inspections enable row level security;
revoke all on table public.inspections from anon;
grant select, insert, update on table public.inspections to authenticated;

drop policy if exists inspections_select_own on public.inspections;
create policy inspections_select_own on public.inspections
  for select to authenticated
  using ((select auth.uid()) = user_id);

drop policy if exists inspections_insert_own on public.inspections;
create policy inspections_insert_own on public.inspections
  for insert to authenticated
  with check ((select auth.uid()) = user_id);

drop policy if exists inspections_update_own on public.inspections;
create policy inspections_update_own on public.inspections
  for update to authenticated
  using ((select auth.uid()) = user_id)
  with check ((select auth.uid()) = user_id);

insert into storage.buckets (id, name, public, file_size_limit, allowed_mime_types)
values (
  'kiwit-inspection-photos',
  'kiwit-inspection-photos',
  false,
  20971520,
  array['image/jpeg']
)
on conflict (id) do update
set public = false,
    file_size_limit = excluded.file_size_limit,
    allowed_mime_types = excluded.allowed_mime_types;

drop policy if exists kiwit_photos_select_own on storage.objects;
create policy kiwit_photos_select_own on storage.objects
  for select to authenticated
  using (
    bucket_id = 'kiwit-inspection-photos'
    and (storage.foldername(name))[1] = (select auth.uid())::text
  );

drop policy if exists kiwit_photos_insert_own on storage.objects;
create policy kiwit_photos_insert_own on storage.objects
  for insert to authenticated
  with check (
    bucket_id = 'kiwit-inspection-photos'
    and (storage.foldername(name))[1] = (select auth.uid())::text
  );

drop policy if exists kiwit_photos_update_own on storage.objects;
create policy kiwit_photos_update_own on storage.objects
  for update to authenticated
  using (
    bucket_id = 'kiwit-inspection-photos'
    and (storage.foldername(name))[1] = (select auth.uid())::text
  )
  with check (
    bucket_id = 'kiwit-inspection-photos'
    and (storage.foldername(name))[1] = (select auth.uid())::text
  );

do $$
begin
  if exists (select 1 from pg_publication where pubname = 'supabase_realtime')
     and not exists (
       select 1 from pg_publication_tables
       where pubname = 'supabase_realtime'
         and schemaname = 'public' and tablename = 'inspections'
     )
  then
    alter publication supabase_realtime add table public.inspections;
  end if;
end;
$$;

commit;
