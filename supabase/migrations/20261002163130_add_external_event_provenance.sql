-- M1. Additive provenance state. Canonicalization and hashing belong to TypeScript.
create table public.external_event_records (
  id bigint generated always as identity primary key,
  provider text not null check (provider ~ '^[a-z0-9_]+$'),
  external_id text not null check (length(btrim(external_id)) > 0),
  occurrence_key text null check (occurrence_key is null or length(btrim(occurrence_key)) > 0),
  source_url text null,
  normalized jsonb not null check (jsonb_typeof(normalized) = 'object'),
  normalization_version integer not null check (normalization_version > 0),
  moderation_hash text not null check (moderation_hash ~ '^[0-9a-fA-F]{64}$'),
  proposed_normalized jsonb null check (proposed_normalized is null or jsonb_typeof(proposed_normalized) = 'object'),
  proposed_normalization_version integer null check (proposed_normalization_version is null or proposed_normalization_version > 0),
  proposed_hash text null check (proposed_hash is null or proposed_hash ~ '^[0-9a-fA-F]{64}$'),
  metadata jsonb not null default '{}'::jsonb check (jsonb_typeof(metadata) = 'object'),
  metadata_version integer not null check (metadata_version > 0),
  ignored_at timestamptz null,
  event_id bigint null references public.events(id) on delete restrict,
  created_at timestamptz not null default now(),
  modified_at timestamptz not null default now(),
  constraint external_event_records_identity_key unique nulls not distinct (provider, external_id, occurrence_key),
  constraint external_event_records_proposed_complete_check check (
    num_nonnulls(proposed_normalized, proposed_normalization_version, proposed_hash) in (0, 3)
  )
);

alter table public.external_event_records enable row level security;
revoke all on public.external_event_records from public, anon, authenticated;
revoke all on sequence public.external_event_records_id_seq from public, anon, authenticated;
grant select, insert, update, delete on public.external_event_records to service_role;
grant usage, select on sequence public.external_event_records_id_seq to service_role;
alter table public.content_submissions
  add column external_event_record_id bigint null references public.external_event_records(id) on delete restrict,
  add column external_normalized jsonb null,
  add column external_normalization_version integer null,
  add column external_moderation_hash text null,
  add column target_event_id bigint null references public.events(id) on delete restrict,
  add column source_asset_import_claimed_at timestamptz null,
  add constraint content_submissions_external_normalized_object_check
    check (external_normalized is null or jsonb_typeof(external_normalized) = 'object'),
  add constraint content_submissions_external_version_positive_check
    check (external_normalization_version is null or external_normalization_version > 0),
  add constraint content_submissions_external_hash_format_check
    check (external_moderation_hash is null or external_moderation_hash ~ '^[0-9a-fA-F]{64}$'),
  add constraint content_submissions_asset_claim_imported_check
    check (source_asset_import_claimed_at is null or external_event_record_id is not null);
alter table public.content_submissions
  add constraint content_submissions_external_complete_check check (
    num_nonnulls(external_event_record_id, external_normalized, external_normalization_version, external_moderation_hash) in (0, 4)
  ),
  add constraint content_submissions_existing_event_target_exclusive_check
    check (promoted_event_id is null or target_event_id is null),
  add constraint content_submissions_existing_event_target_accepted_check
    check (target_event_id is null or status = 'accepted');
create unique index content_submissions_one_external_pending_idx
  on public.content_submissions(external_event_record_id)
  where external_event_record_id is not null and status = 'pending';
-- A verified legacy backfill may populate previously null provenance. Once
-- populated, normal runtime SQL (including Admin) cannot rewrite source history.
create function private.guard_submission_external_provenance()
returns trigger language plpgsql set search_path = '' as $$
begin
  if old.external_event_record_id is not null and (
    new.external_event_record_id is distinct from old.external_event_record_id
    or new.external_normalized is distinct from old.external_normalized
    or new.external_normalization_version is distinct from old.external_normalization_version
    or new.external_moderation_hash is distinct from old.external_moderation_hash
  ) then
    raise exception using errcode = '23514', message = 'external_provenance_immutable';
  end if;
  return new;
end;
$$;
revoke all on function private.guard_submission_external_provenance() from public, anon, authenticated, service_role;
create trigger guard_submission_external_provenance
before update on public.content_submissions
for each row execute function private.guard_submission_external_provenance();
-- Equality tokens are DB-owned when merge content is saved. Do not round-trip
-- through application Date precision, and always advance inside one transaction.
create function private.maintain_submission_merge_modified_at()
returns trigger language plpgsql set search_path = '' as $$
begin
  if row(new.name, new.category, new.description, new.description_delta,
         new.all_day, new.start_date, new.end_date, new.city, new.latitude, new.longitude)
     is distinct from
     row(old.name, old.category, old.description, old.description_delta,
         old.all_day, old.start_date, old.end_date, old.city, old.latitude, old.longitude) then
    new.modified_at := greatest(clock_timestamp(), old.modified_at + interval '1 microsecond');
  else
    new.modified_at := old.modified_at;
  end if;
  return new;
end;
$$;
revoke all on function private.maintain_submission_merge_modified_at() from public, anon, authenticated, service_role;
create trigger maintain_submission_merge_modified_at
before update of name, category, description, description_delta, all_day,
                 start_date, end_date, city, latitude, longitude
on public.content_submissions
for each row execute function private.maintain_submission_merge_modified_at();
-- Consistency guard, not a security boundary against privileged SQL. Supported
-- service-role resolution RPCs set this GUC transaction-locally before writes.
-- JWT verification, RPC ACLs and RLS remain the authorization boundaries.
create function private.guard_submission_external_resolution()
returns trigger language plpgsql set search_path = '' as $$
begin
  if old.external_event_record_id is not null and (
    new.status is distinct from old.status
    or new.target_event_id is distinct from old.target_event_id
    or new.promoted_event_id is distinct from old.promoted_event_id
    or new.promoted_place_id is distinct from old.promoted_place_id
  ) and coalesce(current_setting('app.external_resolution', true), '') <> 'on' then
    raise exception using errcode = '23514', message = 'external_requires_resolution';
  end if;
  return new;
end;
$$;
revoke all on function private.guard_submission_external_resolution() from public, anon, authenticated, service_role;
create trigger guard_submission_external_resolution
before update on public.content_submissions
for each row execute function private.guard_submission_external_resolution();
-- Rollout step 1: structural suppression precedes provenance resolution/backfill.
drop trigger "notify-submission-status" on public.content_submissions;
create trigger "notify-submission-status"
  after update of status on public.content_submissions
  for each row
  when (new.external_event_record_id is null
    and old.status = 'pending'::public.submission_status
    and new.status in ('accepted'::public.submission_status, 'rejected'::public.submission_status))
  execute function private.notify_submission_status_webhook();
