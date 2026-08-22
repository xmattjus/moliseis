set local check_function_bodies = off;

alter default privileges for role "postgres" in schema "public" revoke all on sequences from "anon";

alter default privileges for role "postgres" in schema "public" revoke all on sequences from "authenticated";

alter default privileges for role "postgres" in schema "public" revoke all on sequences from "service_role";

create schema "private";

create extension "moddatetime" schema "extensions";

create extension "pg_cron";

create extension "pg_net" schema "extensions";

create table "public"."cities" (
  "id"                bigint                   generated always as identity not null,
  "name"              text                     not null,
  "description_delta" jsonb,
  "created_at"        timestamp with time zone not null default now(),
  "modified_at"       timestamp with time zone not null default now(),
  "deleted_at"        timestamp with time zone,
  constraint "cities_name_key" unique (name),
  constraint "cities_pkey" primary key (id)
);

alter table "public"."cities"
  enable row level security;

create table "public"."content_submissions" (
  "id"                        bigint                   generated always as identity not null,
  "city"                      text                     not null,
  "name"                      text                     not null,
  "description"               text,
  "latitude"                  double precision,
  "longitude"                 double precision,
  "address"                   text,
  "start_date"                timestamp with time zone,
  "end_date"                  timestamp with time zone,
  "user_email"                text                     not null,
  "user_name"                 text                     not null,
  "user_id"                   uuid                     not null,
  "created_at"                timestamp with time zone not null default now(),
  "modified_at"               timestamp with time zone not null default now(),
  "handled_at"                timestamp with time zone,
  "handled_by"                uuid,
  "rejection_reason"          text,
  "internal_notes"            text,
  "description_delta"         jsonb,
  "status_email_state"        text,
  "status_email_key"          text,
  "status_email_attempted_at" timestamp with time zone,
  "status_email_sent_at"      timestamp with time zone,
  "status_email_message_id"   text,
  "status_email_last_error"   text,
  constraint "content_submissions_address_length_check" check ((char_length(address) <= 250)),
  constraint "content_submissions_city_length_check" check ((char_length(city) <= 100)),
  constraint "content_submissions_description_delta_requires_description_chec" check (((description_delta IS NULL) OR (description IS NOT NULL))),
  constraint "content_submissions_description_delta_type_check" check (((description_delta IS NULL) OR (jsonb_typeof(description_delta) = 'array'::text))),
  constraint "content_submissions_description_length_check" check ((char_length(description) <= 5000)),
  constraint "content_submissions_name_length_check" check ((char_length(name) <= 150)),
  constraint "content_submissions_pkey" primary key (id),
  constraint "content_submissions_status_email_state_check"
    check (((status_email_state IS NULL) OR (status_email_state = ANY (ARRAY['sending'::text, 'sent'::text, 'failed'::text])))),
  constraint "content_submissions_user_email_length_check" check ((char_length(user_email) <= 320)),
  constraint "content_submissions_user_name_length_check" check ((char_length(user_name) <= 100))
);

alter table "public"."content_submissions"
  enable row level security;

create table "public"."events" (
  "id"                bigint                   generated always as identity not null,
  "name"              text                     not null,
  "description"       text,
  "description_delta" jsonb,
  "start_date"        timestamp with time zone not null,
  "end_date"          timestamp with time zone,
  "latitude"          double precision         not null,
  "longitude"         double precision         not null,
  "city_id"           bigint,
  "created_at"        timestamp with time zone not null default now(),
  "modified_at"       timestamp with time zone not null default now(),
  "deleted_at"        timestamp with time zone,
  constraint "events_latitude_check" check (((latitude >= ('-90'::integer)::double precision) AND (latitude <= (90)::double precision))),
  constraint "events_longitude_check" check (((longitude >= ('-180'::integer)::double precision) AND (longitude <= (180)::double precision))),
  constraint "events_pkey" primary key (id)
);

alter table "public"."events"
  enable row level security;

