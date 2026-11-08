---
name: flutter-ui-engineering
description: >-
  Molise Is-specific Flutter UI composition and review guidance. Use before
  creating or materially changing Screens, feature widgets, or ViewModels under
  lib/ui/, and when reviewing oversized or tightly coupled Flutter UI code.
---

# Flutter UI engineering — Molise Is

## Scope and precedence

Apply to new or materially changed `lib/ui/**` code and its relevant tests.
The goal is cohesive, testable Screens and ViewModels, not a target line count.
Follow root `AGENTS.md` and any approved change specification first. Reuse
existing feature patterns only when sound. This project-specific UI guidance
takes precedence over conflicting generic Flutter skills within its scope;
it does not override project architecture, specialized lifecycle rules, or
explicit product requirements.

In particular, keep Provider/`ChangeNotifier`, the existing dependency root,
domain-facing repositories, `command_it`/`Result` contracts, `go_router`
ownership, and the established design system. Do not add another state
management approach, dependency, or architectural layer just to shorten files.
Read `.agents/skills/molise-is-async-mounted-context-safety/SKILL.md` for
changes involving async widget callbacks or post-unmount access.

## Before implementing

For a substantial Screen or ViewModel change (not a trivial visual edit):

1. Inspect the affected feature, sibling widgets, ViewModel, tests and shared
   components. Identify existing state and resource owners.
2. Sketch the cohesive visual sections, state ownership (local UI vs.
   ViewModel), commands, side effects and important rebuild boundaries.
   Keep this lightweight; no planning artifact is required for small work.
3. Choose the least complex design: simplify in place, extract a meaningful
   widget, reuse a suitable existing component, then add a justified new
   collaborator only if necessary. Do not extract solely to satisfy line counts.
4. Identify lifecycle/owner changes and relevant regression cases before
   altering orchestration or splitting a ViewModel.

## DO / DON'T — rule catalog

`MUST` rules apply when relevant to the change and need an explicit reason
if a documented exception is necessary. `SHOULD` rules are strong defaults;
deviations are acceptable when they make the code simpler or safer.
An existing file is not defective merely because it predates a rule.

### Composition

| ID | Level | DO | DON'T |
| --- | --- | --- | --- |
| UI-01 | SHOULD | Keep the Screen focused on composition, visible state and interactions. | Accumulate unrelated workflows in one Screen class. |
| UI-02 | SHOULD | Extract cohesive, understandable sections of a large widget tree. | Grow one huge nested `build()` tree. |
| UI-03 | SHOULD | Prefer private or public widget classes for meaningful subtrees, especially those with distinct rebuild boundaries. | Replace composition with dozens of large `_build*()` methods returning widgets. |
| UI-04 | SHOULD | Keep small private widgets in the same file when clear; use separate files for independently meaningful or reused sections. | Create a file for every `Padding`, `Row` or one-line widget. |
| UI-05 | SHOULD | Pass the minimum meaningful inputs and callbacks into leaf components. | Pass a whole ViewModel to every leaf or introduce long, fragile parameter chains. |
| UI-06 | SHOULD | Reuse existing shared controls and form primitives when behavior matches. | Fork button, feedback, form and loading patterns without a reason. |
| UI-07 | SHOULD | Share a component only for real reuse or a stable independent responsibility. | Add generic widget factories, base classes or abstractions for hypothetical reuse. |

A small private rendering helper is not automatically wrong. A separate
`StatelessWidget` is preferred when it provides encapsulation, independent
identity or a useful rebuild boundary. A View can contain many widgets; do
not create a separate ViewModel for each widget.

### State and boundaries

| ID | Level | DO | DON'T |
| --- | --- | --- | --- |
| UI-08 | MUST | Keep repository access, domain rules and app workflows outside widget rendering code. | Fetch, persist, validate domain invariants or implement business workflows in the Screen. |
| UI-09 | MUST | Give feature/application state and command orchestration an authoritative owner. | Duplicate mutable business state in `State`, ViewModel and repository. |
| UI-10 | SHOULD | Keep purely ephemeral visual state (focus, animation, local expansion) in the owning widget. | Move every controller and short-lived UI detail into a ViewModel. |
| UI-11 | MUST | Trigger established ViewModel commands and present their state/results. | Bypass command contracts or re-orchestrate multiple application operations inside callbacks. |
| UI-12 | SHOULD | Split a large ViewModel only across proven, testable responsibility boundaries; preserve its orchestration owner. | Introduce one ViewModel per section or move methods mechanically into helper classes. |
| UI-13 | SHOULD | Distinguish user-relevant idle, loading, partial, success and error states as required by the flow. | Hide meaningful errors or partial outcomes behind a single ambiguous flag. |

Do not introduce sealed-state hierarchies automatically: use the project's
existing command snapshots and presentation state when sufficient. When
changing draft, save, navigation or recovery behavior, preserve single-flight,
revision, identity and publication-authority invariants.

### Lifecycle and performance

