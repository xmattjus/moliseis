# moliseis — AGENTS.md

Multi-platform tourism app for the Molise region (Italy). Flutter `3.41.9` + Dart SDK `^3.11.5`.

## Architecture

Clean Architecture with strict layer boundaries:

```
lib/
├── domain/          # Models, abstract repositories, use cases
│   ├── models/      # ContentBase, Event, Place, City, Media, etc.
│   ├── repositories/# Abstract interfaces (contracts)
│   └── use-cases/   # Orchestration logic (ExploreUseCase, SyncUseCase, etc.)
├── data/            # Concrete implementations, data sources, services
│   ├── core/        # 
│   ├── data-sources/# ObjectBox entities + Supabase table descriptors
│   ├── mappers/     # Entity → Domain model mappers
│   ├── repositories/# Repository impls (combine remote + local)
│   └── services/    # ObjectBox store, Cloudinary, OpenStreetMap, Weather APIs
├── ui/              # Feature-based screens, view models, widgets
│   ├── core/        # Themes, shared UI primitives, scaffold shell
│   ├── explore/     # Home/explore screen with search
│   ├── category/    # Category-filtered content listing
│   ├── event/       # Events listing
│   ├── favourite/   # Saved/favourite content
│   ├── geo_map/     # Map view with weather overlay
│   ├── post/        # Content detail screen
│   ├── search/      # Search results
│   ├── settings/    # App settings + theme
│   ├── sync/        # Data synchronization screen
│   ├── user_contribution/ # User-submitted content
│   └── weather/     # Weather display components
├── routing/         # GoRouter config, route paths/names, core reusable routes
├── config/          # DI (dependencies.dart), env vars
├── utils/           # Result<T>, Command0/Command1, logging, extensions, LRU cache
├── generated/       # ObjectBox codegen (objectbox.g.dart, objectbox-model.json)
└── main.dart        # App entrypoint: Supabase + ObjectBox init, Sentry, Provider tree
```

## DOs / DON'Ts

- DO analyze the codebase before answering a question
- DO prefer solutions that are consistent with existing code over theoretically superior alternatives
- DO suggest maintainable, future-proof solutions
- DO ask questions if you have any doubt
- DO follow the existing architecture and patterns already present in the codebase
- DO use Clean Architecture as a guiding principle, not an absolute rule
    - When architectural purity conflicts with simplicity, consistency with the existing codebase, or implementation clarity, prefer the pragmatic solution and document the tradeoff
- DO prefer incremental changes that fit naturally into the existing codebase

- DO NOT propose large-scale refactors unless they are necessary to solve the problem being discussed
- DO NOT introduce new packages, frameworks, state management solutions, or architectural patterns unless explicitly justified
- DO NOT consider development time, delivery deadlines, or implementation costs unless explicitly stated
- DO NOT write long winded answers unless explicitly requested

## Key Patterns

### Result<T> (`lib/utils/result.dart`)
Sealed class with `Success<T>` / `Error<T>` — used everywhere for error propagation. Never throw; always return `Result`.

```dart
Future<Result<Place>> getById(int id);
// Consume: result.fold(onSuccess, onError)
// Compose: Result.zip2, Result.zip3, Result.zip4 for parallel ops
```

### Command0 / Command1 (`lib/utils/command.dart`)
ViewModel async action encapsulation. Guards against concurrent execution, exposes `running`/`completed`/`error`/`result`. Used in all ViewModels.

```dart
class FooViewModel extends ChangeNotifier {
  late final load = Command0<void>(_fetch);
  late final loadById = Command1<void, int>(_fetchById);
}
```

### Repository + Synchronizable
Abstract repo in `domain/repositories/` extends `Synchronizable`. Concrete impl in `data/repositories/` combines ObjectBox (local) + Supabase (remote). Sync diff: fetch remote, compare with local ObjectBox store, upsert changes.

### Entity ↔ Model mapping
`data/mappers/` contains `toModel()` extension methods on ObjectBox entities. Entities live in `data/data-sources/` with `@Entity()` + `@JsonSerializable()` annotations.

### Use Cases
Thin orchestration layer in `domain/use-cases/`. Examples: `ExploreUseCase` aggregates Place/Event repos; `SyncUseCase` syncs repos in order (city → place → event → media).

## State Management

