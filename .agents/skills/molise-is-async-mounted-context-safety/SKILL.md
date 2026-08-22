---
name: molise-is-async-mounted-context-safety
description: >
  How to prevent Null check operator, BuildContext-after-async-gap, ticker/
  controller-used-after-dispose, and unmounted-State crashes (State.context
  AND State.widget) in this Flutter project. Use BEFORE writing or editing
  any widget State, callback passed to a route/transition/controller (e.g.
  SearchAnchor.viewBuilder, suggestionsBuilder, viewOnClose,
  AnimationController listeners, TickerFuture callbacks), async method that
  touches BuildContext, State.context, or State.widget after an await, or
  test reproducing an unmount race. Mandates the `if (!mounted) return;`
  guard idiom with capture-before-await hardening and cached-field
  safe-defaults, with DO/DON'T code examples derived from the FLUTTER-5S
  fix and its adversarial review.
---

# Async Gap & Mounted Context Safety

Use this skill whenever writing or editing code that:

- accesses `BuildContext`, `State.context`, **or `State.widget`** after an
  `await` or any async gap;
- passes a closure to a framework object that outlives the originating widget
  (e.g. `SearchAnchor.viewBuilder`/`suggestionsBuilder`/`viewOnClose`,
  `AnimationController` listeners, `TickerFuture` then-callbacks,
  `StreamSubscription`, `Timer`, `Future.delayed`, route
  `builder`/`pageBuilder` callbacks);
- calls `setState`, `notifyListeners`, `MediaQuery.of`, `Theme.of`,
  `Navigator.of`, or any inherited-widget lookup inside such a closure;
- reads `widget.<field>` inside any closure or async method that may run after
  the State unmounts;
- disposes a `TickerProvider`/`AnimationController`/`ScrollController`/
  `SearchController`/`TextEditingController` that still has live listeners; or
- writes a widget/integration test that unmounts a widget while a popup route,
  transition, or pending Future is still active.

This skill is the project authority for the class of bugs that caused Sentry
issue **FLUTTER-5S** (`TypeError: Null check operator used on a null value`
from `State.context` after the host navigated away during a popup exit
transition) and prevents its recurrence — including the `State.widget` crash
paths discovered during the adversarial review of the initial fix.

Reference files in this repo:
- `lib/ui/search/widgets/components/app_search_anchor.dart` — canonical fix
  (all guard sites: `suggestionsBuilder` top-of-closure + post-debounce,
  `_search` top + post-await, `_handleOnClose`, `onDeleted` delayed callback,
  `_buildViewBuilder`).
- `lib/ui/geo_map/widgets/geo_map_screen.dart` — `if (!mounted) return;`
- `lib/ui/sync/widgets/sync_screen.dart` — `if (!mounted) return;`
- `lib/ui/post/widgets/components/post_media_slideshow.dart` — `mounted` guards
- `lib/ui/weather/widgets/components/weather_forecast_hourly_list.dart`
- `lib/ui/content_submission/widgets/content_submission_add_asset_form.dart`
- `lib/ui/content_submission/widgets/content_submission_screen.dart`
- `test/ui/search/widgets/components/app_search_anchor_test.dart` — regression
  tests for the unmount-during-exit-transition race.

---

## The core rule

**Any access to `BuildContext`, `State.context`, or `State.widget` that
happens after an async gap, or inside a callback the framework may re-invoke
after the widget unmounts, MUST be preceded by a `mounted` guard.**

Two framework fields go null on unmount, and both are accessed via `!`:

```dart
// framework.dart
T get widget => _widget!;          // line 3653 — throws if _widget is null
BuildContext get context => _element!;  // line 958 — throws if _element is null
bool get mounted => _widget != null;    // line 3657 — mounted reads _widget
```

`Element.unmount()` sets `_widget = null` (line 4863). After that, any access
to `State.widget` or `State.context` throws:

```
TypeError: Null check operator used on a null value
  at State.widget (framework.dart:3653)    // widget.viewModel, widget.hintText, ...
  at State.context (framework.dart:958)    // Theme.of(context), MediaQuery.of(context), ...
```

