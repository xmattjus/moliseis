---
name: molise-is-result-pattern
description: >
  How to use the Result<T> pattern correctly in this project: which combinator
  to choose, how to unwrap values, how ViewModels consume repository results,
  and what anti-patterns to avoid.
---

# Result Pattern

Use this skill whenever writing or reviewing code that calls a repository,
use case, or any function returning `Result<T>` — especially in ViewModels.

Reference files:
- `lib/utils/result.dart` — full API
- `lib/ui/search/view_models/search_view_model.dart` — canonical ViewModel usage

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

All async operations across every layer return `Result<T>`.
**Never throw across layer boundaries** — wrap in `Result.error` instead.

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

## Key Patterns from SearchViewModel

### 1. Simple async load — map to update state

Call the repository, then use `map` to unpack the value and mutate state.
Return the mapped result directly; the `Command` surfaces any error.

```dart
Future<Result<void>> _loadPastSearches() async {
  final result = await _searchRepository.getPastSearches();

  return result.map((pastSearches) {
    _pastSearches = pastSearches;
    notifyListeners();
  });
}
```

### 2. Optimistic update — mapError to roll back

Apply the change locally before the async write.
If the write fails, `mapError` reverses it and re-notifies listeners.

```dart
Future<Result<void>> _addToPastSearches(String query) async {
  _pastSearches.add(query);   // optimistic
  notifyListeners();

  final result = await _searchRepository.addToPastSearches(query);

  return result.mapError((error) {
    _pastSearches.remove(query);  // rollback
    notifyListeners();
    return error;
  });
}
```

### 3. Direct retrieval and lifecycle guards

List discovery returns complete domain models. Await the repository once,
check disposal, then replace visible state synchronously on success. An error
retains the previous successful collection; successful empty retrieval clears it.

```dart
final result = await _searchRepository.getResultsByQuery(query);
if (_disposed) return result.map((_) {});
return result.map((results) {
  _results = results;
  notifyListeners();
});
```

Use `asyncMap` when a successful transform actually needs an await;
use `asyncFlatMap` when that next async operation itself returns a Result.
Do not introduce discovery IDs merely to resolve every entity separately.

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

## ViewModel Return Contract

Every `Command` handler **must** return `Future<Result<T>>`:

- Return `Result.success(value)` — command marks `completed = true`.
- Return `Result.error(exception)` — command marks `error = true`.
- **Never** `return null` or forget the `return` — the type system enforces this.

```dart
// WRONG — loses the error signal
Future<Result<void>> _doSomething() async {
  await _repository.doSomething();
}

// CORRECT — always propagate or transform
Future<Result<void>> _doSomething() async {
  return await _repository.doSomething();
}
```

---

## Anti-Patterns

| Anti-pattern | Why it's wrong | Fix |
|---|---|---|
| Throwing instead of returning `Result.error` | Crosses layer boundaries unsafely | `return Result.error(exception)` |
| `switch (result) { case Success ... }` when a combinator exists | Verbose and error-prone | Use `map`, `fold`, `flatMap`, etc. |
| `result.isSuccess` then `.getOrNull()!` | Two-step unwrap with a hidden null-bang | Use `map` or `fold` |
| Ignoring the returned `Result` | Silently swallows errors | Always `return` or chain the result |
| Using `zip2` for dependent operations | `zip2` assumes independence | Use `flatMap` / `asyncFlatMap` for dependent chains |
| `asyncMap` when `map` suffices | Unnecessary `Future` overhead | Use `map` for sync transformations |