create table "public"."media" (
  "id"          bigint                   generated always as identity not null,
  "url"         text                     not null,
  "description" text,
  "author"      text,
  "license"     text,
  "license_url" text,
  "width"       integer                  not null,
  "height"      integer                  not null,
  "event_id"    bigint,
  "place_id"    bigint,
  "created_at"  timestamp with time zone not null default now(),
  "modified_at" timestamp with time zone not null default now(),
  "deleted_at"  timestamp with time zone,
  constraint "media_exactly_one_parent" check (((event_id IS NULL) <> (place_id IS NULL))),
  constraint "media_pkey" primary key (id),
  constraint "media_positive_dimensions" check (((width > 0) AND (height > 0))),
  constraint "media_url_format" check ((url ~~ 'https://%'::text))
);

alter table "public"."media"
  enable row level security;

create table "public"."places" (
  "id"                bigint                   generated always as identity not null,
  "name"              text                     not null,
  "description"       text,
  "description_delta" jsonb,
  "latitude"          double precision         not null,
  "longitude"         double precision         not null,
  "city_id"           bigint,
  "created_at"        timestamp with time zone not null default now(),
  "modified_at"       timestamp with time zone not null default now(),
  "deleted_at"        timestamp with time zone,
  constraint "places_latitude_check" check (((latitude >= ('-90'::integer)::double precision) AND (latitude <= (90)::double precision))),
  constraint "places_longitude_check" check (((longitude >= ('-180'::integer)::double precision) AND (longitude <= (180)::double precision))),
  constraint "places_pkey" primary key (id)
);

alter table "public"."places"
  enable row level security;

create table "public"."submission_rate_limits" (
  "user_id"           uuid                     not null,
  "submission_count"  integer                  not null default 0,
  "window_started_at" timestamp with time zone not null,
  constraint "submission_rate_limits_pkey" primary key (user_id)
);

alter table "public"."submission_rate_limits"
  enable row level security;

create table "public"."submissions_assets" (
  "id"                    bigint  generated always as identity not null,
  "url"                   text    not null,
  "width"                 integer not null,
  "height"                integer not null,
  "mime_type"             text,
  "duration_seconds"      integer,
  "content_submission_id" bigint  not null,
  constraint "submissions_assets_pkey" primary key (id)
);

alter table "public"."submissions_assets"
  enable row level security;

create type "public"."content_category" as enum (
  'unknown',
  'nature',
  'history',
  'folklore',
  'food',
  'allure',
  'experience'
);

alter table "public"."content_submissions"
  add column "category" public.content_category not null default 'unknown'::public.content_category;

alter table "public"."events"
  add column "category" public.content_category not null default 'unknown'::public.content_category;

alter table "public"."places"
  add column "category" public.content_category not null default 'unknown'::public.content_category;

create type "public"."submission_status" as enum (
  'pending',
  'accepted',
  'rejected'
);

alter table "public"."content_submissions"
  add column "status" public.submission_status not null default 'pending'::public.submission_status;

create or replace function private.notify_submission_status_webhook()
  returns trigger
  language plpgsql
  security definer
  set search_path to ''
  AS $function$
DECLARE
  function_url text;
  webhook_secret text;
BEGIN
  BEGIN
    SELECT decrypted_secret
    INTO function_url
    FROM vault.decrypted_secrets
    WHERE name = 'notify_submission_status_url'
    LIMIT 1;

    SELECT decrypted_secret
    INTO webhook_secret
    FROM vault.decrypted_secrets
    WHERE name = 'notify_submission_status_webhook_secret'
    LIMIT 1;

    IF function_url IS NULL OR webhook_secret IS NULL THEN
      RAISE WARNING
        'notify-submission-status Vault configuration is missing';

      RETURN NEW;
    END IF;

    PERFORM net.http_post(
      url := function_url,
      headers := jsonb_build_object(
        'Content-Type', 'application/json',
        'x-webhook-secret', webhook_secret
      ),
      body := jsonb_build_object(
        'type', TG_OP,
        'schema', TG_TABLE_SCHEMA,
        'table', TG_TABLE_NAME,
        'record', jsonb_build_object(
          'id', NEW.id,
          'status', NEW.status
        ),
        'old_record', jsonb_build_object(
          'id', OLD.id,
          'status', OLD.status
        )
      ),
      timeout_milliseconds := 10000
    );
  EXCEPTION
    WHEN OTHERS THEN
      -- Notification failures must not roll back moderation updates.
      RAISE WARNING
        'Could not enqueue notify-submission-status: %',
        SQLERRM;
  END;

  RETURN NEW;