These are **fatal, unhandled** errors in release mode and are the exact crash
class behind FLUTTER-5S. They are silent in the type system — the compiler
cannot catch them — so the guard is the only defense.

### The `mounted` ↔ `widget` invariant (critical)

`State.mounted` reads `_widget != null` — the **same field** as `State.widget`.
This has a critical consequence:

> **A `mounted` guard placed *after* a `widget.` read can never fire.**

If `!mounted` is true at the guard, then `_widget == null`, which means the
preceding `widget.<field>` access already threw. The guard is dead code.

Therefore the guard must always be placed **before any `widget.` or `context.`
access** — at the very top of the closure or method, not inside a helper that
the closure calls after reading `widget.`.

---

## Where async gaps hide

An "async gap" is not only an explicit `await`. It is any point where control
returns to the event loop before `widget`/`context` is touched:

| Gap type | Example | Why it's dangerous |
|---|---|---|
| `await` in the method body | `await repo.load(); widget.viewModel.x` | The widget can unmount while the Future is pending. |
| `await` before a callback returns | `suggestionsBuilder: (ctx, ctrl) async { await _search(...); return _buildChips(); }` | The framework re-invokes the callback after the host navigated away. |
| Closure captured by a long-lived object | `viewBuilder: (s) => ListView(children: [... context.padding ...])` | The route freezes the closure at open time and re-runs it on every animation tick of the exit transition. |
| `viewOnClose` / `viewOnSubmitted` | `viewOnClose: _handleOnClose` where `_handleOnClose` reads `widget.onBackPressed` | The popup route fires these from `didPop` after the host's `goNamed` already unmounted the anchor. |
| `Future.delayed` | `await Future.delayed(Durations.medium1, () => controller.text = '');` | The host can navigate away during the delay. |
| `Timer(Duration.zero, ...)` | Framework `didChangeDependencies` schedules a zero-delay timer. | The timer fires after unmount. |
| Debounce timer | `debounce(duration: 500ms, function: _search).call(query)` | The 500 ms timer may fire after the anchor unmounts if the user submits within the debounce window. |
| Listener on a shared controller | `_controller.addListener(updateSuggestions)` where `updateSuggestions` calls `suggestionsBuilder(context, ...)` | The listener survives the originating State's `_detach` and is only removed when the listener-owner itself disposes. |
| `TickerFuture` then-callback | `animation.forward().then((_) => setState(...))` | The ticker completes after the widget is disposed. |
| `State.widget` access in any of the above | `widget.viewModel.pastSearches` inside `suggestionsBuilder` | `State.widget` is `_widget!` — same `TypeError` as `State.context`, same unmount condition. |

---

## The `mounted` guard idiom (this project's established pattern)

This repo uses `if (!mounted) return;` (or `return <safe-default>;` when the
caller expects a value). **Use exactly this idiom.** Do not introduce
`if (!context.mounted)`, `Builder`, or a wrapper abstraction unless the plan
explicitly requires it — `State.mounted` is the project convention.

### For `void`-returning methods

```dart
Future<void> _loadSomething() async {
  final result = await _repository.load();
  if (!mounted) return;          // <-- guard before ANY widget/context/setState use

  setState(() {
    _data = result;
  });
}
```

### For value-returning callbacks (viewBuilder, suggestionsBuilder, etc.)

Return a harmless, cheap default that the framework can render/feed into the
dismissing transition without touching `State.widget` or `State.context`:

```dart
Widget _buildViewBuilder(Iterable<Widget> suggestions) {
  if (!mounted) {
    return const SizedBox.shrink();   // <-- safe default, no context access
  }

  // ...existing body that reads context.colorScheme, MediaQuery, etc...
}
```

**Cached-field defaults.** When the callback has a cached result field
(e.g. `_lastHistory`, `_lastOptions`), return it instead of a synthetic
default. A field read is a plain Dart operation that cannot throw after
unmount:

```dart
suggestionsBuilder: (context, controller) async {
  if (!mounted) return _lastHistory;  // <-- cached field, safe post-unmount
  // ...
}
```

---

## Capture-before-await (preferred hardening)

