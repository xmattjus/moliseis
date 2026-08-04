---
name: dart-documentation
description: Guidelines for writing dartdoc-style documentation comments for all public (and private) Dart APIs in this project.
---

# Dart Documentation

Use this skill whenever writing, reviewing, or editing documentation comments
in any `.dart` file — especially before committing changes that touch public
APIs.

## Core Rules

1. Use `///` for all doc comments (not `//` or `/* */`).
2. Document all public APIs. Consider documenting private APIs too.
3. Place doc comments **before** any metadata annotations (e.g., `@override`).
4. Add a library-level comment at the top of files where a general overview is
   helpful.

## Comment Structure

```dart
/// Single-sentence summary ending with a period.
///
/// Further explanation in a separate paragraph. Explain *why* the code
/// behaves a certain way, context that isn't obvious from the name, and
/// anything a reader would reasonably ask when they first encounter this.
///
/// Describe parameters, return values, and errors using prose — not tags.
/// Example: throws an [ArgumentError] if [id] is empty.
///
/// ```dart
/// final result = await repository.getById('123');
/// ```
```

## Philosophy

- **Explain why, not what.** The code already shows what it does. The comment
  should add context, constraints, or reasoning that the code cannot express.
- **Answer real questions.** If you had to look something up to understand the
  code, add the answer at the place you first looked.
- **No useless documentation.** A comment that only restates the name or
  signature adds noise. Omit it or replace it with something meaningful.
- **Document for the reader.** Write as if explaining to a capable colleague
  encountering this API for the first time.

## Writing Style

- Be brief and direct.
- Avoid jargon and acronyms unless widely understood.
- Use Markdown sparingly; never use HTML.
- Wrap lines at 80 characters.
- Enclose code references in backticks: `MyClass`, `someMethod()`.
- Use `[ClassName]` or `[method]` for cross-references within dartdoc.

## What to Document

| Element | Guidance |
|---|---|
| Public class | Summary + purpose and key constraints. |
| Public method / function | What it does, parameters, return value, errors. |
| Public field / property | What the value represents and valid range / states. |
| Getter + setter pair | Document one only; dartdoc treats them as one field. |
| Constructor | Document if it has non-obvious parameters or side effects. |
| Private APIs | Document when logic is non-trivial or intent isn't obvious. |
| Library / file | Add a top-level `///` overview when the file isn't self-evident. |

## Examples

### Class

```dart
/// A use case that synchronises remote content into the local ObjectBox store.
///
/// Coordinates [EventRepository], [PlaceRepository], and [MediaRepository]
/// to fetch fresh data from Supabase and persist it locally in a single
/// transaction. Returns [Result.error] if any repository fails, leaving
/// previously stored data intact.
class SyncUseCase { ... }
```

### Method

```dart
/// Fetches the place with the given [id] from the local store.
///
/// Returns [Result.error] if no matching place exists or if the store is
/// unavailable.
Future<Result<Place>> getById(String id);
```

### Field / property

```dart
/// Whether a sync operation is currently in progress.
///
/// Listeners are notified when this value changes so the UI can show or
/// hide a loading indicator.
bool get isSyncing => _syncCommand.running;
```

## Anti-Patterns

- Restating the name: `/// Gets the name.` on a `getName()` method.
- Empty filler: `/// TODO: document this.`
- Over-tagging with `@param` / `@return` — use prose instead.
- Documenting only the getter or only the setter when both exist (pick one).
- Skipping the blank line between the summary sentence and the body paragraph.
