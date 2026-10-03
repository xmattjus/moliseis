import type { Sql } from "npm:postgres@3.4.5";
import {
  canonicalizeEventTimestamp,
  EXTERNAL_EVENT_NORMALIZATION_VERSION,
  hashNormalizedExternalEvent,
} from "../functions/_shared/external_event_normalization.ts";
import type {
  LegacySubmission,
  MigrationPlan,
} from "./external_event_migration.ts";

import {
  identityKey,
  type SourceIdentity,
} from "./external_event_migration.ts";
import type { PreparedExternalEvent } from "../functions/import-external-events/import_logic.ts";
import { calendarDateInRome } from "../functions/import-external-events/import_logic.ts";
export function assertReleaseDate(t0: string, now: string) {
  if (
    !Number.isFinite(Date.parse(t0)) || Date.parse(t0) > Date.parse(now) ||
    calendarDateInRome(t0) !== calendarDateInRome(now)
  ) throw new Error("invalid_quiescent_t0_or_rome_date");
}
export type ProposalExplanation = {
  identity: SourceIdentity;
  source_hash: string;
  evidence_ref: string;
};
export type BackfillOptions = {
  migration_timestamp: string;
  never_attempted: Array<{ submission_id: number; evidence_ref: string }>;
  rollback: boolean;
  release_guard?: { t0: string; now?: () => string };
  verify_ingest?: {
    observations: PreparedExternalEvent[];
    importer_user_id: string;
    explanations: ProposalExplanation[];
  };
};
function stableRow(row: LegacySubmission): string {
  const ignored = new Set([
    "external_event_record_id",
    "external_normalized",
    "external_normalization_version",
    "external_moderation_hash",
    "source_asset_import_claimed_at",
  ]);
  const dates = new Set([
    "created_at",
    "modified_at",
    "handled_at",
    "start_date",
    "end_date",
    "status_email_attempted_at",
    "status_email_sent_at",
  ]);
  return JSON.stringify(
    Object.keys(row).sort().filter((key) => !ignored.has(key)).map((key) => {
      const value = row[key as keyof LegacySubmission];
      return [
        key,
        dates.has(key) && typeof value === "string"
          ? canonicalizeEventTimestamp(value)
          : value,
      ];
    }),
  );
}

