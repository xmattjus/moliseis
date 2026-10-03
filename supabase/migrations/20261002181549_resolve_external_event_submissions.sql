-- Replace the three-argument signature; defaults preserve legacy request envelopes
-- without ambiguous PostgREST overloads.
drop function public.promote_content_submission(bigint,text,uuid);

create or replace function public.promote_content_submission(
  p_submission_id bigint,
  p_target text,
  p_handled_by uuid,
  p_acknowledge_current_source boolean default false,
  p_expected_source_hash text default null
)
returns table (
  outcome text,
  target_type text,
  entity_id bigint
)
language plpgsql
security definer
set search_path = ''
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
  reviewed_submission public.content_submissions%rowtype;
  source_record public.external_event_records%rowtype;
  previous_context text;
  proposal record;
begin
  -- Programmer/API contract errors are validated before acquiring any lock.
  -- The function is deliberately not STRICT: PostgREST RPC calls with NULL
  -- arguments silently skip STRICT functions and return a null result instead
  -- of raising, so null inputs are rejected explicitly here.
  if p_target is null or p_target not in ('place', 'event') then
    raise exception 'p_target must be ''place'' or ''event'''
      using errcode = '22023';
  end if;

  if p_handled_by is null or p_acknowledge_current_source is null then
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

  -- Imported resolution follows submission -> record before Event creation.
  select s.* into reviewed_submission from public.content_submissions s where s.id=p_submission_id;
  if reviewed_submission.external_event_record_id is not null then
    select r.* into strict source_record from public.external_event_records r
      where r.id=reviewed_submission.external_event_record_id for update;
    if p_target='event' and source_record.event_id is not null then
      return query select 'source_already_linked'::text,null::text,null::bigint;
      return;
    end if;
  end if;

  if p_acknowledge_current_source and (
    reviewed_submission.external_event_record_id is null
    or reviewed_submission.external_moderation_hash = source_record.moderation_hash
    or p_expected_source_hash is distinct from source_record.moderation_hash
  ) then
    return query select 'source_changed'::text,null::text,null::bigint;
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
  -- explicit status-resolution modified_at (content edits have a DB-owned token),
  -- and accepted status commit
  -- in one statement so the promotion-link CHECK sees one consistent row
  -- version. handled_at stays owned by the handle_handled_at trigger and the
  -- notify-submission-status trigger observes pending -> accepted; its pg_net
  -- enqueue rolls back with this transaction while its own failures are
  -- swallowed there and never roll back moderation.
  if reviewed_submission.external_event_record_id is not null then
    previous_context := current_setting('app.external_resolution',true);
    perform set_config('app.external_resolution','on',true);
  end if;
  update public.content_submissions
  set promoted_place_id =
        case when p_target = 'place' then new_entity_id end,
      promoted_event_id =
        case when p_target = 'event' then new_entity_id end,
      handled_by = p_handled_by,
      modified_at = now(),
      status = 'accepted'
  where content_submissions.id = p_submission_id;

  if reviewed_submission.external_event_record_id is not null then
    perform set_config('app.external_resolution',coalesce(previous_context,''),true);
    update public.external_event_records r set event_id=new_entity_id,
      proposed_normalized=case when p_acknowledge_current_source then source_record.normalized else reviewed_submission.external_normalized end,
      proposed_hash=case when p_acknowledge_current_source then source_record.moderation_hash else reviewed_submission.external_moderation_hash end,
      proposed_normalization_version=case when p_acknowledge_current_source then source_record.normalization_version else reviewed_submission.external_normalization_version end,
      modified_at=greatest(clock_timestamp(),r.modified_at+interval '1 microsecond')
      where r.id=source_record.id;
    select * into proposal from private.enqueue_external_event_proposal_if_needed(source_record.id,
      reviewed_submission.user_id,reviewed_submission.user_email,reviewed_submission.user_name);
  end if;

  return query select 'created'::text, p_target, new_entity_id;
end;
$function$;

revoke all on function public.promote_content_submission(bigint, text, uuid, boolean, text) from public, anon, authenticated;

grant execute on function public.promote_content_submission(bigint, text, uuid, boolean, text) to service_role;

notify pgrst, 'reload schema';

create function public.link_content_submission_to_event(
  p_submission_id bigint, p_target_event_id bigint, p_handled_by uuid,
  p_acknowledge_current_source boolean default false, p_expected_source_hash text default null
)
returns table(outcome text,event_id bigint,pending_submission_id bigint)
language plpgsql security definer set search_path='' as $$
declare
  submission public.content_submissions%rowtype;
  source public.external_event_records%rowtype;
  target public.events%rowtype;
  proposal record;
  previous_context text;
