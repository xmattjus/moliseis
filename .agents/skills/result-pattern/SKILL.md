---
name: result-pattern
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

### 3. Chaining async operations — asyncMap

When the next step is itself async but doesn't return `Result`, use `asyncMap`.

```dart
Future<Result<void>> _loadRelatedResultsIds(String query) async {
  final result = await _searchRepository.getRelatedResults(query);

  return result.asyncMap((ids) async {
    _relatedResultsIds = ids;
    await loadRelatedResults.execute();
  });
}
```

### 4. Combining two independent operations — zip2

Run two async `Result`-returning functions in sequence; short-circuit on
the first error without manual `switch` boilerplate.

```dart
return Result.zip2(
  () => _searchRepository.getPlaceIdsByQuery(query),
  () => _searchRepository.getEventIdsByQuery(query),
  (placeIds, eventIds) async {
    for (final id in placeIds) {
      final r = await _exploreGetByIdUseCase.getById(id);
      r.map((place) => _results.add(place));
    }
    // ... process eventIds ...
    return const Result.success(null);
  },
);
```

### 5. Partial-failure loops — map inside loop, continue on error

When iterating over IDs, use `map` to collect successes and silently skip
failures. Do **not** short-circuit the loop with `flatMap`.

```dart
for (final id in _relatedResultsIds) {
  final result = await _exploreGetByIdUseCase.getById(id);
  result.map((item) => relatedResults.add(item));  // errors are ignored
}
```

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
