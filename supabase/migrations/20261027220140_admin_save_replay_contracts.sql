-- Admin Save replay boundaries. Authentication/staff authorization and payload
-- validation remain in the Admin Edge Function; these RPCs are service-role only.
create function public.admin_create_submission(
  p_user_id uuid,
  p_client_submission_id uuid,
  p_user_email text,
  p_user_name text,
  p_input jsonb
)
returns table (outcome text, submission_id bigint)
language plpgsql
security invoker
set search_path = ''
as $function$
declare
  persisted_id bigint;
begin
  if p_user_id is null or p_client_submission_id is null
     or p_client_submission_id::text !~
       '^[0-9a-f]{8}-[0-9a-f]{4}-4[0-9a-f]{3}-[89ab][0-9a-f]{3}-[0-9a-f]{12}$'
     or p_input is null or jsonb_typeof(p_input) <> 'object' then
    raise exception 'Invalid Admin Create identity or input' using errcode = '22023';
  end if;

  insert into public.content_submissions (
    user_id, client_submission_id, user_email, user_name,
    category, city, name, description, description_delta,
    start_date, end_date, all_day, latitude, longitude
  ) values (
    p_user_id, p_client_submission_id, p_user_email, p_user_name,
    coalesce((p_input->>'category')::public.content_category, 'unknown'),
    p_input->>'city', p_input->>'name', p_input->>'description',
    nullif(p_input->'description_delta', 'null'::jsonb),
    (p_input->>'start_date')::timestamptz,
    (p_input->>'end_date')::timestamptz,
    coalesce((p_input->>'all_day')::boolean, false),
    (p_input->>'latitude')::double precision,
    (p_input->>'longitude')::double precision
  )
  on conflict on constraint content_submissions_user_id_client_submission_id_key
  do nothing
  returning content_submissions.id into persisted_id;

  if found then
    return query select 'created'::text, persisted_id;
    return;
  end if;

  -- A separate READ COMMITTED statement sees the winner after the unique
  -- conflict has waited for its commit. Never use a no-op DO UPDATE: replay
  -- must not fire update/moderation/timestamp triggers.
  select existing.id into persisted_id
  from public.content_submissions as existing
  where existing.user_id = p_user_id
    and existing.client_submission_id = p_client_submission_id;
  if not found then
    -- A privileged concurrent deletion is not permission to invent success.
    raise exception 'Admin Create replay target unavailable' using errcode = '40001';
  end if;
  return query select 'replayed'::text, persisted_id;
end;
$function$;

create function public.add_admin_submission_asset_once(
  p_submission_id bigint,
  p_asset jsonb
)
returns table (outcome text, id bigint, url text, width integer, height integer)
language plpgsql
security invoker
set search_path = ''
as $function$
declare
  parent_status public.submission_status;
  receipt record;
  associated public.submissions_assets%rowtype;
begin
  if p_submission_id is null or p_asset is null
     or jsonb_typeof(p_asset) <> 'object' then
    raise exception 'Invalid Admin asset request' using errcode = '22023';
  end if;
  select * into receipt from jsonb_to_record(p_asset) as value(
    url text, width integer, height integer, mime_type text, duration_seconds integer
  );
  if receipt.url is null or receipt.url = '' or receipt.width is null
     or receipt.width <= 0 or receipt.height is null or receipt.height <= 0 then
    raise exception 'Invalid Admin asset receipt' using errcode = '22023';
  end if;

  select parent.status into parent_status
  from public.content_submissions as parent
  where parent.id = p_submission_id
  for update;
  if not found then
    return query select 'not_found'::text, null::bigint, null::text, null::integer, null::integer;
    return;
  end if;

  select asset.* into associated
  from public.submissions_assets as asset
  where asset.content_submission_id = p_submission_id
    and asset.url = receipt.url
    and asset.width = receipt.width
    and asset.height = receipt.height
    and asset.mime_type is not distinct from receipt.mime_type
    and asset.duration_seconds is not distinct from receipt.duration_seconds
  order by asset.id
  limit 1;
  if found then
    return query select 'replayed'::text, associated.id, associated.url,
      associated.width, associated.height;
    return;
  end if;

  if exists (
    select 1 from public.submissions_assets as asset
    where asset.content_submission_id = p_submission_id and asset.url = receipt.url
  ) then
    return query select 'metadata_conflict'::text, null::bigint, null::text, null::integer, null::integer;
    return;
  end if;

  if parent_status <> 'pending' then
    return query select 'not_pending'::text, null::bigint, null::text, null::integer, null::integer;
    return;
  end if;

  -- Re-entering the same parent lock is safe; the established function owns
  -- insertion/capacity. Legacy/Public batch semantics are unchanged.
  return query select added.outcome, added.id, added.url, added.width, added.height
  from public.add_submission_assets(p_submission_id, jsonb_build_array(p_asset)) as added;
end;
$function$;

revoke all on function public.admin_create_submission(uuid, uuid, text, text, jsonb)
  from public, anon, authenticated;
grant execute on function public.admin_create_submission(uuid, uuid, text, text, jsonb)
  to service_role;
revoke all on function public.add_admin_submission_asset_once(bigint, jsonb)
  from public, anon, authenticated;
grant execute on function public.add_admin_submission_asset_once(bigint, jsonb)
  to service_role;
