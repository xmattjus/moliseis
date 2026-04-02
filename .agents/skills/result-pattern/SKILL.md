---
name: result-pattern
description: Use the app Result<T> standard to model success and failure, and prefer the built-in mapping helpers when transforming repository and use-case data.
---

# Result Pattern

Use this skill when working with `lib/utils/result.dart`
or any code that consumes `Result<T>`, `Success<T>`, or `Error<T>`.

## Standard

1. Use `Result.success(value)` for completed work.
2. Use `Result.error(exception)` for failures.
3. Prefer `map`, `fold`, and `flatMap` over manual switch blocks when the code only transforms or forwards a result.
4. Keep explicit `switch` statements for cases that need different side effects or state updates in each branch.

## Recommended helpers

- `map` for value transformation.
- `fold` for turning a `Result<T>` into any other type.
- `flatMap` for chaining operations that already return `Result`.
- `getOrNull()` for safe unwrapping to nullable.
- `getOrElse()` for unwrapping with a fallback.
- `isSuccess` and `isError` for type-free status checks.

## Example

```dart
final contentResult = await repository.getById(id);

return contentResult.map((item) => ItemContent.fromItem(item));
```

```dart
final summary = (await repository.getAll()).fold(
  (items) => items.length,
  (_) => 0,
);
```

## Ergonomic shortcuts

Use these for convenience without needing `switch` or `fold`:

```dart
// Safe unwrapping to nullable
final value = result.getOrNull();

// Unwrapping with a default
final value = result.getOrElse(() => AppSettings());

// Status checks without type-checking
if (result.isSuccess) {
  print('Success!');
}
```

## Guidance

- Preserve existing error semantics when refactoring call sites.
- Use `flatMap` only when the follow-up function already returns `Result`.
- Do not replace branch-specific state updates with helpers if the code becomes harder to read.
- Keep error handling visible in application logic when the error branch has important behavior.

## Common refactor targets

- Repository-to-use-case transformations.
- Use cases that map entities into UI content models.
- Simple forwarding logic that only unwraps and rewraps a `Result`.

## Anti-patterns

- Repeating `switch` blocks that only unwrap a success value and return a transformed result.
- Swallowing errors without a clear reason.
- Adding helper methods that duplicate `map`, `fold`, or `flatMap` behavior.