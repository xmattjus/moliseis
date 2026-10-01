-- Add explicit source-owned temporal mode without reclassifying existing rows.
alter table public.content_submissions
  add column all_day boolean not null default false;
alter table public.events
  add column all_day boolean not null default false;
alter table public.content_submissions
  add constraint content_submissions_all_day_start_required_check
  check (not all_day or start_date is not null);

-- The optional trailing argument preserves old PostgREST argument sets.
-- Remove the previous identity so schema-cache dispatch has no competing overload.
drop function public.submit_content(
  uuid, uuid, text, text, text, jsonb, double precision, double precision,
  text, timestamp with time zone, timestamp with time zone,
  public.content_category, text, text, jsonb
);

create function public.submit_content(
  p_user_id uuid,
  p_client_submission_id uuid,
  p_city text,
  p_name text,
  p_description text,
  p_description_delta jsonb,
  p_latitude double precision,
  p_longitude double precision,
  p_address text,
  p_start_date timestamp with time zone,
  p_end_date timestamp with time zone,
  p_category public.content_category,
  p_user_email text,
  p_user_name text,
  p_assets jsonb,
  p_all_day boolean default false
)
returns table (
  outcome text,
  submission_id bigint
)
language plpgsql
security invoker
set search_path to ''
as $function$
declare
  transaction_now timestamptz := transaction_timestamp();
  existing_submission_id bigint;
  quota_count integer;
  quota_window_started_at timestamptz;
  next_quota_count integer;
  next_window_started_at timestamptz;
  new_submission_id bigint;
  expected_asset_count integer;
  created_asset_count integer := 0;
  asset_result record;
begin
  -- This function is deliberately not STRICT: explicit rejection prevents a
  -- NULL RPC argument from becoming a silent null result at the PostgREST
  -- boundary.
  if p_user_id is null then
    raise exception 'p_user_id must not be null' using errcode = '22023';
  end if;

  if p_client_submission_id is null then
    raise exception 'p_client_submission_id must not be null'
      using errcode = '22023';
  end if;

  if p_assets is null or jsonb_typeof(p_assets) <> 'array' then
    raise exception 'p_assets must be a JSON array' using errcode = '22023';
  end if;

  -- A committed key is a replay even when the quota window has expired or the
  -- submission has entered moderation. It never mutates quota or payload.
  select content_submissions.id
  into existing_submission_id
  from public.content_submissions
  where content_submissions.user_id = p_user_id
    and content_submissions.client_submission_id = p_client_submission_id;

  if found then
    return query select 'replayed'::text, existing_submission_id;
    return;
  end if;

  -- Create the per-user serialization row if needed, then serialize both a
  -- same-key race and quota arbitration through its row lock.
  insert into public.submission_rate_limits (
    user_id,
    submission_count,
    window_started_at
  )
  values (p_user_id, 0, transaction_now)
  on conflict (user_id) do nothing;

  select submission_rate_limits.submission_count,
         submission_rate_limits.window_started_at
  into quota_count,
       quota_window_started_at
  from public.submission_rate_limits
  where submission_rate_limits.user_id = p_user_id
  for update;

  select content_submissions.id
  into existing_submission_id
  from public.content_submissions
  where content_submissions.user_id = p_user_id
    and content_submissions.client_submission_id = p_client_submission_id;

  if found then
    return query select 'replayed'::text, existing_submission_id;
    return;
  end if;

  -- Keep the established fixed-window policy exactly: equality with the
  -- 24-hour boundary is expired and starts a new window.
  if quota_window_started_at > transaction_now - interval '24 hours' then
    if quota_count >= 5 then
      return query select 'rate_limited'::text, null::bigint;
      return;
    end if;

    next_quota_count := quota_count + 1;
    next_window_started_at := quota_window_started_at;
  else
    next_quota_count := 1;
    next_window_started_at := transaction_now;
  end if;

  insert into public.content_submissions (
    user_id,
    client_submission_id,
    city,
    name,
    description,
    description_delta,
    latitude,
    longitude,
    address,
    start_date,
    end_date,
    all_day,
    category,
    user_email,
    user_name
  )
  values (
    p_user_id,
    p_client_submission_id,
    p_city,
    p_name,
    p_description,
    p_description_delta,
    p_latitude,
    p_longitude,
    p_address,
    p_start_date,
    p_end_date,
    p_all_day,
    coalesce(p_category, 'unknown'::public.content_category),
    p_user_email,
    p_user_name
  )
  returning content_submissions.id into new_submission_id;

  expected_asset_count := jsonb_array_length(p_assets);
  for asset_result in
    select added_assets.outcome
    from public.add_submission_assets(new_submission_id, p_assets) as added_assets
  loop
    if asset_result.outcome <> 'created' then
      raise exception 'add_submission_assets returned unexpected outcome'
        using errcode = 'P0001';
    end if;

    created_asset_count := created_asset_count + 1;
  end loop;

  if created_asset_count <> expected_asset_count then
    raise exception 'add_submission_assets returned unexpected row count'
      using errcode = 'P0001';
  end if;

  update public.submission_rate_limits
  set submission_count = next_quota_count,
      window_started_at = next_window_started_at
  where submission_rate_limits.user_id = p_user_id;

  return query select 'created'::text, new_submission_id;
