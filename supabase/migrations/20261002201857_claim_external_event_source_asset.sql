-- The budget timestamp is immutable once consumed, including conservative
-- migration-time consumption. Initial NULL -> timestamp remains supported.
create function private.guard_source_asset_claim_irreversible()
returns trigger language plpgsql set search_path = '' as $$
begin
  if old.source_asset_import_claimed_at is not null
     and new.source_asset_import_claimed_at is distinct from old.source_asset_import_claimed_at then
    raise exception using errcode = '23514', message = 'source_asset_claim_irreversible';
  end if;
  return new;
end;
$$;
revoke all on function private.guard_source_asset_claim_irreversible() from public, anon, authenticated, service_role;
create trigger guard_source_asset_claim_irreversible
before update of source_asset_import_claimed_at on public.content_submissions
for each row execute function private.guard_source_asset_claim_irreversible();

create function public.claim_external_event_source_asset(p_submission_id bigint)
returns table(outcome text)
language plpgsql security invoker set search_path = '' as $$
declare
  submission public.content_submissions%rowtype;
  source public.external_event_records%rowtype;
begin
  select * into submission from public.content_submissions where id=p_submission_id for update;
  if not found then return query select 'not_found'::text; return; end if;
  if submission.external_event_record_id is null then return query select 'not_imported'::text; return; end if;
  if submission.status <> 'pending' then return query select 'not_pending'::text; return; end if;
  select * into source from public.external_event_records where id=submission.external_event_record_id for update;
  if not found then return query select 'not_found'::text; return; end if;
  if source.event_id is not null then return query select 'source_already_linked'::text; return; end if;
  if submission.source_asset_import_claimed_at is not null then return query select 'already_claimed'::text; return; end if;
  if exists(select 1 from public.submissions_assets where content_submission_id=submission.id) then return query select 'assets_present'::text; return; end if;
  update public.content_submissions set source_asset_import_claimed_at=clock_timestamp() where id=submission.id;
  return query select 'claimed'::text;
end;
$$;
revoke all on function public.claim_external_event_source_asset(bigint) from public, anon, authenticated;
grant execute on function public.claim_external_event_source_asset(bigint) to service_role;
notify pgrst,'reload schema';