A `mounted` guard at the top of an async method protects the *first* `widget.`
read, but any `widget.` read *after* the `await` is still unguarded — the
widget may unmount during the await. The preferred hardening is to **capture
all `widget.` references into locals before the first await**, then use only
the captured locals after the await, plus a post-await `mounted` guard:

```dart
Future<Iterable<ContentBase>?> _search([String? query]) async {
  if (!mounted) return null;              // <-- guard before any widget access

  // ...validation...

  final viewModel = widget.viewModel;     // <-- capture BEFORE await
  await viewModel.loadSuggestions.execute(query);

  if (!mounted) return null;              // <-- post-await guard

  final options = viewModel.suggestions;  // <-- captured local, not widget.
  return options;
}
```

This pattern — guard → capture → await → guard → captured-locals-only — is
the canonical form for async methods that touch `widget` across an await.

---

## DO / DON'T

### 1. Accessing `widget`/`context` after `await` in a State method

#### DON'T

```dart
Future<void> _refresh() async {
  final result = await _repository.fetch();
  // BAD: no mounted check — crashes if the widget unmounted during the await.
  widget.viewModel.update(result);   // State.widget throws _widget!
  context.goNamed(RouteNames.home);  // State.context throws _element!
  setState(() => _data = result);
}
```

This throws `TypeError: Null check operator used on a null value` from
`State.widget` or `State.context` when the user navigates away before
`fetch()` completes. This is the FLUTTER-5S class of bug.

#### DO

```dart
Future<void> _refresh() async {
  // Capture before the await — the widget may unmount during fetch().
  final viewModel = widget.viewModel;
  final result = await _repository.fetch();
  if (!mounted) return;            // <-- guard

  viewModel.update(result);        // <-- captured local
  context.goNamed(RouteNames.home);
  setState(() => _data = result);
}
```

---

### 2. Callbacks passed to `SearchAnchor` (or any route/transition)

The `SearchAnchor` widget freezes `viewBuilder`, `suggestionsBuilder`, and
`viewOnClose` into a popup route at open time. That route rebuilds
`viewBuilder` on **every animation tick** of the exit transition, the view
route stays a listener on the `SearchController` until the transition
completes, and `viewOnClose` fires from `didPop` — all three outlive the
anchor's State if the host navigates away.

> **Warning: a guard inside a helper is dead code if the caller reads
> `widget.` before calling the helper.** Because `State.mounted` reads
> `_widget != null` (the same field as `State.widget`), any `widget.` access
> *before* the guard will throw *before* the guard can fire. Always place the
> guard at the **top of the closure** that the framework invokes, before any
> `widget.` or `context.` access — not inside a helper that the closure calls
> after reading `widget.`.

#### DON'T

```dart
SearchAnchor(
  viewBuilder: (suggestions) {
    // BAD: context is read unconditionally. The framework re-invokes this on
    // every exit-transition tick AFTER the anchor may have been unmounted by
    // the host's goNamed. State.context throws _element!.
    return MediaQuery.removePadding(
      context: context,
      removeTop: true,
      child: ListView(children: [SizedBox(height: context.bottomPadding)]),
    );
  },
  suggestionsBuilder: (context, controller) async {
    // BAD: widget.viewModel is read BEFORE any guard. If the SDK re-invokes
    // this closure after unmount, State.widget throws _widget! here — a
    // guard inside _buildChips would never be reached.
    if (controller.text.isEmpty) {
      final history = widget.viewModel.pastSearches;  // <-- crashes here
      return _buildChips(texts: history);              // guard inside is dead
    }
    final options = await _debouncedSearch(controller.text);
    return _buildChips(texts: options?.toList() ?? []); // widget. after await
  },
)
```

#### DO