begin
  if p_target_event_id is null or p_target_event_id<=0 or p_handled_by is null or p_acknowledge_current_source is null then
    raise exception using errcode='22023',message='invalid_external_resolution_arguments';
  end if;
  select s.* into submission from public.content_submissions s where s.id=p_submission_id for update;
  if not found then return query select 'not_found'::text,null::bigint,null::bigint; return; end if;
  -- Durable same-target discovery precedes pending, discriminator, source and
  -- Event checks, so a committed resolution can be retried without new writes.
  if submission.status='accepted' and submission.target_event_id is not null then
    if submission.target_event_id=p_target_event_id then
      return query select 'already_resolved'::text,p_target_event_id,null::bigint;
    else return query select 'target_conflict'::text,null::bigint,null::bigint; end if;
    return;
  end if;
  if submission.status<>'pending' then return query select 'not_pending'::text,null::bigint,null::bigint; return; end if;
  if submission.start_date is null then return query select 'not_event_submission'::text,null::bigint,null::bigint; return; end if;
  if submission.external_event_record_id is not null then
    select r.* into strict source from public.external_event_records r where r.id=submission.external_event_record_id for update;
    if source.event_id is not null and source.event_id<>p_target_event_id then
      return query select 'relink_conflict'::text,null::bigint,null::bigint; return;
    end if;
  end if;
  if p_acknowledge_current_source and (
    submission.external_event_record_id is null or submission.external_moderation_hash=source.moderation_hash
    or p_expected_source_hash is distinct from source.moderation_hash
  ) then return query select 'source_changed'::text,null::bigint,null::bigint; return; end if;
  select e.* into target from public.events e where e.id=p_target_event_id for update;
  if not found then return query select 'event_not_found'::text,null::bigint,null::bigint; return; end if;
  if target.deleted_at is not null then return query select 'event_inactive'::text,null::bigint,null::bigint; return; end if;
  if submission.external_event_record_id is not null then
    previous_context:=current_setting('app.external_resolution',true);
    perform set_config('app.external_resolution','on',true);
  end if;
  update public.content_submissions set status='accepted',target_event_id=p_target_event_id,
    handled_by=p_handled_by,modified_at=clock_timestamp() where id=submission.id;
  if submission.external_event_record_id is not null then
    perform set_config('app.external_resolution',coalesce(previous_context,''),true);
    update public.external_event_records r set event_id=p_target_event_id,
      proposed_normalized=case when p_acknowledge_current_source then source.normalized else submission.external_normalized end,
      proposed_hash=case when p_acknowledge_current_source then source.moderation_hash else submission.external_moderation_hash end,
      proposed_normalization_version=case when p_acknowledge_current_source then source.normalization_version else submission.external_normalization_version end,
      modified_at=greatest(clock_timestamp(),r.modified_at+interval '1 microsecond') where r.id=source.id;
    select * into proposal from private.enqueue_external_event_proposal_if_needed(source.id,
      submission.user_id,submission.user_email,submission.user_name);
    return query select 'linked'::text,p_target_event_id,proposal.pending_submission_id;
  else return query select 'linked'::text,p_target_event_id,null::bigint; end if;
end;
$$;
revoke all on function public.link_content_submission_to_event(bigint,bigint,uuid,boolean,text) from public,anon,authenticated;
grant execute on function public.link_content_submission_to_event(bigint,bigint,uuid,boolean,text) to service_role;
notify pgrst,'reload schema';

-- Only the service-role Edge can supply groups. Values always come from the
-- locked moderated submission, never from RPC body field values or SQL merge.
create function public.apply_external_event_submission(
  p_submission_id bigint,p_target_event_id bigint,p_handled_by uuid,
  p_groups_to_apply text[],p_submission_version_token text,p_event_version_token text,
  p_acknowledge_current_source boolean default false,p_expected_source_hash text default null
)
returns table(outcome text,event_id bigint,pending_submission_id bigint)
language plpgsql security definer set search_path='' as $$
declare
  submission public.content_submissions%rowtype;
  source public.external_event_records%rowtype;
  target public.events%rowtype;
  proposal record;
  resolved_city_id bigint;
  previous_context text;
  submission_token timestamptz;
  event_token timestamptz;