| ID | Level | DO | DON'T |
| --- | --- | --- | --- |
| UI-14 | MUST | Keep `build()` free of side effects and repeated expensive work. | Start network calls, persistence, subscriptions or navigation during rendering. |
| UI-15 | MUST | Bind/unbind owned listeners and dispose owned controllers at the correct lifecycle points; handle owner replacement. | Leave subscriptions attached after `dispose()` or `didUpdateWidget()` swaps dependencies. |
| UI-16 | MUST | Guard async continuation against unmount and stale identity/owner where relevant. | Treat `mounted` alone as proof that a returned result still belongs to the active session. |
| UI-17 | SHOULD | Localize state subscriptions and rebuilds around the content that changes. | Rebuild an entire complex Screen for a small independent change without reason. |
| UI-18 | SHOULD | Use `const` when applicable and lazy builders for potentially large collections. | Eagerly build long collections or repeat expensive work in `build()`. |
| UI-19 | SHOULD | Measure a suspected performance issue with DevTools before special optimization. | Add caching or `RepaintBoundary` everywhere without evidence. |

Keep `BuildContext` and `State.widget` mounted-guard rules, lifecycle fencing
and the project's `command_it` edge cases in their owning instructions.
Localizing rebuilds should not duplicate application state or break atomic UI
snapshots.

### Layout, design and accessibility

| ID | Level | DO | DON'T |
| --- | --- | --- | --- |
| UI-20 | SHOULD | Base responsive decisions on available constraints (`LayoutBuilder`) or window size (`MediaQuery.sizeOf`) as appropriate. | Assume device type or portrait orientation implies available width. |
| UI-21 | SHOULD | Use the project's theme, typography and established design tokens/components. | Hardcode inconsistent colors, typography or spacing in new UI. |
| UI-22 | SHOULD | Check narrow/expanded layouts and larger text scaling where affected. | Suppress text scaling or let essential controls overflow or disappear. |
| UI-23 | MUST | Make new or altered interactive controls accessible, with meaningful labels, semantics, focus and reasonable target sizes. | Rely only on color, unlabeled icons or inaccessible custom gestures. |
| UI-24 | SHOULD | Represent applicable loading, empty, failure and completion states with usable feedback. | Render unexplained blank states, duplicate submissions or silent terminal failures. |

### Tests and review

| ID | Level | DO | DON'T |
| --- | --- | --- | --- |
| UI-25 | MUST | Unit-test new or changed nontrivial ViewModel/state decisions proportionately to risk. | Test business transitions only through elaborate widget pumps. |
| UI-26 | MUST | Widget-test material visible transitions and interactions affected by the change. | Equate successful compilation with correct UI behavior. |
| UI-27 | MUST | Cover owner replacement, disposal and stale async results when those failure modes are introduced or changed. | Test only the happy path for identity-sensitive asynchronous work. |
| UI-28 | MUST | Run relevant formatting, analyzer and tests; report actual outcomes and pre-existing failures accurately. | Claim comprehensive correctness from a green suite or fabricate checks. |

`MUST` in the test section is conditional on a material behavior or risk
being changed: a trivial cosmetic edit does not require new ViewModel tests
or broad end-to-end coverage.

## Size-based review heuristics — not lints

For new or materially edited UI code, use these **review triggers**:

| Trigger | Review action |
| --- | --- |
| Single `build()` exceeds ~150 lines | Consider visual sections, owner clarity and rebuild boundaries. |
| Screen file exceeds ~400 lines | Review component boundaries and coupled responsibilities. |
| Screen file exceeds ~600 lines | Explicitly justify keeping it together or simplify/extract. |
| ViewModel file exceeds ~800 lines | Review mixed responsibilities, orchestration and possible safe extraction. |

These are **not** official Flutter limits, automatic PR blockers, or
instructions to rewrite existing large files. Do not game them with
`part` files, thin forwarding classes, static widget factories or trivial
one-widget files. If a touched file exceeds a trigger, briefly explain in
the implementation/review report why its boundaries are appropriate or
what focused refactor is needed. No separate evidence artifact is required.

Calibration on `main` at `ff07477e` (2026-11-08): 5 of 18
`*_screen.dart` files exceeded 400 lines, 2 exceeded 600; 2 of 16
`*_view_model.dart` files exceeded 800. These counts justify review
attention only; they do not establish defects.

## Completion check

Before considering a material UI change done:

- Confirm that the Screen describes UI rather than executing data workflows;
  named sections have clear input/interaction contracts, and local state has
  the narrowest correct owner.
- Verify command/result ownership, loading/error feedback and lifecycle safety;
  for asynchronous flows check identity, concurrency and stale completions.
- Look for unjustified file fragmentation, copied patterns, hardcoded design
  tokens and needless new abstractions.
- Run targeted unit/widget tests and the relevant analyzer/format checks;
  disclose checks not executed and any existing failures.
- If size heuristics trigger, report a reasoned assessment, not an automatic
  failure. Avoid refactoring unrelated legacy files.

## Authoritative references

- Flutter architecture: https://docs.flutter.dev/app-architecture/recommendations
- Flutter MVVM guide: https://docs.flutter.dev/app-architecture/guide
- Flutter performance: https://docs.flutter.dev/perf/best-practices
- Flutter adaptive UI: https://docs.flutter.dev/ui/adaptive-responsive/best-practices
- Flutter accessibility: https://docs.flutter.dev/ui/accessibility
- Flutter testing: https://docs.flutter.dev/testing/overview
- Dart style: https://dart.dev/effective-dart

Use docs compatible with the actual checked-out Flutter/Dart SDK; do not
assume that every example in the latest online docs is available locally.
