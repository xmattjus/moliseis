-- Canonical lifecycle repair precedes DB-owned semantic UPDATE markers.
drop trigger handle_modified_at on public.cities;
drop trigger handle_modified_at on public.events;
drop trigger handle_modified_at on public.places;
drop trigger handle_modified_at on public.media;

-- Preserve deletion chronology while advancing every legacy tombstone marker.
update public.cities
set modified_at = greatest(deleted_at, modified_at + interval '1 microsecond')
where deleted_at is not null;

update public.events
set modified_at = greatest(deleted_at, modified_at + interval '1 microsecond')
where deleted_at is not null;

update public.places
set modified_at = greatest(deleted_at, modified_at + interval '1 microsecond')
where deleted_at is not null;

update public.media
set modified_at = greatest(deleted_at, modified_at + interval '1 microsecond')
where deleted_at is not null;

alter table public.cities alter column modified_at set default pg_catalog.clock_timestamp();
alter table public.events alter column modified_at set default pg_catalog.clock_timestamp();
alter table public.places alter column modified_at set default pg_catalog.clock_timestamp();
alter table public.media alter column modified_at set default pg_catalog.clock_timestamp();

create function private.set_cities_modified_at()
returns trigger
language plpgsql
security invoker
set search_path = ''
as $$
begin
  if new.name is distinct from old.name
     or new.description_delta is distinct from old.description_delta
     or new.deleted_at is distinct from old.deleted_at then
    new.modified_at := greatest(pg_catalog.clock_timestamp(), old.modified_at + interval '1 microsecond');
  else
    new.modified_at := old.modified_at;
  end if;
  return new;
end;
$$;
revoke all on function private.set_cities_modified_at() from public, anon, authenticated, service_role;
create trigger handle_modified_at before update on public.cities
for each row execute function private.set_cities_modified_at();

create function private.set_events_modified_at()
returns trigger
language plpgsql
security invoker
set search_path = ''
as $$
begin
  if new.name is distinct from old.name
     or new.description is distinct from old.description
     or new.description_delta is distinct from old.description_delta
     or new.start_date is distinct from old.start_date
     or new.end_date is distinct from old.end_date
     or new.all_day is distinct from old.all_day
     or new.latitude is distinct from old.latitude
     or new.longitude is distinct from old.longitude
     or new.city_id is distinct from old.city_id
     or new.category is distinct from old.category
     or new.deleted_at is distinct from old.deleted_at then
    new.modified_at := greatest(pg_catalog.clock_timestamp(), old.modified_at + interval '1 microsecond');
  else
    new.modified_at := old.modified_at;
  end if;
  return new;
end;
$$;
revoke all on function private.set_events_modified_at() from public, anon, authenticated, service_role;
create trigger handle_modified_at before update on public.events
for each row execute function private.set_events_modified_at();

create function private.set_places_modified_at()
returns trigger
language plpgsql
security invoker
set search_path = ''
as $$
begin
  if new.name is distinct from old.name
     or new.description is distinct from old.description
     or new.description_delta is distinct from old.description_delta
     or new.latitude is distinct from old.latitude
     or new.longitude is distinct from old.longitude
     or new.city_id is distinct from old.city_id
     or new.category is distinct from old.category
     or new.deleted_at is distinct from old.deleted_at then
    new.modified_at := greatest(pg_catalog.clock_timestamp(), old.modified_at + interval '1 microsecond');
  else
    new.modified_at := old.modified_at;
  end if;
  return new;
end;
$$;
revoke all on function private.set_places_modified_at() from public, anon, authenticated, service_role;
create trigger handle_modified_at before update on public.places
for each row execute function private.set_places_modified_at();

create function private.set_media_modified_at()
returns trigger
language plpgsql
security invoker
set search_path = ''
as $$
begin
  if new.url is distinct from old.url
     or new.description is distinct from old.description
     or new.author is distinct from old.author
     or new.license is distinct from old.license
     or new.license_url is distinct from old.license_url
     or new.width is distinct from old.width
     or new.height is distinct from old.height
     or new.event_id is distinct from old.event_id
     or new.place_id is distinct from old.place_id
     or new.deleted_at is distinct from old.deleted_at then
    new.modified_at := greatest(pg_catalog.clock_timestamp(), old.modified_at + interval '1 microsecond');
  else
    new.modified_at := old.modified_at;
  end if;
  return new;
end;
$$;
revoke all on function private.set_media_modified_at() from public, anon, authenticated, service_role;
create trigger handle_modified_at before update on public.media
for each row execute function private.set_media_modified_at();

comment on column public.cities.modified_at is 'modified_at identifies the last semantically relevant change to the resource represented by the row. Which changes are semantically relevant is table-specific and must not be interpreted as every SQL UPDATE. deleted_at lifecycle changes, including soft-delete and return to active, are semantically relevant.';
create index cities_modified_at_idx on public.cities using btree (modified_at);

comment on column public.events.modified_at is 'modified_at identifies the last semantically relevant change to the resource represented by the row. Which changes are semantically relevant is table-specific and must not be interpreted as every SQL UPDATE. deleted_at lifecycle changes, including soft-delete and return to active, are semantically relevant.';
create index events_modified_at_idx on public.events using btree (modified_at);

comment on column public.places.modified_at is 'modified_at identifies the last semantically relevant change to the resource represented by the row. Which changes are semantically relevant is table-specific and must not be interpreted as every SQL UPDATE. deleted_at lifecycle changes, including soft-delete and return to active, are semantically relevant.';
create index places_modified_at_idx on public.places using btree (modified_at);

comment on column public.media.modified_at is 'modified_at identifies the last semantically relevant change to the resource represented by the row. Which changes are semantically relevant is table-specific and must not be interpreted as every SQL UPDATE. deleted_at lifecycle changes, including soft-delete and return to active, are semantically relevant.';
create index media_modified_at_idx on public.media using btree (modified_at);

-- An observation of server time, not a dataset snapshot or commit-order token.
create function public.get_content_sync_cursor()
returns timestamptz
language sql
volatile
security invoker
set search_path = ''
as $$
  select pg_catalog.clock_timestamp();
$$;
revoke all on function public.get_content_sync_cursor() from public, anon, authenticated, service_role;
grant execute on function public.get_content_sync_cursor() to anon, authenticated;

notify pgrst, 'reload schema';