```dart
SearchAnchor(
  viewBuilder: _buildViewBuilder,        // <-- method reference, guarded inside
  suggestionsBuilder: (context, controller) async {
    // Guard at the TOP of the closure, before any widget./context. access.
    // Return a cached field — a plain field read that cannot throw.
    if (!mounted) return _lastHistory;

    // Capture before any await — the widget may unmount while the debounce
    // timer or the API call is in flight.
    final viewModel = widget.viewModel;
    final onSuggestionPressed = widget.onSuggestionPressed;

    if (controller.text.isEmpty) {
      final history = viewModel.pastSearches;   // <-- captured local
      return _lastHistory = _buildChips(
        viewModel: viewModel,                    // <-- pass as parameter
        texts: history,
      );
    }

    final options = (await _debouncedSearch(controller.text))?.toList();

    // Guard again after the debounce await.
    if (!mounted) return _lastOptions;

    if (options == null) return _lastOptions;

    return _lastOptions = <Widget>[
      ListenableBuilder(
        listenable: viewModel.loadSuggestions,   // <-- captured local
        builder: (context, _) {
          // ...use viewModel.* and onSuggestionPressed, never widget.*...
        },
      ),
    ];
  },
  // Guard viewOnClose — fires from didPop after unmount.
  viewOnClose: widget.onBackPressed != null ? _handleOnClose : null,
)

// ...

Widget _buildViewBuilder(Iterable<Widget> suggestions) {
  if (!mounted) {
    return const SizedBox.shrink();        // <-- guard: no context access
  }
  // ...existing body...
}

List<Widget> _buildChips({required SearchViewModel viewModel, ...}) {
  // NO guard here — the caller (suggestionsBuilder) guarantees mounted
  // and passes viewModel as a parameter, so this method never reads
  // State.widget. Tap callbacks that fire after unmount (e.g.
  // Future.delayed) have their OWN guards.
  return texts.map((e) => RawChip(
    // ...use viewModel.* not widget.*...
  )).toList();
}

void _handleOnClose() {
  if (!mounted) return;                    // <-- guard before widget. access
  widget.onBackPressed?.call();
}
```

**Key principles embodied here:**

1. **Guard at the closure top** — before any `widget.`/`context.` read.
2. **Capture `widget.*` into locals before any `await`** — then use only
   captured locals after the await.
3. **Post-await guard** — re-check `mounted` after every `await`.
4. **Pass captured references as parameters to helpers** — helpers should
   never read `State.widget` themselves; the caller guarantees `mounted` and
   passes what the helper needs.
5. **Return cached-field defaults** (`_lastHistory`, `_lastOptions`) — plain
   field reads that cannot throw post-unmount.

---

### 3. `AnimationController` / `Ticker` callbacks after disposal

#### DON'T

```dart
late final AnimationController _controller;

@override
void initState() {
  super.initState();
  _controller = AnimationController(
    vsync: this,
    duration: const Duration(milliseconds: 300),
  )..forward().then((_) {
    // BAD: no mounted check — the widget can be disposed before the
    // animation completes. setState on a dead State throws, and any
    // context access crashes.
    setState(() => _animationDone = true);
  });
}
```

This produces `setState() called after dispose()` or the null-check
`State.context` error.

#### DO

```dart
late final AnimationController _controller;

@override
void initState() {
  super.initState();
  _controller = AnimationController(
    vsync: this,
    duration: const Duration(milliseconds: 300),
  )..forward().then((_) {
    if (!mounted) return;            // <-- guard
    setState(() => _animationDone = true);
  });
}

@override
void dispose() {
  _controller.dispose();             // <-- always dispose the controller
  super.dispose();
}
```

For listeners added via `addListener`, prefer removing the listener in
`dispose()` **and** guarding inside the callback:

```dart
@override
void initState() {
  super.initState();
  _controller.addListener(_onTick);
}

void _onTick() {
  if (!mounted) return;              // <-- guard: listener may fire during
                                      //     the dispose sequence
  setState(() {});
}

@override
void dispose() {
  _controller.removeListener(_onTick);  // <-- remove listener
  _controller.dispose();
  super.dispose();
}
```

---

### 4. `Future.delayed` / `Timer` callbacks

#### DON'T

```dart
void _onDeleteChip(String e) {
  _searchController.text = '\u200B';
  Future.delayed(Durations.medium1, () {
    // BAD: the user can navigate away during Durations.medium1.
    _searchController.text = '';
    setState(() {});                // crashes if disposed
  });
}
```

#### DO

```dart
void _onDeleteChip(String e) {
  _searchController.text = '\u200B';
  Future.delayed(Durations.medium1, () {
    if (!mounted) return;           // <-- guard
    _searchController.text = '';
    setState(() {});
  });
}
```

