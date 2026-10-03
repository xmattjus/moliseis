-- Persist the post-cut-over retirement on fresh schema replay as well.
-- The provenance cron is operator-managed; migrations must never activate it.
do $$
declare
  legacy_job_id bigint;
begin
  for legacy_job_id in
    select jobid from cron.job
    where jobname = 'import-external-events-eventimolise'
  loop
    perform cron.unschedule(legacy_job_id);
  end loop;
end;
$$;
