# moliseis — AGENTS.md

Repository-wide operational rules for Molise Is. More specific nested
`AGENTS.md` files also apply.

## Sources of truth and repository-first work

- The user's request defines the outcome; an approved plan/specification defines
  executable intent when present; applicable `AGENTS.md` files define repository
  rules. Current code, tests, migrations, configuration, and authoritative
  dependency sources establish implementation reality.
- Stop affected execution on material contradictions. Report them for resolution
  by the planner/reviewer before continuing; do not silently override a source or
  redesign the task. Plan compliance alone does not establish correctness.
- Before proposing or modifying code, inspect the relevant implementations,
  callers, tests, and backend contracts. Identify existing patterns, abstractions,
  ownership, and conventions; reuse or extend them before introducing alternatives.
  Do not reproduce demonstrated defects merely for consistency.
- A new architectural pattern, shared abstraction strategy, framework,
  or cross-cutting convention requires explicit user authorization,
  unless already authorized by the user's request or an approved plan.
  Before proposing one, establish why existing approaches are
  insufficient and identify the simplest viable alternative.
  Stop only for architectural decisions outside the authorized scope.
  Ordinary local implementation details do not require approval.
- New packages require material justification.
- Preserve unrelated working-tree changes and stay within authorized scope.
  Do not prioritize delivery time or implementation cost unless requested.

## Delegation

Use `.codex/agents/` role instructions when supported; keep model, sandbox, and
prompt configuration there. Delegate selectively, not for trivial work or extra
opinions after sufficient evidence exists. Prefer parallel independent reads;
avoid concurrent writers on the same production surface.

Give each task explicit scope, expected results, constraints, and evidence
requirements, with one owner per bounded implementation. The main agent retains
request interpretation, scope, evidence reconciliation, integration, and final
architecture/readiness judgments. Verify material delegated conclusions rather
than treating reports as authority. Subagents must not broaden scope; confirmed
contradictions that make the task unsafe or impossible require escalation.

## Architecture and persistence boundaries

- Keep `lib/domain/` independent of `data` and `ui`. Domain repository contracts
  live in `lib/domain/repositories/`; implementations in `lib/data/repositories/`.
  The data layer implements domain contracts and owns infrastructure details.
- UI/ViewModels use domain-facing contracts. Keep presentation, ViewModel
  orchestration, domain rules, persistence, and backend enforcement in their
  owning layers; do not expose privileged backend details in UI.
- Keep Provider/`ChangeNotifier` for state and dependency injection, with
  `lib/config/dependencies.dart` as the primary composition root. Do not introduce
  parallel state management.
- ObjectBox entities/local data sources belong in `lib/data/data-sources/`, wire
  DTOs in `lib/data/dtos/`, and mappings in `lib/data/mappers/`. Reuse repository
  and write boundaries before adding direct data-source access.
- Preserve deliberate local exceptions rather than performing unrelated
  architectural cleanup.

## Result and command contracts

Use `Result.success(T)` / `Result.error(Exception)` for expected recoverable
failures across repository, use-case, and ViewModel boundaries. Translate expected
infrastructure failures at the boundary owning the error contract, preserving
logging/reporting. Internal code and Result transformations may throw; there is
no blanket prohibition on exceptions.

For new ViewModel async actions:

- Default to `createResultCommand` / `createResultCommandNoParam` from
  `lib/utils/result_command.dart`. They wrap `command_it.Command<P, Result<T>?>`
  and reject concurrent invocations while running; consumer-required coalescing
  belongs in orchestration.
- Use `RestartableCommand<P, T>` from `lib/utils/restartable_command.dart` only
  when newer intent must supersede older work, such as search or identity/selection
  reads. Its child commands and `switchMap` revoke obsolete work's publication
  authority even when physical work continues. It is not the default for actions.
- Keep expected failures as `Result.error`; raw throws are unexpected runtime or
  programming failures. Do not catch generic `Object` and convert it to
  `Result.error` to bypass lifecycle or error routing. While commands remain live,
  handled unexpected failures use the configured `command_it` global reporter.
- Views trigger commands rather than duplicating ViewModel orchestration.

`command_it 9.5.2` has a late-throw-after-dispose limitation: after deferred
internal notifier teardown, raw async throws can fail on disposed state before
reaching the global handler. Preserve ViewModel lifecycle guards; global reporting
cannot make post-dispose throws safe. Re-audit this when upgrading `command_it`.

## Supabase and database contracts

Current migrations and SQL definitions are authoritative for schema, constraints,
RLS, transactional invariants, and RPC behavior.

- Keep database invariants server-side; Flutter must not be their sole enforcer.
- Preserve existing RPC/transaction boundaries instead of direct table writes.
- Do not weaken RLS, authentication, authorization, service-role, or secret
  boundaries. Keep privileged operations behind existing Edge Function/RPC
  boundaries.
- For database contract changes, inspect affected SQL, Edge Functions, callers,
  generated/shared types where applicable, and regression tests.
- Never expose secret values, full authorization headers, or secret-bearing
  environment contents in source, plans, logs, tests, or chat output.

## Generated code and verification

- Change generator inputs rather than hand-editing generated output. For
  ObjectBox, `dart_mappable`, and Envied, use the established `build_runner`
  workflow, typically `dart run build_runner build --delete-conflicting-outputs`.
  Inspect generated diffs and retain only intentionally caused changes.
- Start with the smallest relevant checks; broaden for shared contracts and risk.
  Follow explicit plan/specification acceptance requirements. Common Flutter
  checks are `flutter analyze` and `flutter test`; follow affected Deno code/tests
  for Edge Function formatting, type checks, and test commands.
- Never invent repository facts or claim a command, test, migration, build,
  deployment, or smoke check passed without executing it and observing success.
- For version-sensitive behavior, inspect the checkout's actual versions and use
  authoritative local source or current official documentation. Use available
  documentation tools within permissions; no particular search tool is required.

## GitHub contributions and pull requests

- `main` is an integration branch. Agent-authored changes intended for it go
  through PRs; direct pushes require an explicit user exception, regardless of
  urgency or change size. Local experiments and uncommitted work need no PR.
- Use one PR per cohesive, independently reviewable change, normally one per
  OpenSpec change. Keep related implementation, tests, docs, generated artifacts,
  and review fixes together; add review-fix commits to the same open PR.
- Agents may create/update PRs within authorized work. Merging requires explicit
  user authorization, as does bypassing branch protections or required checks.
- Generate PR titles with the repository-local
  `.agents/skills/strict-conventional-commit/SKILL.md` and its `--pr-title` mode.
  Consider the entire PR against its base; staging alone does not represent it.
- Follow `.github/PULL_REQUEST_TEMPLATE.md` for descriptions, including via CLI
  or API. Only `Why` is mandatory. Keep descriptions concise; do not duplicate CI
  outcomes, file summaries, logs, or execution histories. Retain materially
  necessary optional information as required by the template.