END;
$function$;

create or replace function public.rls_auto_enable()
  returns event_trigger
  language plpgsql
  security definer
  set search_path to 'pg_catalog'
  AS $function$
DECLARE
  cmd record;
BEGIN
  FOR cmd IN
    SELECT *
    FROM pg_event_trigger_ddl_commands()
    WHERE command_tag IN ('CREATE TABLE', 'CREATE TABLE AS', 'SELECT INTO')
      AND object_type IN ('table','partitioned table')
  LOOP
     IF cmd.schema_name IS NOT NULL AND cmd.schema_name IN ('public') AND cmd.schema_name NOT IN ('pg_catalog','information_schema') AND cmd.schema_name NOT LIKE 'pg_toast%' AND cmd.schema_name NOT LIKE 'pg_temp%' THEN
      BEGIN
        EXECUTE format('alter table if exists %s enable row level security', cmd.object_identity);
        RAISE LOG 'rls_auto_enable: enabled RLS on %', cmd.object_identity;
      EXCEPTION
        WHEN OTHERS THEN
          RAISE LOG 'rls_auto_enable: failed to enable RLS on %', cmd.object_identity;
      END;
     ELSE
        RAISE LOG 'rls_auto_enable: skip % (either system schema or not in enforced list: %.)', cmd.object_identity, cmd.schema_name;
     END IF;
  END LOOP;
END;
$function$;

alter table "public"."content_submissions"
  add constraint "content_submissions_user_id_fkey" foreign key (user_id) references auth.users(id);

alter table "public"."events"
  add constraint "events_city_id_fkey" foreign key (city_id) references public.cities(id) on delete restrict;

alter table "public"."media"
  add constraint "media_event_id_fkey" foreign key (event_id) references public.events(id) on delete cascade;

alter table "public"."places"
  add constraint "places_city_id_fkey" foreign key (city_id) references public.cities(id) on delete restrict;

alter table "public"."media"
  add constraint "media_place_id_fkey" foreign key (place_id) references public.places(id) on delete cascade;

alter table "public"."submission_rate_limits"
  add constraint "submission_rate_limits_user_id_fkey" foreign key (user_id) references auth.users(id);

alter table "public"."submissions_assets"
  add constraint "submissions_assets_content_submission_id_fkey" foreign key (content_submission_id) references public.content_submissions(id) on delete cascade;

create index events_active_idx on public.events using btree (id)
  where (deleted_at is null);

create index events_category_idx on public.events using btree (category);

create index events_city_id_idx on public.events using btree (city_id);

create index media_active_event_idx on public.media using btree (event_id)
  where (deleted_at is null);

create index media_active_place_idx on public.media using btree (place_id)
  where (deleted_at is null);

create index places_active_idx on public.places using btree (id)
  where (deleted_at is null);

create index places_category_idx on public.places using btree (category);

create index places_city_id_idx on public.places using btree (city_id);

create trigger handle_modified_at
  before update on public.cities
  for each row
  when ((NOT (new.deleted_at IS DISTINCT FROM old.deleted_at)))
  execute function extensions.moddatetime('modified_at');

create trigger handle_handled_at
  before update on public.content_submissions
  for each row
  when ((new.status IS DISTINCT FROM old.status))
  execute function extensions.moddatetime('handled_at');