begin
  if p_target_event_id is null or p_target_event_id<=0 or p_handled_by is null or p_acknowledge_current_source is null then
    raise exception using errcode='22023',message='invalid_external_resolution_arguments';
  end if;
  select s.* into submission from public.content_submissions s where s.id=p_submission_id for update;
  if not found then return query select 'not_found'::text,null::bigint,null::bigint; return; end if;
  if submission.status='accepted' and submission.target_event_id is not null then
    if submission.target_event_id=p_target_event_id then
      return query select 'already_resolved'::text,p_target_event_id,null::bigint;
    else return query select 'target_conflict'::text,null::bigint,null::bigint; end if;
    return;
  end if;
  if submission.status<>'pending' then return query select 'not_pending'::text,null::bigint,null::bigint; return; end if;
  if submission.external_event_record_id is null then return query select 'not_imported'::text,null::bigint,null::bigint; return; end if;
  select r.* into strict source from public.external_event_records r where r.id=submission.external_event_record_id for update;
  if source.event_id is null then return query select 'source_not_linked'::text,null::bigint,null::bigint; return; end if;
  if source.event_id<>p_target_event_id then return query select 'relink_conflict'::text,null::bigint,null::bigint; return; end if;
  if source.proposed_normalized is null then return query select 'base_required'::text,null::bigint,null::bigint; return; end if;
  if source.proposed_normalization_version<>submission.external_normalization_version or source.normalization_version<>submission.external_normalization_version then
    return query select 'normalization_mismatch'::text,null::bigint,null::bigint; return;
  end if;
  if p_acknowledge_current_source and (submission.external_moderation_hash=source.moderation_hash
    or p_expected_source_hash is distinct from source.moderation_hash) then
    return query select 'source_changed'::text,null::bigint,null::bigint; return;
  end if;
  select e.* into target from public.events e where e.id=p_target_event_id for update;
  if not found then return query select 'event_not_found'::text,null::bigint,null::bigint; return; end if;
  if target.deleted_at is not null then return query select 'event_inactive'::text,null::bigint,null::bigint; return; end if;
  begin submission_token:=p_submission_version_token::timestamptz;
  exception when invalid_datetime_format or datetime_field_overflow then
    return query select 'submission_changed'::text,null::bigint,null::bigint; return;
  end;
  if submission.modified_at is distinct from submission_token then return query select 'submission_changed'::text,null::bigint,null::bigint; return; end if;
  begin event_token:=p_event_version_token::timestamptz;
  exception when invalid_datetime_format or datetime_field_overflow then
    return query select 'event_changed'::text,null::bigint,null::bigint; return;
  end;
  if target.modified_at is distinct from event_token then return query select 'event_changed'::text,null::bigint,null::bigint; return; end if;
  -- Locked Event readiness applies even when schedule is not an applied group.
  if submission.start_date is null then return query select 'start_date_required'::text,null::bigint,null::bigint; return; end if;
  if submission.end_date<submission.start_date then return query select 'invalid_date_range'::text,null::bigint,null::bigint; return; end if;
  if p_groups_to_apply is null or array_ndims(p_groups_to_apply)>1 or exists (
    select 1 from unnest(p_groups_to_apply) g where g is null or g not in ('name','category','description','schedule','location')
  ) or cardinality(p_groups_to_apply)<>(select count(distinct g) from unnest(p_groups_to_apply) g) then
    return query select 'invalid_groups'::text,null::bigint,null::bigint; return;
  end if;
  if 'location'=any(p_groups_to_apply) then
    if submission.latitude is null or submission.longitude is null then
      return query select 'coordinates_required'::text,null::bigint,null::bigint; return;
    end if;
    if submission.latitude < -90::double precision or submission.latitude > 90::double precision
      or submission.longitude < -180::double precision or submission.longitude > 180::double precision then
      return query select 'invalid_coordinates'::text,null::bigint,null::bigint; return;
    end if;
    select c.id into resolved_city_id from public.cities c where c.name=submission.city and c.deleted_at is null for share;
    if not found then return query select 'city_not_found'::text,null::bigint,null::bigint; return; end if;
  end if;
  if cardinality(p_groups_to_apply)>0 then
    update public.events e set
      name=case when 'name'=any(p_groups_to_apply) then submission.name else e.name end,
      category=case when 'category'=any(p_groups_to_apply) then submission.category else e.category end,
      description=case when 'description'=any(p_groups_to_apply) then submission.description else e.description end,
      description_delta=case when 'description'=any(p_groups_to_apply) then submission.description_delta else e.description_delta end,
      start_date=case when 'schedule'=any(p_groups_to_apply) then submission.start_date else e.start_date end,
      end_date=case when 'schedule'=any(p_groups_to_apply) then submission.end_date else e.end_date end,
      all_day=case when 'schedule'=any(p_groups_to_apply) then submission.all_day else e.all_day end,
      city_id=case when 'location'=any(p_groups_to_apply) then resolved_city_id else e.city_id end,
      latitude=case when 'location'=any(p_groups_to_apply) then submission.latitude else e.latitude end,
      longitude=case when 'location'=any(p_groups_to_apply) then submission.longitude else e.longitude end
      where e.id=target.id;
  end if;
  previous_context:=current_setting('app.external_resolution',true);
  perform set_config('app.external_resolution','on',true);
  update public.content_submissions set status='accepted',target_event_id=p_target_event_id,
    handled_by=p_handled_by,modified_at=clock_timestamp() where id=submission.id;
  perform set_config('app.external_resolution',coalesce(previous_context,''),true);
  update public.external_event_records r set
    proposed_normalized=case when p_acknowledge_current_source then source.normalized else submission.external_normalized end,
    proposed_hash=case when p_acknowledge_current_source then source.moderation_hash else submission.external_moderation_hash end,
    proposed_normalization_version=case when p_acknowledge_current_source then source.normalization_version else submission.external_normalization_version end,
    modified_at=greatest(clock_timestamp(),r.modified_at+interval '1 microsecond') where r.id=source.id;
  select * into proposal from private.enqueue_external_event_proposal_if_needed(source.id,
    submission.user_id,submission.user_email,submission.user_name);
  return query select 'applied'::text,p_target_event_id,proposal.pending_submission_id;
end;
$$;
revoke all on function public.apply_external_event_submission(bigint,bigint,uuid,text[],text,text,boolean,text) from public,anon,authenticated;
grant execute on function public.apply_external_event_submission(bigint,bigint,uuid,text[],text,text,boolean,text) to service_role;
notify pgrst,'reload schema';