For `Timer` stored in a field, also cancel it in `dispose()`:

```dart
Timer? _resetTimer;

@override
void dispose() {
  _resetTimer?.cancel();            // <-- cancel pending timer
  super.dispose();
}
```

**Debounce timers (guarded, not cancelled).** When the timer is owned by a
utility like `Debounced` (see `lib/utils/debounceable.dart`) and the State
stores only the `.call` tear-off — not the `Debounced` instance itself — the
timer cannot be cancelled in `dispose()`. In this case, a `mounted` guard at
the top of the debounced function is the chosen mitigation:

```dart
Future<Iterable<ContentBase>?> _search([String? query]) async {
  // The debounce timer (500 ms) may fire after the anchor has been
  // unmounted. Guard before any widget access.
  if (!mounted) return null;
  // ...
}
```

If the debounce window is long and unmount-during-debounce is a likely user
flow, consider storing the `Debounced` instance and calling `.cancel()` in
`dispose()` as additional hardening.

---

### 5. `StreamSubscription` callbacks

#### DON'T

```dart
StreamSubscription<List<Item>>? _sub;

@override
void initState() {
  super.initState();
  _sub = _repository.watchItems().listen((items) {
    // BAD: the stream can emit after the widget is disposed.
    setState(() => _items = items);
  });
}
```

#### DO

```dart
StreamSubscription<List<Item>>? _sub;

@override
void initState() {
  super.initState();
  _sub = _repository.watchItems().listen((items) {
    if (!mounted) return;           // <-- guard
    setState(() => _items = items);
  });
}

@override
void dispose() {
  _sub?.cancel();                   // <-- cancel the subscription
  super.dispose();
}
```

---

### 6. Using `BuildContext` across an `await` in a `build` method or callback

`build` methods are synchronous and must never contain `await`. If you need
async work, move it to a lifecycle method or an event handler and guard the
post-async context access.

#### DON'T

```dart
Widget build(BuildContext context) {
  _repository.fetch().then((data) {
    // BAD: `context` is the build context captured by the closure; it may be
    // invalid by the time the Future completes.
    Navigator.of(context).push(...);
  });
  return Container();
}
```

#### DO

```dart
Future<void> _loadAndNavigate() async {
  final data = await _repository.fetch();
  if (!mounted) return;             // <-- guard
  Navigator.of(context).push(...);
}

Widget build(BuildContext context) {
  return SomeWidget(onTap: _loadAndNavigate);  // async work in an event handler
}
```

---

### 7. Tests: unmounting a widget while a popup route / transition is active

When writing a widget test that reproduces an unmount race, you must:

1. **Drive the real framework path** (e.g. the view's `SearchBar.onSubmitted`,
   not a manual reconstruction) so the production close-then-navigate order is
   preserved.
2. **Pump exit-transition frames** after unmount so the framework re-invokes the
   captured callback on the dead State.
3. **Assert `tester.takeException()` is null** to prove the guard prevents the
   crash.
4. **Confirm the test fails (red) on the unguarded code** before accepting it as
   a regression test. Execute the red run — do not rely on analytic argument
   alone.

#### DON'T

```dart
testWidgets('submission does not crash', (tester) async {
  await tester.pumpWidget(MyApp());
  await tester.tap(find.byType(SearchBar));
  await tester.pumpAndSettle();

  // BAD: calls onSubmitted manually, skipping closeView — no exit transition
  // starts, so the race is never exercised. This test passes even on buggy
  // code and gives false confidence.
  tester.widget<AppSearchAnchor>(find.byType(AppSearchAnchor)).onSubmitted!('q');
  await tester.pumpAndSettle();

  expect(tester.takeException(), isNull);   // meaningless — no race occurred
});
```

#### DO — test 1: viewBuilder guard (exit-transition ticks)