create trigger "notify-submission-status"
  after update of status on public.content_submissions
  for each row
  when (((old.status = 'pending'::public.submission_status) AND ((new.status = 'accepted'::public.submission_status) OR (new.status = 'rejected'::public.submission_status))))
  execute function private.notify_submission_status_webhook();

create trigger handle_modified_at
  before update on public.events
  for each row
  when ((NOT (new.deleted_at IS DISTINCT FROM old.deleted_at)))
  execute function extensions.moddatetime('modified_at');

create trigger handle_modified_at
  before update on public.media
  for each row
  when ((NOT (new.deleted_at IS DISTINCT FROM old.deleted_at)))
  execute function extensions.moddatetime('modified_at');

create trigger handle_modified_at
  before update on public.places
  for each row
  when ((NOT (new.deleted_at IS DISTINCT FROM old.deleted_at)))
  execute function extensions.moddatetime('modified_at');

create policy "Disable delete for all users" on "public"."cities"
  for delete
  to PUBLIC
  using (false);

create policy "Disable insert for all users" on "public"."cities"
  for insert
  to PUBLIC
  with check (false);

create policy "Disable update for all users" on "public"."cities"
  for update
  to PUBLIC
  using (false)
  with check (false);

create policy "Enable select for all users" on "public"."cities"
  for select
  to PUBLIC
  using (true);

create policy "deny delete until admin dashboard ships" on "public"."content_submissions"
  for delete
  to "anon", "authenticated"
  using (false);

create policy "deny insert until admin dashboard ships" on "public"."content_submissions"
  for insert
  to "anon", "authenticated"
  with check (false);

create policy "deny select until admin dashboard ships" on "public"."content_submissions"
  for select
  to "anon", "authenticated"
  using (false);

create policy "deny update until admin dashboard ships" on "public"."content_submissions"
  for update
  to "anon", "authenticated"
  using (false)
  with check (false);

create policy "Disable delete for all users" on "public"."events"
  for delete
  to PUBLIC
  using (false);

create policy "Disable insert for all users" on "public"."events"
  for insert
  to PUBLIC
  with check (false);

create policy "Disable update for all users" on "public"."events"
  for update
  to PUBLIC
  using (false)
  with check (false);

create policy "Enable select for all users" on "public"."events"
  for select
  to PUBLIC
  using (true);

create policy "Disable delete for all users" on "public"."media"
  for delete
  to PUBLIC
  using (false);

create policy "Disable insert for all users" on "public"."media"
  for insert
  to PUBLIC
  with check (false);

create policy "Disable update for all users" on "public"."media"
  for update
  to PUBLIC
  using (false)
  with check (false);

create policy "Enable select for all users" on "public"."media"
  for select
  to PUBLIC
  using (true);

create policy "Disable delete for all users" on "public"."places"
  for delete
  to PUBLIC
  using (false);

create policy "Disable insert for all users" on "public"."places"
  for insert
  to PUBLIC
  with check (false);

create policy "Disable update for all users" on "public"."places"
  for update
  to PUBLIC
  using (false)
  with check (false);

create policy "Enable select for all users" on "public"."places"
  for select
  to PUBLIC
  using (true);

create policy "deny delete until admin dashboard ships" on "public"."submission_rate_limits"
  for delete
  to "anon", "authenticated"
  using (false);

create policy "deny insert until admin dashboard ships" on "public"."submission_rate_limits"
  for insert
  to "anon", "authenticated"
  with check (false);

create policy "deny select until admin dashboard ships" on "public"."submission_rate_limits"
  for select
  to "anon", "authenticated"
  using (false);

create policy "deny update until admin dashboard ships" on "public"."submission_rate_limits"
  for update
  to "anon", "authenticated"
  using (false)
  with check (false);

create policy "deny delete until admin dashboard ships" on "public"."submissions_assets"
  for delete
  to "anon", "authenticated"
  using (false);

