create function public.add_submission_assets(
  p_submission_id bigint,
  p_assets jsonb
)
returns table (
  outcome text,
  id bigint,
  url text,
  width integer,
  height integer
)
language plpgsql
security invoker
as $function$
declare
  existing_count integer;
  requested_count integer;
  submission_status public.submission_status;
begin
  select status
  into submission_status
  from public.content_submissions
  where content_submissions.id = p_submission_id
  for update;

  if not found then
    return query select 'not_found'::text, null::bigint, null::text, null::integer, null::integer;
    return;
  end if;

  if submission_status <> 'pending' then
    return query select 'not_pending'::text, null::bigint, null::text, null::integer, null::integer;
    return;
  end if;

  if jsonb_typeof(p_assets) <> 'array' then
    raise exception 'p_assets must be a JSON array' using errcode = '22023';
  end if;

  requested_count := jsonb_array_length(p_assets);
  select count(*)
  into existing_count
  from public.submissions_assets
  where content_submission_id = p_submission_id;

  if existing_count + requested_count > 5 then
    return query select 'limit_reached'::text, null::bigint, null::text, null::integer, null::integer;
    return;
  end if;

  return query
  with inserted as (
    insert into public.submissions_assets (
      content_submission_id,
      url,
      width,
      height,
      mime_type,
      duration_seconds
    )
    select
      p_submission_id,
      asset.url,
      asset.width,
      asset.height,
      asset.mime_type,
      asset.duration_seconds
    from jsonb_to_recordset(p_assets) as asset(
      url text,
      width integer,
      height integer,
      mime_type text,
      duration_seconds integer
    )
    returning submissions_assets.id, submissions_assets.url, submissions_assets.width, submissions_assets.height
  )
  select 'created'::text, inserted.id, inserted.url, inserted.width, inserted.height
  from inserted;
end;
$function$;

create function public.delete_submission_asset(
  p_submission_id bigint,
  p_asset_id bigint
)
returns text
language plpgsql
security invoker
as $function$
declare
  submission_status public.submission_status;
begin
  select status
  into submission_status
  from public.content_submissions
  where content_submissions.id = p_submission_id
  for update;

  if not found then
    return 'not_found';
  end if;

  if submission_status <> 'pending' then
    return 'not_pending';
  end if;

  delete from public.submissions_assets
  where id = p_asset_id
    and content_submission_id = p_submission_id;

  if not found then
    return 'asset_not_found';
  end if;

  return 'deleted';
end;
$function$;

revoke all on function public.add_submission_assets(bigint, jsonb) from public, anon, authenticated;
revoke all on function public.delete_submission_asset(bigint, bigint) from public, anon, authenticated;

grant execute on function public.add_submission_assets(bigint, jsonb) to service_role;
grant execute on function public.delete_submission_asset(bigint, bigint) to service_role;
