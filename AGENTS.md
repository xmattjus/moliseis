# moliseis — AGENTS.md

Repository-wide engineering instructions for AI agents working on Molise Is.

This file contains **project-specific rules only**. It does not replace an
effective implementation plan/specification or a more specific nested `AGENTS.md`.

## Sources of Truth

For repository-changing work, keep these responsibilities distinct:

- the user's explicit request defines the desired outcome;
- an approved implementation plan or specification defines current executable
  intent when one exists;
- applicable `AGENTS.md` files define repository-specific engineering rules;
- current code, tests, migrations, configuration, and authoritative dependency
  sources provide repository reality and implementation evidence.

Do not resolve a material conflict by silently overriding one source with another.
A planner/reviewer must resolve material conflicts between requested intent,
planning artifacts, and repository reality before affected execution starts or
resumes. An executor must stop and report a material contradiction rather than
silently redesigning the task.

OpenCode/plugin orchestration details belong in the relevant agent/workflow
configuration rather than this repository-wide policy.

## Engineering Principles

Apply these principles together rather than mechanically optimizing for any one of
them:

- **KISS (Keep It Simple):** choose the simplest design that satisfies the
  verified requirement and fits the current architecture. Avoid speculative
  indirection, generalized infrastructure, and complexity without a concrete need.
