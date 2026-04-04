# Molise Is

A multi-platform application that allows users to explore the Molise region in Italy. It is built using Flutter, uses ObjectBox for local data storage, and integrates with the Supabase backend for remote data access.

## Architecture

The app follows **Clean Architecture** with an **MVVM** presentation layer. State management uses `Provider` (`ChangeNotifier` + `ChangeNotifierProvider`). There is no BLoC or Riverpod.

### Layers

- `lib/config/` — Dependency injection (`dependencies.dart` wires all providers)
- `lib/domain/` — Models, repository interfaces, use cases
- `lib/data/` — Repository implementations, data sources (Supabase remote, ObjectBox local)
- `lib/ui/` — Views and ViewModels, organized by feature
- `lib/routing/` — GoRouter configuration with shell routes for bottom navigation
- `lib/utils/` — Shared utilities: `Result<T>`, `Command`, extensions

### Key Patterns

**Result pattern** — All async operations return `Result<T>` (a sealed `Success<T> | Error<T>` class in `lib/utils/result.dart`). Use `fold()`, `map()`, `flatMap()` on results. Do not throw exceptions across layer boundaries.

**Command pattern** — ViewModels expose `Command0<T>` and `Command1<T, A>` (in `lib/utils/command.dart`) for async actions. Commands carry `running`, `completed`, and `error` states automatically.

**Repository pattern** — Each feature has a domain interface (e.g., `PlaceRepository`) and a data implementation (e.g., `PlaceRepositoryImpl`). Repositories are provided as singletons via Provider.

**Use cases** — Located in `lib/domain/use-cases/`. Orchestrate multiple repositories and return `Result<T>`.

### Data Sources

- **Remote**: Supabase (PostgreSQL). Accessed via `SupabaseTable` helper classes.
- **Local**: ObjectBox (NoSQL). Models are code-generated; run `build_runner` after schema changes.
- **Images**: Flutter Cache Manager CE + Cloudinary CDN.

### Environment

Environment variables are loaded from a `.env` file in the project root and code-generated into `lib/config/env/env.g.dart` via the `envied` package. Values are obfuscated at compile time.

### Navigation

GoRouter with animated shell routes. Five main branches: Explore, Events, Favourites, Map, Settings. Sync screen is a startup route outside the shell.

## Coding Standards

- Use `const` constructors whenever possible.
- Prefix internal/private variables with `_`.
- Documentation comments use `///`, max 80 chars per line, ending each phrase with a period. Follow Effective Dart guidelines.
- Inline comments explain *why*, not *what*.