```dart
testWidgets(
  'submission that goNamed-unmounts the anchor does not crash during '
  'the popup exit transition',
  (tester) async {
    installDiagnosticFilter();  // swallow debug-only "deactivated ancestor"

    final fixture = _ShellSearchFixture(navigateOnSubmit: true);
    addTearDown(fixture.dispose);
    await fixture.pumpApp(tester);

    // Open the search view.
    await tester.tap(find.byType(SearchBar));
    await tester.pumpAndSettle();
    expect(fixture.controller.isOpen, isTrue);

    // Enter a valid query and let the debouncer settle.
    fixture.controller.text = 'molise';
    await tester.pump(const Duration(milliseconds: 600));
    await tester.pump();

    // Drive the framework's real viewOnSubmitted path with ONE call.
    // The view's SearchBar.onSubmitted is wired to SearchAnchor's
    // viewOnSubmitted, which performs closeView (pop + 600 ms exit
    // transition) -> onSubmitted (goNamed -> unmount anchor) in
    // production order.
    final viewBar = tester.widget<SearchBar>(
      find.byType(SearchBar).last,
    );
    viewBar.onSubmitted!('molise');

    // Process the pop + goNamed, then run every exit-transition tick.
    // The 600 ms popup exit outlives the ~300 ms route pop, so
    // post-unmount ticks are guaranteed.
    await tester.pump();
    await tester.pumpAndSettle();

    expect(tester.takeException(), isNull);
    expect(fixture.matchedLocation, '/home/search_results');
    debugDefaultTargetPlatformOverride = null;
  },
);
```

#### DO — test 2: suggestionsBuilder guard (direct closure re-invocation)

To test the `suggestionsBuilder` top-of-closure guard, capture the closure
before unmount and directly re-invoke it after. This is more reliable than
mutating `controller.text` and hoping the SDK's listener fires at the right
time:

```dart
testWidgets(
  'suggestionsBuilder does not crash when re-invoked after unmount',
  (tester) async {
    installDiagnosticFilter();

    final fixture = _ShellSearchFixture(
      navigateOnSubmit: true,
      pastSearches: const ['termoli'],
    );
    addTearDown(fixture.dispose);
    await fixture.pumpApp(tester);

    // Open the search view — a history chip is visible.
    await tester.tap(find.byType(SearchBar));
    await tester.pumpAndSettle();

    // Capture the suggestionsBuilder closure and a valid context
    // before unmounting the anchor.
    final searchAnchor = tester.widget<SearchAnchor>(
      find.byType(SearchAnchor),
    );
    final suggestionsBuilder = searchAnchor.suggestionsBuilder;
    final callbackContext = tester.element(find.byType(MaterialApp));

    // Submit → closeView → goNamed (page replacement → unmount old anchor).
    final viewBar = tester.widget<SearchBar>(find.byType(SearchBar).last);
    viewBar.onSubmitted!('molise');

    // Process the pop + goNamed + unmount. Pump enough frames for the
    // element to be fully unmounted (_widget = null, mounted = false).
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 50));

    // Directly re-invoke the captured suggestionsBuilder on the dead
    // anchor State. Without the mounted guard at the top of the closure,
    // widget.viewModel throws the null-check TypeError.
    await suggestionsBuilder(callbackContext, fixture.controller);

    await tester.pumpAndSettle();

    expect(tester.takeException(), isNull);
    debugDefaultTargetPlatformOverride = null;
  },
);
```

#### Diagnostic filter helper

Install a shared `FlutterError.onError` filter that swallows the debug-only
"deactivated widget's ancestor" diagnostic. This diagnostic does not appear in
release mode and would otherwise cause `takeException` to report a false
failure:

```dart
void installDiagnosticFilter() {
  final previousErrorHandler = FlutterError.onError;
  FlutterError.onError = (details) {
    if (details.exception.toString().startsWith(
      "Looking up a deactivated widget's ancestor is unsafe.",
    )) {
      return;
    }
    previousErrorHandler?.call(details);
  };
  addTearDown(() => FlutterError.onError = previousErrorHandler);
}
```

**Important test invariants:**

- Do **not** call `controller.isOpen` or `controller.closeView(...)` after the
  anchor is unmounted — both assert `isAttached` / hit `_anchor!`. Post-unmount,
  either mutate `controller.text` directly (a `TextEditingController` method,
  independent of the anchor) or directly re-invoke the captured closure.
- Use `tester.pump` durations, never `Future.delayed`, to keep tests
  deterministic.