end;
$function$;

revoke all on function public.submit_content(
  uuid,
  uuid,
  text,
  text,
  text,
  jsonb,
  double precision,
  double precision,
  text,
  timestamp with time zone,
  timestamp with time zone,
  public.content_category,
  text,
  text,
  jsonb,
  boolean
) from public, anon, authenticated;

grant execute on function public.submit_content(
  uuid,
  uuid,
  text,
  text,
  text,
  jsonb,
  double precision,
  double precision,
  text,
  timestamp with time zone,
  timestamp with time zone,
  public.content_category,
  text,
  text,
  jsonb,
  boolean
) to service_role;

-- Enforce concrete categories at the authoritative publication boundary while
-- preserving the existing promotion contract, locking, and ACL.
create or replace function public.promote_content_submission(
  p_submission_id bigint,
  p_target text,
  p_handled_by uuid
)
returns table (
  outcome text,
  target_type text,
  entity_id bigint
)
language plpgsql
security invoker
as $function$
declare
  submission_status public.submission_status;
  linked_place_id bigint;
  linked_event_id bigint;
  submission_city text;
  submission_name text;
  submission_description text;
  submission_description_delta jsonb;
  submission_latitude double precision;
  submission_longitude double precision;
  submission_category public.content_category;
  submission_start_date timestamptz;
  submission_end_date timestamptz;
  submission_all_day boolean;
  resolved_city_id bigint;
  new_entity_id bigint;
