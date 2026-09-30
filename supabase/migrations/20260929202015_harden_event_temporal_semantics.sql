-- Persist only chronological event intervals. The completed production audit
-- found no invalid rows, so these checks require no remediation migration.
alter table public.content_submissions
  add constraint content_submissions_end_date_requires_start_date_check
    check (end_date is null or start_date is not null),
  add constraint content_submissions_end_date_not_before_start_date_check
    check (end_date is null or end_date >= start_date);

-- events.start_date is already NOT NULL, so an end-requires-start check would
-- be redundant here. Keep only the chronological interval constraint.
alter table public.events
  add constraint events_end_date_not_before_start_date_check
    check (end_date is null or end_date >= start_date);