- Set `debugDefaultTargetPlatformOverride = TargetPlatform.android` in the
  fixture constructor and reset it to `null` in `dispose()` and at the end of
  each test, matching the existing fixture convention.
- **Execute the red run** — temporarily remove each guard and confirm the
  test fails with the expected `TypeError`. An analytic argument that a guard
  is reachable is not sufficient; the test infrastructure (e.g.
  `StatefulShellRoute.indexedStack` keeping pages mounted during transitions)
  may prevent the race from actually occurring.
- Reuse existing fixtures additively (e.g. extend `_ShellSearchFixture` with
  optional parameters) rather than duplicating near-verbatim fixture classes.

---

## Common error messages this skill prevents

| Error message | Root cause | Fix |
|---|---|---|
| `TypeError: Null check operator used on a null value` at `State.widget` | `State.widget` is `_widget!`; `_widget` is `null` after `Element.unmount`. | `if (!mounted) return;` before any `widget.` access after an async gap or in a long-lived callback. `mounted` reads `_widget != null` — same field. |
| `TypeError: Null check operator used on a null value` at `State.context` | `State.context` is `_element!`; `_element` is `null` after unmount. | `if (!mounted) return;` before any `context` access after an async gap or in a long-lived callback. |
| `setState() called after dispose()` | `setState` invoked on a disposed State. | `if (!mounted) return;` before `setState`; cancel timers/subscriptions in `dispose`. |
| `A ticker was started on a disposed TickerProvider` | `AnimationController`/`Ticker` used after the widget's `dispose`. | Dispose the controller in `dispose()`; guard `TickerFuture` then-callbacks with `mounted`. |
| `Looking up a deactivated widget's ancestor is unsafe.` | `BuildContext` used during the deactivation window (debug-only diagnostic). | Guard with `mounted`; if the diagnostic still appears in tests, swallow it via `installDiagnosticFilter()` — it is debug-only noise, not a production `TypeError`. |
| `setState() or markNeedsBuild() called during build` | `setState`/rebuild triggered synchronously inside a `build` method or listener that fires mid-build. | Defer with `WidgetsBinding.instance.addPostFrameCallback` and guard with `mounted`. |

---

## Checklist before committing code that touches `widget`/`context` after async

- [ ] Every method that `await`s and then reads `widget.*`/`context`/`setState`
      has a `if (!mounted) return;` guard immediately after the `await`.
- [ ] Every async method that reads `widget.*` both before and after an `await`
      captures `widget.*` into locals before the first `await` and uses only
      captured locals after the `await`.
- [ ] Every closure passed to `SearchAnchor.viewBuilder`/
      `suggestionsBuilder`/`viewOnClose`/`AnimationController.addListener`/
      `Timer`/`Future.delayed`/`StreamSubscription` has a `mounted` guard at
      the **top of the closure** — before any `widget.`/`context.` access —
      or is removed/cancelled in `dispose()`.
- [ ] No guard is placed **after** a `widget.` read in the same closure/method
      — `mounted` reads the same field as `widget`, so such a guard is dead
      code.
- [ ] Every value-returning guarded callback returns a safe, cheap default
      (`SizedBox.shrink()`, `const <Widget>[]`, a cached field like
      `_lastHistory`/`_lastOptions`, `null`) — never throws, never touches
      `widget` or `context`.
- [ ] Helpers called from guarded closures receive captured references as
      parameters and never read `State.widget` themselves.
- [ ] Every `AnimationController`, `ScrollController`, `SearchController`,
      `TextEditingController`, `StreamSubscription`, `Timer`, and `FocusNode`
      created by the State is disposed/cancelled in `dispose()`. If a timer
      cannot be cancelled (e.g. a debounce timer owned by a utility), a
      `mounted` guard at the top of the timer's callback is the documented
      mitigation.
- [ ] No `build` method contains `await` or starts a Future that reads
      `widget`/`context` in its completion callback without a `mounted` guard.
- [ ] A widget test reproduces the unmount race (open → close + navigate →
      pump exit transition → `takeException()` is null) and was **executed**
      (not argued analytically) to fail on the unguarded code.
- [ ] `dart analyze` on the changed file is clean.
