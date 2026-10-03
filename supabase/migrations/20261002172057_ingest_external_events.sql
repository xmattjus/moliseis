-- Initial identity is resolved from Auth, never from caller-supplied email/name.
-- The public RPC is service-role-only SECURITY DEFINER so neither auth.users
-- reads nor execution of private helpers need to be granted to API clients.
create function private.external_event_importer_identity(p_user_id uuid)
returns table(user_id uuid, user_email text, user_name text)
language plpgsql security invoker set search_path = '' as $$
begin
  return query select u.id, btrim(u.email), btrim(u.raw_user_meta_data->>'display_name')
    from auth.users u
    where u.id = p_user_id
      and length(btrim(u.email)) > 0
      and jsonb_typeof(u.raw_user_meta_data->'display_name') = 'string'
      and length(btrim(u.raw_user_meta_data->>'display_name')) > 0;
  if not found then
    raise exception using errcode = '22023', message = 'external_importer_identity_invalid';
  end if;
end;
$$;
revoke all on function private.external_event_importer_identity(uuid) from public, anon, authenticated, service_role;

-- The only automatic imported pending INSERT. Its own record lock also makes
-- the required caller-held lock explicit; never acquire an existing submission
-- lock here (ingest owns only the source record).
create function private.enqueue_external_event_proposal_if_needed(
  p_record_id bigint, p_user_id uuid, p_user_email text, p_user_name text
)
returns table(pending_submission_id bigint, pending_created boolean)
language plpgsql security invoker set search_path = '' as $$
declare
  source public.external_event_records%rowtype;
  pending_id bigint;
begin
  select r.* into strict source from public.external_event_records r
    where r.id = p_record_id for update;
  if source.ignored_at is not null or (source.event_id is not null and exists (
    select 1 from public.events e where e.id = source.event_id and e.deleted_at is not null
  )) then
    return query select null::bigint, false;
    return;
  end if;
  select s.id into pending_id from public.content_submissions s
    where s.external_event_record_id = source.id and s.status = 'pending';
  if found then
    return query select pending_id, false;
    return;
  end if;
  if source.proposed_hash = source.moderation_hash
    and source.proposed_normalization_version = source.normalization_version then
    return query select null::bigint, false;
    return;
  end if;
  if p_user_id is null or coalesce(length(btrim(p_user_email)), 0) = 0
    or coalesce(length(btrim(p_user_name)), 0) = 0 then
    raise exception using errcode = '22023', message = 'external_importer_identity_invalid';
  end if;
  -- Mechanical typed projection only: no Unicode/Quill/time/coordinate
  -- canonicalization, hashing or merge decisions are implemented in SQL.
  insert into public.content_submissions (
    user_id, user_email, user_name, client_submission_id, status,
    name, category, description, description_delta, city, latitude, longitude,
    all_day, start_date, end_date, internal_notes,
    external_event_record_id, external_normalized,
    external_normalization_version, external_moderation_hash
  ) values (
    p_user_id, p_user_email, p_user_name, null, 'pending',
    source.normalized->>'name', (source.normalized->>'category')::public.content_category,
    source.normalized->>'description', nullif(source.normalized->'description_delta', 'null'::jsonb),
    source.normalized->>'city', (source.normalized->>'latitude')::double precision,
    (source.normalized->>'longitude')::double precision, (source.normalized->>'all_day')::boolean,
    (source.normalized->>'start_date')::timestamptz, (source.normalized->>'end_date')::timestamptz,
    source.metadata->>'internal_notes', source.id, source.normalized,
    source.normalization_version, source.moderation_hash
  ) returning id into pending_id;
  return query select pending_id, true;
end;
$$;
revoke all on function private.enqueue_external_event_proposal_if_needed(bigint, uuid, text, text) from public, anon, authenticated, service_role;

create function public.ingest_external_event(
  p_provider text, p_external_id text, p_occurrence_key text, p_source_url text,
  p_normalized jsonb, p_normalization_version integer, p_moderation_hash text,
  p_metadata jsonb, p_metadata_version integer, p_importer_user_id uuid
)
returns table(outcome text, record_id bigint, event_id bigint, pending_submission_id bigint, pending_created boolean)
language plpgsql security definer set search_path = '' as $$
declare
  source public.external_event_records%rowtype;
  contributor record;
  proposal record;
  start_instant timestamptz;
  end_instant timestamptz;
begin
  -- Readiness is validated before persistence, not SQL canonicalization.
  if p_normalized->>'start_date' is null then
    return query select 'start_date_required'::text, null::bigint, null::bigint, null::bigint, false;
    return;
  end if;
  start_instant := (p_normalized->>'start_date')::timestamptz;
  end_instant := (p_normalized->>'end_date')::timestamptz;
  if end_instant < start_instant then
    return query select 'invalid_date_range'::text, null::bigint, null::bigint, null::bigint, false;
    return;
  end if;
  insert into public.external_event_records (
    provider, external_id, occurrence_key, source_url, normalized,
    normalization_version, moderation_hash, metadata, metadata_version
  ) values (
    p_provider, p_external_id, p_occurrence_key, p_source_url, p_normalized,
    p_normalization_version, p_moderation_hash, p_metadata, p_metadata_version
  ) on conflict (provider, external_id, occurrence_key) do nothing;
  select r.* into strict source from public.external_event_records r
    where r.provider = p_provider and r.external_id = p_external_id
      and r.occurrence_key is not distinct from p_occurrence_key for update;
  if source.normalization_version <> p_normalization_version then
    return query select 'normalization_mismatch'::text, source.id, source.event_id, null::bigint, false;
    return;
  end if;
  if row(source.source_url, source.normalized, source.normalization_version,
         source.moderation_hash, source.metadata, source.metadata_version)
     is distinct from row(p_source_url, p_normalized, p_normalization_version,
                          p_moderation_hash, p_metadata, p_metadata_version) then
    update public.external_event_records r
      set source_url = p_source_url, normalized = p_normalized,
          normalization_version = p_normalization_version, moderation_hash = p_moderation_hash,
          metadata = p_metadata, metadata_version = p_metadata_version,
          modified_at = greatest(clock_timestamp(), r.modified_at + interval '1 microsecond')
      where r.id = source.id;
  end if;
  -- Existing source workflows inherit historical technical identity. The env
  -- identity seeds only a workflow with no imported submission history.
  select s.user_id, s.user_email, s.user_name into contributor
    from public.content_submissions s where s.external_event_record_id = source.id
      and length(btrim(s.user_email)) > 0 and length(btrim(s.user_name)) > 0
    order by s.handled_at desc nulls last, s.id desc limit 1;
  if not found then
    if exists (select 1 from public.content_submissions s where s.external_event_record_id = source.id) then
      raise exception using errcode = '22023', message = 'external_importer_identity_invalid';
    end if;
    select * into contributor from private.external_event_importer_identity(p_importer_user_id);
  end if;
  select * into proposal from private.enqueue_external_event_proposal_if_needed(
    source.id, contributor.user_id, contributor.user_email, contributor.user_name
  );
  return query select 'ingested'::text, source.id, source.event_id,
    proposal.pending_submission_id, proposal.pending_created;
end;
$$;
revoke all on function public.ingest_external_event(text, text, text, text, jsonb, integer, text, jsonb, integer, uuid) from public, anon, authenticated;
grant execute on function public.ingest_external_event(text, text, text, text, jsonb, integer, text, jsonb, integer, uuid) to service_role;
