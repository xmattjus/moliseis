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

<!-- code-review-graph MCP tools -->
## MCP Tools: code-review-graph

**IMPORTANT: This project has a knowledge graph. ALWAYS use the
code-review-graph MCP tools BEFORE using Grep/Glob/Read to explore
the codebase.** The graph is faster, cheaper (fewer tokens), and gives
you structural context (callers, dependents, test coverage) that file
scanning cannot.

### When to use graph tools FIRST

- **Exploring code**: `semantic_search_nodes` or `query_graph` instead of Grep
- **Understanding impact**: `get_impact_radius` instead of manually tracing imports
- **Code review**: `detect_changes` + `get_review_context` instead of reading entire files
- **Finding relationships**: `query_graph` with callers_of/callees_of/imports_of/tests_for
- **Architecture questions**: `get_architecture_overview` + `list_communities`

Fall back to Grep/Glob/Read **only** when the graph doesn't cover what you need.

### Key Tools

| Tool | Use when |
|------|----------|
| `detect_changes` | Reviewing code changes — gives risk-scored analysis |
| `get_review_context` | Need source snippets for review — token-efficient |
| `get_impact_radius` | Understanding blast radius of a change |
| `get_affected_flows` | Finding which execution paths are impacted |
| `query_graph` | Tracing callers, callees, imports, tests, dependencies |
| `semantic_search_nodes` | Finding functions/classes by name or keyword |
| `get_architecture_overview` | Understanding high-level codebase structure |
| `refactor_tool` | Planning renames, finding dead code |

### Workflow

1. The graph auto-updates on file changes (via hooks).
2. Use `detect_changes` for code review.
3. Use `get_affected_flows` to understand impact.
4. Use `query_graph` pattern="tests_for" to check coverage.