- **YAGNI (You Aren't Gonna Need It):** implement requirements and edge cases that
  are actually required now. Defer speculative extensibility, future hooks, and
  hypothetical scenarios until there is evidence they are needed.
- **DRY (Don't Repeat Yourself):** reuse existing behavior and keep important
  rules/invariants in a single authoritative place when practical. Do not use DRY
  as a reason to introduce a premature abstraction for small or incidental
  duplication.
- **Rule of Three:** prefer tolerating limited duplication over inventing a generic
  abstraction too early. Extract a reusable abstraction when there are at least
  three concrete use cases, unless an existing shared contract or invariant already
  requires one authoritative implementation.
- **SRP (Single Responsibility Principle):** keep functions, classes, widgets,
  services, RPCs, and Edge Functions focused on one coherent responsibility. Do
  not split code into artificial micro-abstractions merely to satisfy the principle
  mechanically.
- **Separation of Concerns:** keep UI/presentation, application orchestration,
  domain rules, persistence/infrastructure, and database enforcement in their
  appropriate layers. In particular, do not move Supabase/database invariants into
  Flutter merely for convenience, or leak privileged backend details into the UI.
- **Composition over inheritance:** in Dart/Flutter, prefer composing existing
  widgets, helpers, services, and behaviors over creating new inheritance
  hierarchies, unless an established project hierarchy clearly fits the problem.
- **Clean Architecture is guidance, not a goal by itself:** preserve useful layer
  boundaries, but do not add abstractions, boilerplate, or files when doing so
  would conflict with KISS or YAGNI.

Operationally:

- Inspect the current implementation, relevant tests, and backend definitions
  before proposing or making changes.
- Prefer existing project patterns and reusable components over theoretically
  superior replacements.
- Prefer incremental, maintainable changes that fit naturally into the codebase.
- Do not introduce new packages, frameworks, state-management solutions, or
  architectural patterns unless materially justified.
- Do not broaden a task into opportunistic cleanup or a large refactor.
- Do not optimize for delivery time or implementation cost unless explicitly
  requested.
- Preserve unrelated working-tree changes. Never discard user work to simplify a
  change.
- Do not invent files, symbols, APIs, schemas, behavior, or verification results.

## Architecture

The current high-level structure is:

```text
lib/
├── domain/          # Models, repository contracts, use cases
├── data/
│   ├── data-sources/ # ObjectBox/local persistence
│   ├── dtos/         # Remote/wire DTOs
│   ├── mappers/      # DTO/entity ↔ domain mapping
│   ├── repositories/ # Repository implementations
│   └── services/     # Infrastructure/external services
├── ui/              # Feature-based UI, ViewModels, widgets
├── routing/         # go_router
├── config/          # Environment + Provider composition root
├── utils/           # Result, Command, logging, shared utilities
└── generated/       # Generated ObjectBox output

supabase/
├── functions/       # Edge Functions + shared Deno/TypeScript
├── migrations/      # Schema, RPCs, triggers, RLS, DB invariants
└── tests/           # Backend/database tests
```

The directory summary is orientation only. Verify specific paths and symbols in
the current checkout before relying on them.

### Layer boundaries

- `domain` must remain independent of `data` and `ui`.
- `data` implements domain contracts and owns infrastructure details.
- UI/ViewModels should use domain-facing contracts rather than direct persistence
  or privileged backend implementation details.
- `config/dependencies.dart` is the primary Provider composition root.
- Prefer a deliberate existing local exception over an unrelated architectural
  cleanup.

## Project Patterns

### `Result<T>`

Use `Result.success(T)` / `Result.error(Exception)` for expected recoverable
failures across repository, use-case, and ViewModel boundaries.

Do **not** apply a blanket "nothing may ever throw" rule. Internal code and
`Result` transformations can propagate exceptions. Translate expected
infrastructure failures at the architectural boundary that owns the error
contract, and preserve existing logging/error-reporting behavior.

### `Command0` / `Command1`

Use the existing Command pattern for user-initiated async ViewModel actions and
state updates. Views should trigger commands rather than duplicate orchestration
logic unless a concrete existing pattern justifies otherwise.

### Provider / `ChangeNotifier`

Keep the existing Provider/`ChangeNotifier` state-management and dependency
injection model. Do not introduce a parallel state-management solution.

### Data boundaries

- Domain repository contracts: `lib/domain/repositories/`.
- Concrete repositories: `lib/data/repositories/`.
- ObjectBox entities/data sources: `lib/data/data-sources/`.
- Remote/wire DTOs: `lib/data/dtos/`.
- Mapping: `lib/data/mappers/`.

Reuse existing repository/write boundaries before adding direct data-source
access.

## Supabase / Database

Treat current migrations and SQL definitions as authoritative for schema,
constraints, RLS, transactional invariants, and RPC behavior.

- Do not make Flutter the sole enforcement point for database invariants.
- Do not bypass an existing RPC/transaction boundary with direct table writes.
- Do not weaken RLS, authentication, authorization, service-role, or secret
  boundaries to simplify client code.
- Keep privileged operations behind the project's existing Edge Function/RPC
  boundaries.
- When changing a database contract, inspect affected SQL, Edge Functions,
  callers, generated/shared types where applicable, and regression tests.

Never write secret values, full authorization headers, or secret-bearing
environment contents into source, planning artifacts, logs, tests, or chat output.

## Generated Code

Do not hand-edit generated output when its generator input is the proper write
boundary.

The current project uses `build_runner` with ObjectBox, `dart_mappable`, and
Envied. After changing generator inputs, use the established generation workflow,
typically:

```bash
dart run build_runner build --delete-conflicting-outputs
```

Inspect generated diffs and keep only changes caused by intentional source
changes.

## Testing and Verification

- Run the smallest relevant tests first; broaden when shared contracts or the
  current task scope require it.
- Common Flutter checks are `flutter analyze` and `flutter test`.
- For Edge Functions, follow the affected Deno code/tests for formatting, type
  checks, and test commands.
- When work is governed by an implementation plan or specification, its explicit
  verification and acceptance requirements are authoritative.
- Never claim a command, test, migration, build, deployment, or smoke check passed
  unless it actually ran and produced that result.

## Version-Specific Behavior

When library, SDK, CLI, Flutter, Dart, Deno, or Supabase behavior is
version-sensitive, inspect the version actually used by the checkout and prefer
authoritative local source or current official documentation.

Do not hard-code a particular documentation/search tool into this repository
policy. Use the authoritative source and documentation capabilities available to
the active agent, while respecting its permissions.