create policy "deny insert until admin dashboard ships" on "public"."submissions_assets"
  for insert
  to "anon", "authenticated"
  with check (false);

create policy "deny select until admin dashboard ships" on "public"."submissions_assets"
  for select
  to "anon", "authenticated"
  using (false);

create policy "deny update until admin dashboard ships" on "public"."submissions_assets"
  for update
  to "anon", "authenticated"
  using (false)
  with check (false);

create event trigger "ensure_rls"
  on ddl_command_end
  when tag in ('CREATE TABLE', 'CREATE TABLE AS', 'SELECT INTO')
  execute function "public"."rls_auto_enable"();

comment on column "public"."content_submissions"."status_email_attempted_at" is 'Istante in cui la Edge Function ha acquisito il tentativo di invio.';

comment on column "public"."content_submissions"."status_email_key" is 'SHA-256 di submission id, status finale e handled_at; usato per evitare duplicati concorrenti.';

comment on column "public"."content_submissions"."status_email_last_error" is 'Ultimo errore registrato durante la preparazione o l’invio della notifica.';

comment on column "public"."content_submissions"."status_email_message_id" is 'messageId restituito dall’API transazionale Brevo.';

comment on column "public"."content_submissions"."status_email_sent_at" is 'Istante in cui Brevo ha accettato la richiesta di invio.';

comment on column "public"."content_submissions"."status_email_state" is 'Stato dell’ultimo tentativo di notifica relativo alla transizione identificata da status_email_key.';

comment on extension "moddatetime" is 'functions for tracking last modification time';

comment on extension "pg_cron" is 'Job scheduler for PostgreSQL';

comment on extension "pg_net" is 'Async HTTP';

revoke all on function "private"."notify_submission_status_webhook"() from public;

grant execute on function "private"."notify_submission_status_webhook"() to "postgres";

revoke all on function "public"."rls_auto_enable"() from public;

grant execute on function "public"."rls_auto_enable"() to "postgres";

grant create, usage on schema "private" to "postgres";

grant delete, insert, maintain, references, select, trigger, truncate, update on table "public"."cities" to "anon", "authenticated", "postgres", "service_role";

grant delete, insert, maintain, references, select, trigger, truncate, update on table "public"."content_submissions" to "anon", "authenticated", "postgres", "service_role";

grant delete, insert, maintain, references, select, trigger, truncate, update on table "public"."events" to "anon", "authenticated", "postgres", "service_role";

grant delete, insert, maintain, references, select, trigger, truncate, update on table "public"."media" to "anon", "authenticated", "postgres", "service_role";

grant delete, insert, maintain, references, select, trigger, truncate, update on table "public"."places" to "anon", "authenticated", "postgres", "service_role";

grant delete, insert, maintain, references, select, trigger, truncate, update on table "public"."submission_rate_limits" to "anon", "authenticated", "postgres", "service_role";

grant delete, insert, maintain, references, select, trigger, truncate, update on table "public"."submissions_assets" to "anon", "authenticated", "postgres", "service_role";

grant usage on type "public"."content_category" to "postgres";

grant usage on type "public"."submission_status" to "postgres";

select cron.schedule_in_database('import-external-events-eventimolise', '0 22,23 * * *', '
  select net.http_post(
    url := (
      select decrypted_secret
      from vault.decrypted_secrets
      where name = ''import_external_events_function_url''
      limit 1
    ),
    headers := jsonb_build_object(
      ''Content-Type'', ''application/json'',
      ''x-import-secret'', (
        select decrypted_secret
        from vault.decrypted_secrets
        where name = ''import_external_events_cron_secret''
        limit 1
      )
    ),
    body := jsonb_build_object(
      ''source'', ''eventimolise'',
      ''dry_run'', false,
      ''limit'', 20,
      ''mode'', ''scheduled''
    ),
    timeout_milliseconds := 120000
  ) as request_id;
  ', 'postgres', null, true);

