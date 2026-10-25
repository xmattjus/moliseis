---
name: molise-is-result-pattern
description: >
  How to use the Result pattern correctly in this project: which combinator
  to choose, how to unwrap values, how ViewModels consume repository results,
  and what anti-patterns to avoid.
---

# Result Pattern

Use this skill whenever writing or reviewing code that calls a repository,
use case, or any function returning `Result<T>` — especially in ViewModels.

Reference files:
- `lib/utils/result.dart` — domain Result API
- `lib/utils/result_command.dart` — ordinary factories and snapshot projections
- `lib/utils/restartable_command.dart` — latest-intent execution
- `lib/ui/search/view_models/search_view_model.dart` — confirmed history and restartable reads
- `lib/ui/explore/view_models/explore_view_model.dart` — ordinary load with lifecycle guards

---

## The Type

```dart
sealed class Result<T> {
  const factory Result.success(T value) = Success._;
  const factory Result.error(Exception error) = Error._;
}
final class Success<T> extends Result<T> { final T value; }
final class Error<T>   extends Result<T> { final Exception error; }
```

Represent expected recoverable failures at repository, use-case and ViewModel
boundaries as `Result.error(Exception)`. Not every async operation returns a
Result. Unexpected runtime/programming failures remain throws; Result
transformations can also propagate throws. Translate expected infrastructure
failures at the boundary that owns their contract, preserving existing reporting.
Do not catch arbitrary `Object` and reclassify it as an application error.

---

## Choosing the Right Combinator

| Situation | Use |
|---|---|
| Sync transform on success value | `map` |
| Sync chain to another `Result` | `flatMap` |
| Async transform on success value | `asyncMap` |
| Async chain to another `Result` | `asyncFlatMap` |
| Transform or side-effect on error | `mapError` |
| Async transform on error | `asyncMapError` |
| Recover from error with another `Result` | `flatMapError` / `asyncFlatMapError` |
| Branch on both cases | `fold` / `asyncFold` |
| Combine two independent async `Result`s | `Result.zip2` |
| Combine three independent async `Result`s | `Result.zip3` |
| Combine four independent async `Result`s | `Result.zip4` |
| Extract value or `null` | `getOrNull()` |
| Extract value or a fallback | `getOrElse(() => default)` |

---

## Current ViewModel Patterns

### 1. Ordinary load — map after checking lifecycle

An ordinary action can commit its successful result while its owner remains live.
For example, ExploreViewModel checks disposal before retrieval and again after
awaiting it, then maps the Result to update its collection and notify listeners.
Preserve those guards and any post-notify guard before starting another phase.
A returned `Result.error` stays an application failure; the command snapshot
projection, rather than the action alone, determines the rendered state.

### 2. History writes — retain confirmed data

SearchViewModel accepts history mutations into its existing FIFO writer. It does
not optimistically append/remove entries or roll them back: an independent
ordinary read replaces the visible history after confirmed retrieval. Preserve
that contract instead of copying a generic optimistic-update example.

Use `mapError` to transform an expected failure or perform a feature's existing
rollback only where that feature actually requires it. It does not catch a raw
throw or authorize presentation updates after disposal.

### 3. Restartable retrieval — commit through the authoritative snapshot

Search results and suggestions use `RestartableCommand` actions that only
retrieve/compute Results. Their synchronous `results` observers commit successful
current snapshots; superseded work must not mutate visible state from its action.
New intent revokes prior publication authority even if physical work continues.

List discovery returns complete domain models; do not introduce IDs merely to
resolve every entity separately. Use `asyncMap` when a successful transform
actually needs an await; use `asyncFlatMap` when that operation returns a Result.

### 4. Combining two operations — zip2

`Result.zip2` runs the functions sequentially and short-circuits on the first
error. Search repository phases preserve this ordering because they share
parameterized query state. They must not be replaced with `Future.wait`.