/** Privileged one-shot tooling, not an exposed migration API. All plans atomic. */
export async function backfillVerifiedPlans(
  sql: Sql,
  plans: MigrationPlan[],
  options: BackfillOptions,
) {
  const timestamp = canonicalizeEventTimestamp(options.migration_timestamp);
  const releaseGuard = () => {
    if (options.release_guard) {
      assertReleaseDate(
        options.release_guard.t0,
        options.release_guard.now?.() ?? new Date().toISOString(),
      );
    }
  };
  releaseGuard();
  const eligiblePending = new Set(
    plans.flatMap((plan) =>
      plan.tuples.filter((tuple) =>
        plan.history.some((row) =>
          row.id === tuple.submission_id && row.status === "pending"
        )
      ).map((tuple) => tuple.submission_id)
    ),
  );
  const exemptions = new Set<number>();
  for (const exemption of options.never_attempted) {
    if (
      !eligiblePending.has(exemption.submission_id) ||
      exemptions.has(exemption.submission_id) || !exemption.evidence_ref?.trim()
    ) throw new Error("invalid_never_attempted_evidence");
    exemptions.add(exemption.submission_id);
  }
  const result: Array<
    {
      record_id: number;
      pending_submission_id: number | null;
      pending_created: boolean;
    }
  > = [];
  let rolledBackResult: typeof result = [];
  try {
    await sql.begin(async (tx) => {
      const history = plans.flatMap((plan) => plan.history).sort((a, b) =>
        a.id - b.id
      );
      if (new Set(history.map((row) => row.id)).size !== history.length) {
        throw new Error("duplicate_backfill_submission_id");
      }
      const locked = new Map<number, LegacySubmission>();
      // Lock all existing submissions first, before any record or Event lock.
      for (const exported of history) {
        const [entry] =
          await tx`select to_jsonb(s) as row from public.content_submissions s where id=${exported.id} for update`;
        if (!entry || stableRow(entry.row) !== stableRow(exported)) {
          throw new Error("exported_submission_changed");
        }
        locked.set(exported.id, entry.row);
      }
      const records = new Map<
        MigrationPlan,
        { row: Record<string, unknown>; inserted: boolean }
      >();
      const orderedPlans = [...plans].sort((a, b) =>
        JSON.stringify(a.identity).localeCompare(JSON.stringify(b.identity))
      );
      for (
        const plan of orderedPlans
      ) {
        const [inserted] =
          await tx`insert into public.external_event_records(provider,external_id,occurrence_key,normalized,normalization_version,moderation_hash,proposed_normalized,proposed_normalization_version,proposed_hash,event_id,ignored_at,metadata,metadata_version)
          values (${plan.identity.provider},${plan.identity.external_id},${plan.identity.occurrence_key},${
            tx.json(plan.current)
          },${EXTERNAL_EVENT_NORMALIZATION_VERSION},${plan.current_hash},${
            plan.proposed === null ? null : tx.json(plan.proposed)
          },${
            plan.proposed === null ? null : EXTERNAL_EVENT_NORMALIZATION_VERSION
          },${plan.proposed_hash},null,${
            plan.ignored ? timestamp : null
          }::text::timestamptz,'{}',1)
          on conflict(provider,external_id,occurrence_key) do nothing returning id`;
        const [record] =
          await tx`select to_jsonb(r) as row from public.external_event_records r where provider=${plan.identity.provider} and external_id=${plan.identity.external_id} and occurrence_key is not distinct from ${plan.identity.occurrence_key} for update`;
        const current = record.row;
        if (
          current.moderation_hash !== plan.current_hash ||
          current.proposed_hash !== plan.proposed_hash ||
          current.normalization_version !==
            EXTERNAL_EVENT_NORMALIZATION_VERSION ||
          current.proposed_normalization_version !==
            (plan.proposed === null
              ? null
              : EXTERNAL_EVENT_NORMALIZATION_VERSION) ||
          (!inserted && current.event_id !== plan.event_id) ||
          (current.ignored_at !== null) !== plan.ignored
        ) throw new Error("existing_record_changed");
        const [{ equalSnapshots }] = await tx`select normalized=${
          tx.json(plan.current)
        }::jsonb and proposed_normalized is not distinct from ${
          plan.proposed === null ? null : tx.json(plan.proposed)
        }::jsonb as "equalSnapshots" from public.external_event_records where id=${
          Number(current.id)
        }`;
        if (!equalSnapshots) throw new Error("existing_record_changed");
        records.set(plan, { row: current, inserted: !!inserted });
      }
      // Every record lock precedes every canonical Event lock, including batches.
      for (
        const eventId of [
          ...new Set(
            plans.map((plan) => plan.event_id).filter((id): id is number =>
              id !== null
            ),
          ),
        ].sort((a, b) => a - b)
      ) {
        const [event] =
          await tx`select id from public.events where id=${eventId} for update`;
        if (!event) throw new Error("canonical_event_missing");
      }
      for (const plan of orderedPlans) {
        const stored = records.get(plan)!;
        const current = stored.row;
        if (stored.inserted && plan.event_id !== null) {
          await tx`update public.external_event_records set event_id=${plan.event_id} where id=${
            Number(current.id)
          }`;
        }
        for (const tuple of plan.tuples) {
          const submission = locked.get(tuple.submission_id)!;
          if (submission.start_date === null) {
            throw new Error("legacy_event_start_required");
          }
          if (submission.external_event_record_id !== null) {
            if (
              submission.status === "pending" &&
              submission.source_asset_import_claimed_at === null &&
              !exemptions.has(submission.id)
            ) throw new Error("missing_legacy_asset_budget_consumption");
            if (
              submission.external_event_record_id !== current.id ||
              submission.external_moderation_hash !==
                tuple.external_moderation_hash ||
              submission.external_normalization_version !==
                tuple.external_normalization_version ||
              JSON.stringify(submission.external_normalized) !==
                JSON.stringify(tuple.external_normalized)
            ) {
              // JSONB key order is not semantically significant.
              const [{ equal }] = await tx`select ${
                tx.json(submission.external_normalized)
              }::jsonb=${
                tx.json(tuple.external_normalized)
              }::jsonb and ${submission.external_event_record_id}::bigint=${
                Number(current.id)
              }::bigint and ${submission.external_moderation_hash}=${tuple.external_moderation_hash} and ${submission.external_normalization_version}::int=${tuple.external_normalization_version}::int as equal`;
              if (!equal) throw new Error("existing_provenance_changed");
            }
            continue;
          }
          const positive = options.never_attempted.filter((entry) =>
            entry.submission_id === submission.id
          );
          if (
            positive.length > 1 ||
            positive.some((entry) => !entry.evidence_ref.trim())
          ) throw new Error("invalid_never_attempted_evidence");
          const claim = submission.status === "pending" && positive.length === 0
            ? timestamp
            : null;
          await tx`update public.content_submissions set external_event_record_id=${
            Number(current.id)
          },external_normalized=${
            tx.json(tuple.external_normalized)
          },external_normalization_version=${tuple.external_normalization_version},external_moderation_hash=${tuple.external_moderation_hash},source_asset_import_claimed_at=${claim}::text::timestamptz where id=${submission.id}`;
        }
        const seed = [...plan.history].sort((a, b) =>
          (b.handled_at == null
            ? ""
            : canonicalizeEventTimestamp(b.handled_at)).localeCompare(
              a.handled_at == null
                ? ""
                : canonicalizeEventTimestamp(a.handled_at),
            ) || b.id - a.id
        )[0];
        const [proposal] =
          await tx`select * from private.enqueue_external_event_proposal_if_needed(${
            Number(current.id)
          },${seed.user_id}::uuid,${seed.user_email},${seed.user_name})`;
        result.push({
          record_id: Number(current.id),
          pending_submission_id: proposal.pending_submission_id === null
            ? null
            : Number(proposal.pending_submission_id),
          pending_created: proposal.pending_created,
        });
        // Existing records are validation-only on replay; no watermark/content update.
      }
      if (options.verify_ingest) {
        if (!options.rollback) {
          throw new Error("production_contract_dry_run_requires_rollback");
        }
        const verification = options.verify_ingest;
        const ids = new Set(result.map((entry) => entry.record_id));
        for (const observed of verification.observations) {
          const [ingested] =
            await tx`select * from public.ingest_external_event(${observed.provider},${observed.externalId},${observed.occurrenceKey},${observed.sourceUrl},${
              tx.json(observed.normalized)
            },${EXTERNAL_EVENT_NORMALIZATION_VERSION},${await hashNormalizedExternalEvent(
              observed.normalized,
            )},${
              tx.json(observed.metadata)
            },1,${verification.importer_user_id}::uuid)`;
          if (ingested.outcome !== "ingested") {
            throw new Error(`dry_run_ingest_${ingested.outcome}`);
          }
          ids.add(Number(ingested.record_id));
          const observedResult = {
            record_id: Number(ingested.record_id),
            pending_submission_id: ingested.pending_submission_id === null
              ? null
              : Number(ingested.pending_submission_id),
            pending_created: ingested.pending_created,
          };
          const index = result.findIndex((entry) =>
            entry.record_id === observedResult.record_id
          );
          if (index === -1) result.push(observedResult);
          else {result[index] = {
              ...observedResult,
              pending_created: result[index].pending_created ||
                observedResult.pending_created,
            };}
        }
        for (const recordId of ids) {
          const proposals =
            await tx`select r.provider,r.external_id,r.occurrence_key,r.proposed_hash,r.proposed_normalization_version,s.external_moderation_hash,s.external_normalization_version from public.external_event_records r join public.content_submissions s on s.external_event_record_id=r.id and s.status='pending' where r.id=${recordId}`;
          for (const proposal of proposals) {
            const key = identityKey({
              provider: proposal.provider,
              external_id: proposal.external_id,
              occurrence_key: proposal.occurrence_key,
            });
            const explanations = verification.explanations.filter((entry) =>
              identityKey(entry.identity) === key &&
              entry.source_hash === proposal.external_moderation_hash &&
              entry.evidence_ref?.trim()
            );
            if (
              explanations.length !== 1 ||
              (proposal.external_moderation_hash === proposal.proposed_hash &&
                proposal.external_normalization_version ===
                  proposal.proposed_normalization_version)
            ) throw new Error("unexplained_dry_run_proposal");
          }
        }
      }
      releaseGuard();
      if (options.rollback) {
        rolledBackResult = [...result];
        throw new Error("verified_backfill_dry_run_rollback");
      }
    });
  } catch (error) {
    if (
      options.rollback && error instanceof Error &&
      error.message === "verified_backfill_dry_run_rollback"
    ) return rolledBackResult;
    throw error;
  }
  return result;
}