begin
  -- Programmer/API contract errors are validated before acquiring any lock.
  -- The function is deliberately not STRICT: PostgREST RPC calls with NULL
  -- arguments silently skip STRICT functions and return a null result instead
  -- of raising, so null inputs are rejected explicitly here.
  if p_target is null or p_target not in ('place', 'event') then
    raise exception 'p_target must be ''place'' or ''event'''
      using errcode = '22023';
  end if;

  if p_handled_by is null then
    raise exception 'p_handled_by must not be null'
      using errcode = '22023';
  end if;

  -- Lock the parent submission first; every readiness check and the asset
  -- snapshot below happen while this lock is held. The Milestone 0 asset
  -- RPCs take the same parent lock, so assets cannot change between this
  -- snapshot and the media copy.
  select status,
         promoted_place_id,
         promoted_event_id,
         city,
         name,
         description,
         description_delta,
         latitude,
         longitude,
         category,
         start_date,
         end_date,
         all_day
  into submission_status,
       linked_place_id,
       linked_event_id,
       submission_city,
       submission_name,
       submission_description,
       submission_description_delta,
       submission_latitude,
       submission_longitude,
       submission_category,
       submission_start_date,
       submission_end_date,
       submission_all_day
  from public.content_submissions
  where content_submissions.id = p_submission_id
  for update;

  if not found then
    return query select 'not_found'::text, null::text, null::bigint;
    return;
  end if;

  -- Idempotency discovery happens before the pending check: after a successful
  -- promotion the status is accepted, and a retry caused by a client timeout
  -- must discover the original result instead of reporting not_pending.
  if linked_place_id is not null or linked_event_id is not null then
    if linked_place_id is not null then
      return query select 'already_promoted'::text, 'place'::text, linked_place_id;
    else
      return query select 'already_promoted'::text, 'event'::text, linked_event_id;
    end if;
    return;
  end if;

  -- Without a durable promotion link only pending submissions may be promoted;
  -- accepted historical rows without links and rejected rows stay untouched.
  if submission_status <> 'pending' then
    return query select 'not_pending'::text, null::text, null::bigint;
    return;
  end if;

  -- Readiness checks. All happen while the row lock is held; none mutate.
  if btrim(submission_name) = '' then
    return query select 'invalid_name'::text, null::text, null::bigint;
    return;
  end if;

  if submission_latitude is null or submission_longitude is null then
    return query select 'coordinates_required'::text, null::text, null::bigint;
    return;
  end if;

  -- PostgreSQL float comparisons treat NaN as greater than every non-NaN
  -- value, including infinity, so these predicates classify NaN, +Infinity and
  -- -Infinity as out of range. They mirror the places/events CHECK forms.
  if submission_latitude < -90::double precision
     or submission_latitude > 90::double precision
     or submission_longitude < -180::double precision
     or submission_longitude > 180::double precision then
    return query select 'invalid_coordinates'::text, null::text, null::bigint;
    return;
  end if;

  if p_target = 'place' then
    -- Stored event dates are never silently discarded on place publication.
    if submission_start_date is not null
       or submission_end_date is not null then
      return query select 'place_has_event_dates'::text, null::text, null::bigint;
      return;
    end if;
  else
    if submission_start_date is null then
      return query select 'start_date_required'::text, null::text, null::bigint;
      return;
    end if;

    -- Equal start/end is valid; only an end strictly before start is rejected.
    if submission_end_date is not null
       and submission_end_date < submission_start_date then
      return query select 'invalid_date_range'::text, null::text, null::bigint;
      return;
    end if;
  end if;

  -- Resolve the city/locality inside the same transaction: exact stored-name
  -- equality against an active row; promotion never creates or upserts cities.
  -- FOR SHARE blocks concurrent UPDATE / soft-delete / DELETE of the city row
  -- until commit, guaranteeing publication references an active city (plain
  -- RESTRICT alone cannot, because soft-delete is an UPDATE). It stays
  -- self-compatible: concurrent promotions resolving the same city do not
  -- serialize on it. FOR KEY SHARE would be insufficient -- it would not block
  -- a deleted_at update.
  select cities.id
  into resolved_city_id
  from public.cities
  where cities.name = submission_city
    and cities.deleted_at is null
  for share;

  if not found then
    return query select 'city_not_found'::text, null::text, null::bigint;
    return;
  end if;

  -- Zero source assets are valid. Reject any asset violating media constraints
  -- before creating the target; the snapshot is stable under the held lock.
  if exists (
    select 1
    from public.submissions_assets
    where submissions_assets.content_submission_id = p_submission_id
      and (
        submissions_assets.url not like 'https://%'
        or submissions_assets.width <= 0
        or submissions_assets.height <= 0
      )
  ) then
    return query select 'invalid_asset'::text, null::text, null::bigint;
    return;
  end if;

  if submission_category = 'unknown' then
    return query select 'category_required'::text, null::text, null::bigint;
    return;
  end if;

  -- Create the target, then copy every current source asset set-wise. Source
  -- assets are kept unchanged as the immutable audit record; MIME and duration
  -- have no media destination. Unexpected failures propagate and roll back the
  -- caller's entire transaction (target, media, linkage, status and any
  -- transactional notification enqueue).
  if p_target = 'place' then
    insert into public.places (
      name,
      description,
      description_delta,
      latitude,
      longitude,
      city_id,
      category
    )
    values (
      submission_name,
      submission_description,
      submission_description_delta,
      submission_latitude,
      submission_longitude,
      resolved_city_id,
      submission_category
    )
    returning places.id into new_entity_id;

    insert into public.media (url, width, height, place_id)
    select assets.url, assets.width, assets.height, new_entity_id
    from public.submissions_assets as assets
    where assets.content_submission_id = p_submission_id;
  else
    insert into public.events (
      name,
      description,
      description_delta,
      start_date,
      end_date,
      all_day,
      latitude,
      longitude,
      city_id,
      category
    )
    values (
      submission_name,
      submission_description,
      submission_description_delta,
      submission_start_date,
      submission_end_date,
      submission_all_day,
      submission_latitude,
      submission_longitude,
      resolved_city_id,
      submission_category
    )
    returning events.id into new_entity_id;

    insert into public.media (url, width, height, event_id)
    select assets.url, assets.width, assets.height, new_entity_id
    from public.submissions_assets as assets
    where assets.content_submission_id = p_submission_id;
  end if;

  -- Final mutation: the durable link, trusted service-role supplied handled_by,
  -- explicit modified_at (no trigger maintains it), and accepted status commit
  -- in one statement so the promotion-link CHECK sees one consistent row
  -- version. handled_at stays owned by the handle_handled_at trigger and the
  -- notify-submission-status trigger observes pending -> accepted; its pg_net
  -- enqueue rolls back with this transaction while its own failures are
  -- swallowed there and never roll back moderation.
  update public.content_submissions
  set promoted_place_id =
        case when p_target = 'place' then new_entity_id end,
      promoted_event_id =
        case when p_target = 'event' then new_entity_id end,
      handled_by = p_handled_by,
      modified_at = now(),
      status = 'accepted'
  where content_submissions.id = p_submission_id;

  return query select 'created'::text, p_target, new_entity_id;
end;
$function$;

revoke all on function public.promote_content_submission(bigint, text, uuid) from public, anon, authenticated;

grant execute on function public.promote_content_submission(bigint, text, uuid) to service_role;

notify pgrst, 'reload schema';