```dart
return Result.zip2(
  () => searchPlaces(text),
  () => searchEvents(text),
  (places, events) => Result.success(<ContentBase>[...places, ...events]),
);
```

### 5. Direct discovery failures

A recoverable query/materialization Exception fails the logical repository
operation. Do not convert it into partial success or publish a partial list.
The removed per-item lookup stage no longer supplies skip-on-error semantics.
ID APIs remain appropriate when identity membership is the actual requested data.

### 6. Early-return success for no-ops

Use a `const Result.success(null)` guard at the top of `Result<void>`
functions when input validation means no work needs to be done.

```dart
Future<Result<void>> _search(String query) async {
  if (!isSearchQueryValid(query)) return const Result.success(null);
  // ...
}
```

---

## Command Actions and Execution Snapshots

`createResultCommand<P, T>` takes `Future<Result<T>> Function(P)`;
`createResultCommandNoParam<T>` takes `Future<Result<T>> Function()`.
`RestartableCommand<P, T>` also takes `Future<Result<T>> Function(P)`.
These signatures apply to these factories, not every upstream Command or every
ViewModel method. The action returns a non-null Result; the ordinary
`ResultCommand<P, T>` wraps `command_it.Command<P, Result<T>?>` so its initial
snapshot can have null data without representing a successful execution.

Ordinary commands reject concurrent invocations while running; they do not queue
or coalesce another request. `RestartableCommand` instead gives newer intent
publication authority and can invalidate to neutral state. Views trigger the
owner's command/request API rather than duplicating its orchestration.

Observe `results` and the `ResultCommandSnapshot` extension:

- `idle` means no running or terminal execution: both data and error are null.
- `isRunning` belongs to the execution snapshot. `isRunningSync.value` on the
  command provides immediate admission state for coordination; deferred running
  notifications and snapshots serve observation.
- `completed` requires a terminal snapshot with a `Success<T>` payload and no
  upstream runtime error, including `Success<void>(null)`.
- `domainError` exposes the expected exception carried in a terminal `Error<T>`
  payload; `unexpectedError` exposes the original terminal upstream error.
- `hasFailure` covers either kind. A returned `Result.error` is data for upstream
  Command; it does not itself set the upstream snapshot's `error` field.

Do not infer real success from upstream's neutral `isSuccess`, a null payload or
the action's return alone. Read the current execution snapshot, preserving the
owner/intent guards required by the feature.

Unexpected throws must retain their original object/stack and use the configured
`configureCommandReporting` boundary; do not convert them into `Result.error` to
satisfy command lifecycle behavior or report them a second time. Assertion policy
remains fail-loud. With `command_it 9.5.2`, a raw late throw after upstream command
disposal can fail before reaching global reporting: preserve the owner's
revocation guards and delayed physical cleanup. Restartable disposal revokes
publication immediately while started children remain alive until settlement;
it does not cancel physical I/O. Ordinary owners must likewise preserve their
existing safe, deferred release rather than disposing a pending command early.

Propagate or transform a repository Result instead of dropping it:

```dart
Future<Result<void>> _doSomething() async {
  return await _repository.doSomething();
}
```

---

## Anti-Patterns

| Anti-pattern | Why it's wrong | Fix |
|---|---|---|
| Throwing an expected recoverable failure, or converting every raw throw to `Result.error` | Confuses application failures with runtime defects | Translate expected failures at their owning boundary; preserve unexpected throws and original reporting |
| `switch (result) { case Success ... }` when a combinator exists | Verbose and error-prone | Use `map`, `fold`, `flatMap`, etc. |
| `result.isSuccess` then `.getOrNull()!` | Two-step unwrap with a hidden null-bang | Use `map` or `fold` |
| Ignoring the returned `Result` | Silently swallows errors | Always `return` or chain the result |
| Using `zip2` for dependent operations | `zip2` assumes independence | Use `flatMap` / `asyncFlatMap` for dependent chains |
| `asyncMap` when `map` suffices | Unnecessary `Future` overhead | Use `map` for sync transformations |
