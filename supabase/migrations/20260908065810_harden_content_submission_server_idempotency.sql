-- Server-side idempotency and atomic persistence for public content
-- submissions. Legacy, Admin, and import rows intentionally retain a nullable
-- identity; the public Edge boundary always supplies a canonical UUID v4.
alter table public.content_submissions
  add column client_submission_id uuid null;

alter table public.content_submissions
  add constraint content_submissions_client_submission_id_uuid_v4_check
    check (
      client_submission_id is null
      or client_submission_id::text ~
        '^[0-9a-f]{8}-[0-9a-f]{4}-4[0-9a-f]{3}-[89ab][0-9a-f]{3}-[0-9a-f]{12}$'
    );

alter table public.content_submissions
  add constraint content_submissions_user_id_client_submission_id_key
    unique (user_id, client_submission_id);

-- The sole transaction boundary for public submission persistence. The Edge
-- Function authenticates and validates the payload before service-role
-- invocation; this function owns only the database-level quota, idempotency,
-- content, and asset invariants.
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
  p_assets jsonb
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
  jsonb
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
  jsonb
) to service_role;
