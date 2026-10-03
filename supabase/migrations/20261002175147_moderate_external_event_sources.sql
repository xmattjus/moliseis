-- Resolution owns the submission before the source record. Contributor identity
-- is inherited from that reviewed submission, never supplied by Admin callers.
create function public.reject_external_event_submission(
  p_submission_id bigint, p_handled_by uuid, p_ignore_source boolean default false,
  p_acknowledge_current_source boolean default false, p_expected_source_hash text default null
)
returns table(outcome text, pending_submission_id bigint)
language plpgsql security definer set search_path = '' as $$
declare
  submission public.content_submissions%rowtype;
  source public.external_event_records%rowtype;
  proposal record;
  previous_context text;
begin
  if p_handled_by is null or p_ignore_source is null or p_acknowledge_current_source is null then
    raise exception using errcode = '22023', message = 'invalid_external_resolution_arguments';
  end if;
  select s.* into submission from public.content_submissions s where s.id=p_submission_id for update;
  if not found then return query select 'not_found'::text, null::bigint; return; end if;
  if submission.external_event_record_id is null then return query select 'not_imported'::text, null::bigint; return; end if;
  if submission.status <> 'pending' then return query select 'not_pending'::text, null::bigint; return; end if;
  select r.* into strict source from public.external_event_records r where r.id=submission.external_event_record_id for update;
  if p_acknowledge_current_source and (
    submission.external_moderation_hash = source.moderation_hash
    or p_expected_source_hash is distinct from source.moderation_hash
  ) then return query select 'source_changed'::text, null::bigint; return; end if;
  previous_context := current_setting('app.external_resolution', true);
  perform set_config('app.external_resolution','on',true);
  update public.content_submissions set status='rejected', handled_by=p_handled_by,
    modified_at=clock_timestamp() where id=submission.id;
  perform set_config('app.external_resolution',coalesce(previous_context,''),true);
  update public.external_event_records r set
    ignored_at=case when p_ignore_source then clock_timestamp() else r.ignored_at end,
    proposed_normalized=case when p_acknowledge_current_source then source.normalized else submission.external_normalized end,
    proposed_normalization_version=case when p_acknowledge_current_source then source.normalization_version else submission.external_normalization_version end,
    proposed_hash=case when p_acknowledge_current_source then source.moderation_hash else submission.external_moderation_hash end,
    modified_at=greatest(clock_timestamp(),r.modified_at+interval '1 microsecond')
    where r.id=source.id;
  select * into proposal from private.enqueue_external_event_proposal_if_needed(source.id,
    submission.user_id,submission.user_email,submission.user_name);
  return query select 'rejected'::text, proposal.pending_submission_id;
end;
$$;
revoke all on function public.reject_external_event_submission(bigint,uuid,boolean,boolean,text) from public,anon,authenticated;
grant execute on function public.reject_external_event_submission(bigint,uuid,boolean,boolean,text) to service_role;

-- Un-ignore does not require a pending submission and owns only the record.
-- It does not acquire historical submission locks in the reverse order.
create function public.set_source_ignored(p_external_event_record_id bigint, p_ignored boolean default false)
returns table(outcome text, pending_submission_id bigint)
language plpgsql security definer set search_path = '' as $$
declare
  source public.external_event_records%rowtype;
  contributor record;
  proposal record;
begin
  if p_ignored is distinct from false then
    raise exception using errcode='22023', message='ignore_requires_reject';
  end if;
  select r.* into source from public.external_event_records r where r.id=p_external_event_record_id for update;
  if not found then return query select 'not_found'::text,null::bigint; return; end if;
  update public.external_event_records r set ignored_at=null,
    modified_at=case when r.ignored_at is not null then greatest(clock_timestamp(),r.modified_at+interval '1 microsecond') else r.modified_at end
    where r.id=source.id;
  select s.user_id,s.user_email,s.user_name into contributor from public.content_submissions s
    where s.external_event_record_id=source.id and length(btrim(s.user_email))>0 and length(btrim(s.user_name))>0
    order by s.handled_at desc nulls last,s.id desc limit 1;
  if not found then
    raise exception using errcode='22023', message='external_importer_identity_invalid';
  end if;
  select * into proposal from private.enqueue_external_event_proposal_if_needed(source.id,
    contributor.user_id,contributor.user_email,contributor.user_name);
  return query select 'unignored'::text,proposal.pending_submission_id;
end;
$$;
revoke all on function public.set_source_ignored(bigint,boolean) from public,anon,authenticated;
grant execute on function public.set_source_ignored(bigint,boolean) to service_role;
