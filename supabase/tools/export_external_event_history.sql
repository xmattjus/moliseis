-- psql -v legacy_importer_user_id=<audited UUID> --tuples-only --no-align -f ...
-- Private SQL JSONB export boundary: preserves timestamps and full float values.
-- This query is read-only. Do not use PostgREST rows as this tool's drift baseline.
select jsonb_build_object('submissions',coalesce(jsonb_agg(to_jsonb(s) order by s.id),'[]'::jsonb))
from public.content_submissions s where s.user_id=:'legacy_importer_user_id'::uuid;