**Provider** with `ChangeNotifier`. All ViewModels extend `ChangeNotifier`. DI is manual via a single `providers()` function in `config/dependencies.dart`.

## Navigation

**GoRouter** with `AnimatedStatefulShellRoute` (bottom nav bar with 4 branches: explore, favourites, events, map). Route paths/names defined in `routing/route_paths.dart` and `routing/route_names.dart`. Reusable routes (`postRoute`, `categoryRoute`) in `routing/core_routes.dart`.

## Data Flow

1. **Remote**: Supabase tables → JSON → Entity (json_serializable) → Model (domain)
2. **Local**: ObjectBox store → Entity → Model (domain)
3. **Sync**: On app start (every 3 days) → fetch remote Supabase → diff with local ObjectBox → upsert changed entities. Order: cities → places → events → media.

## Code Generation

Run after modifying entities or env:
```bash
dart run build_runner build --delete-conflicting-outputs
```

Generates:
- `*.g.dart` files via `json_serializable` (entities)
- `lib/generated/objectbox.g.dart` via `objectbox_generator`
- `lib/config/env/env.g.dart` via `envied_generator`

## Testing

Domain-layer unit tests in `test/domain/`. Data-layer tests in `test/data/`. Test support mocks in `test/support/`: `mock_logger.dart`, `mock_supabase.dart`, `objectbox_test_store.dart`.

```bash
flutter test
```

## Lint & Analysis

Uses `very_good_analysis` base + custom `app_lints` plugin (`packages/app_lints/`).

```bash
dart analyze
```

## Conventions

- Use the dart-documentation skill to generate classes and constructors documentation
- Every async operation returning data uses `Result<T>` — never raw exceptions
- ViewModels use `Command0`/`Command1` for user-initiated actions
- Repositories named `*_repository.dart` (abstract) / `*_repository_impl.dart` (concrete)
- Entities named `*_entity.dart` with matching `*_supabase_table.dart` table descriptors
- Domain models are `@immutable` and extend `ContentBase` (Event, Place)
- Environment variables in `.env`, accessed via `Env` class (envied-generated)
- Sentry crash reporting toggleable via settings; wrapped with `SentryWidget` conditionally
- Fonts: Fraunces, Lexend (variable fonts in `assets/fonts/`)
- Localization: English + Italian via `flutter_localizations`

<!-- context7 -->
Use the `ctx7` CLI to fetch current documentation whenever the user asks about a library, framework, SDK, API, CLI tool, or cloud service — even well-known ones like React, Next.js, Prisma, Express, Tailwind, Django, or Spring Boot. This includes API syntax, configuration, version migration, library-specific debugging, setup instructions, and CLI tool usage. Use even when you think you know the answer — your training data may not reflect recent changes. Prefer this over web search for library docs.

Do not use for: refactoring, writing scripts from scratch, debugging business logic, code review, or general programming concepts.

## Steps

1. Resolve library: `npx ctx7@latest library <name> "<what to look up>"` — use the official library name with proper punctuation (e.g., "Next.js" not "nextjs", "Customer.io" not "customerio", "Three.js" not "threejs")
2. Pick the best match (ID format: `/org/project`) by: exact name match, description relevance, code snippet count, source reputation (High/Medium preferred), and benchmark score (higher is better). If results don't look right, try alternate names or queries (e.g., "next.js" not "nextjs", or rephrase the question)
3. Fetch docs: `npx ctx7@latest docs <libraryId> "<what to look up>"` — run a separate `docs` command per distinct concept if the question spans multiple topics, unless it's about how they interact
4. Answer using the fetched documentation

You MUST call `library` first to get a valid ID unless the user provides one directly in `/org/project` format. Be specific about what to look up in the library's documentation — specific and detailed queries return better results than vague single words, but keep each query to a single concept unless the question is about how concepts interact; combined multi-topic queries dilute ranking and return shallow results for each topic. Do not run more than 3 commands per question. Do not include sensitive information (API keys, passwords, credentials) in queries.

For version-specific docs, use `/org/project/version` from the `library` output (e.g., `/vercel/next.js/v14.3.0`).

If a command fails with a quota error, inform the user and suggest `npx ctx7@latest login` or setting `CONTEXT7_API_KEY` env var for higher limits. Do not silently fall back to training data.
<!-- context7 -->