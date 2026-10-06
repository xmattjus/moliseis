## Context

See proposal.md for intent. This design is rebased on local `main` HEAD
`e9f792d0e468a8ccb1f8609e3934a549d102f411`, audited on 2026-10-06.
`git ls-remote origin refs/heads/main` returned
`925baa74d8feaeaee6865043207646f4adf8d687`. Local HEAD adds one
post-presentation commit, including `AppTextStyles.postName` and
`postCityName`. Both revisions were inspected; implementation follows the
explicit local checkout baseline, not an assumed remote HEAD. The change was
already present as an untracked directory; no other working-tree changes were
present. Recheck drift before implementing; do not recreate the change.

`pubspec.yaml` declares Flutter 3.47.5, material_ui ^1.5.0,
flex_seed_scheme ^5.0.1, cupertino_ui ^1.1.1 and flutter_quill ^11.5.1.
The lockfile resolves 1.5.0, 5.0.1, 1.1.1 and 11.6.0 respectively.
The actual SDK is `/opt/homebrew/Caskroom/flutter/3.47.5/flutter` (also
reachable through `/opt/homebrew/share/flutter`), tag 3.47.5, commit
`6a19cca56475dbfba1478ee68d7bd0c2ef891da1`.

### Dependency and framework evidence

The app imports the **material_ui fork's** Theme, ThemeData, TextTheme and
Typography, not Flutter's material classes. Inspection of both Flutter 3.47.5
`packages/flutter/lib/src/material/{theme,theme_data,typography,text_theme}.dart`
and material_ui 1.5.0 `lib/src/` counterparts confirms the relevant behavior:

1. ThemeData chooses material2021 typography for Material 3, uses its
   brightness-dependent color/family styles, applies `fontFamily` and fallback
   to those defaults, then merges the supplied partial textTheme. Partial
   styles must retain `inherit: true`; `inherit: false` would replace defaults.
2. Theme.of reads `MaterialLocalizations.scriptCategory`, selects
   `typography.geometryThemeFor(category)`, and invokes ThemeData.localize.
   Localize merges geometry with the configured textTheme and primaryTextTheme.
   Thus the raw partial appTextTheme, constructed ThemeData.textTheme and
   context-resolved TextTheme are distinct boundaries. Resolved styles need
   not have a non-null `locale`; geometry reflects script category, while text
   rendering also consumes its locale.
3. Localize copies extensions unchanged. A precomputed TextTheme extension
   receives no automatic geometry localization. Extensions are not inherently
   incapable of holding typography, but fixing that with a second localization
   mechanism is unnecessary here. Derivation after Theme.of is the smaller
   correct boundary.
4. TextTheme.merge merges role by role. TextStyle.copyWith preserves omitted
   properties, including fontVariations; TextStyle.merge preserves them when
   the incoming inheriting style omits them, but replaces the **whole list**
   when it supplies a list (including an empty one). It does not merge axes.
5. TextTheme.of is a convenience for the same context theme; replacing it
   mechanically gains nothing. TextPainter defaults to no scaling; its caller
   must supply the renderer's scaler, direction and locale. Flutter 3.47.5
   widgets/text.dart also transforms Text's effective style using ambient
   boldText and height/letter/word spacing overrides; a painter does not do so.

material_ui 1.5.0 exports only the fifteen baseline roles. Searches of its
TextTheme, Typography, ThemeData and public exports found no emphasized scale
or typography adapter. `StyleVariant.material3Expressive` is an enum declaration
in theme_data.dart, not an available ThemeData typography switch or emphasized
provider. Existing Expressive shape/motion/component features do not supply
these fifteen typography roles. Do not add an opt-in flag or a package update.

flex_seed_scheme 5.0.1 provides seed/palette/ColorScheme APIs, not ThemeData,
fontFamily or TextTheme configuration. In this checkout
`AppColorSchemesThemeExtension.fromSeed` calls `SeedColorScheme.fromSeeds`
with vivid/vibrant variants, then AppThemeData passes the main scheme into
BaseThemeData. Keep that construction unchanged; runtime semantic colors must
use the resulting current scheme, not independently recreate seeds.

## Goals / Non-Goals

Provide a minimal runtime emphasis boundary with no second baseline or token
geometry database; preserve native localization and existing content semantics.
Fix the identified weight and text-scaling inputs without redesigning layouts.

No packages, state management, typography service, cache, new ThemeExtension,
color-system refactor, navigation changes, custom lint, custom font manager,
backend changes, or broad accessibility migration. No new font-axis management.

## Decisions

### 1. Partial brand configuration plus the default plain font

Set `fontFamily: 'Lexend'` alongside `textTheme: appTextTheme` in
BaseThemeData.get and the independent AppThemeData.photoViewer constructor.
Use one shared const inheriting Fraunces style containing only fontFamily and
`FontVariation('SOFT', 50)` for displayLarge/Medium/Small,
headlineLarge/Medium/Small and titleLarge. Omit every other role from
appTextTheme. Do not specify size, weight, height, tracking or color there.
Do not apply Lexend to an already composed TextTheme, which would overwrite
brand families. PrimaryTextTheme consequently receives the default Lexend
family; do not invent a parallel branded primary scale without a consumer.

The seven brand roles follow the Brand/Plain categories in the primary M3
implementation linked below. titleMedium and titleSmall are Plain, even when
an app uses them as headings. The new post name explicitly uses a brand
headline, providing a concrete application consumer for this division.

Intentional visual effects, not hidden compatibility promises:

- display/headline roles change from platform families to Fraunces with SOFT
  50. Current direct consumers include weather's main temperature
  (displayMedium) and submission progress text (headlineSmall); framework
  dialogs and date/time pickers can also consume headline/display roles.
- titleSmall changes Fraunces to Lexend. No direct current role read was found
  outside theme declarations; framework components can consume it.
- postName keeps headlineLarge, Fraunces, medium weight and SOFT 50;
  postCityName keeps plain titleMedium. Ordinary body/label/titleMedium and
  titleLarge retain their current family assignments.
- removing pinned `wght` makes existing local weight overrides effective:
  rail selected bold becomes w700 and unselected normal becomes w400 instead
  of both being pinned to w500; hourly weather keeps its explicit w300;
  local body bold in daily weather,
  submission field labels and inherited AppBar weights can now render as
  intended. Quill already cleared variations, so its inline bold is preserved.
- photoViewer inherits Lexend defaults as well; its content/action labels and
  fallback styles must be checked independently of the normal app theme.

This does not authorize migrating every local bold style or adjusting component
sizes to compensate for new glyph metrics. Visual QA verifies these declared
changes; it is not an unresolved architecture/design choice.

### 2. Standard weights use FontWeight; only SOFT is explicitly retained

The bundled fvar tables were read directly:

| Asset | Axes (min / default / max) |
| --- | --- |
| Fraunces-VariableFont.ttf | wght 100/900/900; opsz 9/9/144; SOFT 0/0/100; WONK 0/1/1 |
| Lexend-VariableFont.ttf | wght 100/400/900 |

Both regular assets are declared under their families in pubspec without
static weight descriptors. Fraunces italic is present on disk but commented
out of the manifest; enabling it is outside scope. No production code actively
sets opsz, WONK, wdth or GRAD; only SOFT and wght are currently used.
Remove the stale commented speculation about WONK support without introducing
an axis-management feature.

Flutter 3.47.5 `engine/src/flutter/lib/ui/text.dart` documents that FontWeight
sets a variable font's wght axis. It also supports arbitrary integer weights;
no arbitrary values are needed here, so use existing w300/w400/w500/w700
constants. An explicit wght variation takes precedence over fontWeight.
SOFT alone does not pin weight; copyWith(fontWeight: ...) preserves SOFT.
Fraunces' unusual default wght of 900 makes relying on the font's native default
particularly inappropriate: retain resolved Material FontWeight values.

Replace hourly `FontVariation.weight(300)` with fontWeight w300. Migrate
postName as described below and remove all other app-owned explicit wght
entries. Do not add custom fallback lists: leave native fallback behavior.

### 3. Small runtime facade, one baseline access path

Create AppTypography.of(context) from **material_ui Theme.of(context)** and
add `context.appTypography` to the existing BuildContext extensions.
Its public surface is only:

- `emphasized`: a complete TextTheme derived from the resolved theme;
- `section`: resolved titleMedium with current colorScheme.primary;
- `link`: resolved bodySmall with secondary at alpha 0.7, underline and the
  same decoration color.

Store the resolved immutable theme (or its textTheme and colorScheme) privately.
Compute emphasized in its getter, not eagerly in the constructor, so ordinary
section/link calls do not allocate fifteen copied styles. At an emphasized
consumer read the facade/scale once per build. No global/context cache, retained
BuildContext, memoization layer or profiling claim is required. This small
on-demand allocation has no demonstrated performance defect.

Keep context.textTheme as the sole public baseline path; a second `baseline`
getter and aliases subtitle/title/titleSmaller add no migration boundary.
Migrate those aliases to bodyMedium/titleLarge/titleMedium directly.
Migrate postName to emphasized.headlineLarge at PostSectionHeader and
postCityName to context.textTheme.titleMedium; do not create global post tokens.

Move calendarWeekDay and calendarMonthSection to private helpers in
EventsVerticalCalendarMonth. Preserve their distinct sources: weekday derives
from DatePickerTheme.defaults(context).weekdayStyle with black45/white54;
month heading derives from titleMedium with black87/white70, **not** from
DatePickerTheme. Delete text_styles.dart only after all nine existing helpers'
consumers are migrated. Delete the empty AppTextStylesThemeExtension and its
barrel export; no replacement extension.

### 4. Verified temporary emphasized adapter

The normative overview is [Material 3 typography](https://m3.material.io/styles/typography/overview).
The directly inspectable primary implementation is AndroidX Material 3
[TypeScaleTokens at 160825094a81825468a95b115bfb1b541e549856](https://github.com/androidx/androidx/blob/160825094a81825468a95b115bfb1b541e549856/compose/material3/material3/src/commonMain/kotlin/androidx/compose/material3/tokens/TypeScaleTokens.kt),
last changed 2026-08-05, token version v0_103. Its emphasized section still has
a generated-token TODO: treat this as a pinned implementation source, not a
promise that future Expressive releases cannot change. The M3 site requires
JavaScript and its documentation index does not expose the full table; do not
claim the table was read from that page.

Every role was compared against the resolved Flutter/material_ui 2021 baseline.
Reference size/line-height values below are for verification only, not new Dart
constants. Flutter uses rounded height ratios; preserve those ratios and script
geometry rather than re-encoding exact Android sp line heights.

| Role | Category | Size / line height reference | Baseline -> emphasized weight | Flutter tracking -> emphasized |
| --- | --- | --- | --- | --- |
| displayLarge | Brand | 57 / 64 | 400 -> 500 | -0.25 -> 0 |
| displayMedium | Brand | 45 / 52 | 400 -> 500 | 0 unchanged |
| displaySmall | Brand | 36 / 44 | 400 -> 500 | 0 unchanged |
| headlineLarge | Brand | 32 / 40 | 400 -> 500 | 0 unchanged |
| headlineMedium | Brand | 28 / 36 | 400 -> 500 | 0 unchanged |
| headlineSmall | Brand | 24 / 32 | 400 -> 500 | 0 unchanged |
| titleLarge | Brand | 22 / 28 | 400 -> 500 | 0 unchanged |
| titleMedium | Plain | 16 / 24 | 500 -> 700 | 0.15 unchanged |
| titleSmall | Plain | 14 / 20 | 500 -> 700 | 0.1 unchanged |
| bodyLarge | Plain | 16 / 24 | 400 -> 500 | 0.5 -> 0.15 |
| bodyMedium | Plain | 14 / 20 | 400 -> 500 | 0.25 unchanged |
| bodySmall | Plain | 12 / 16 | 400 -> 500 | 0.4 unchanged |
| labelLarge | Plain | 14 / 20 | 500 -> 700 | 0.1 unchanged |
| labelMedium | Plain | 12 / 16 | 500 -> 700 | 0.5 unchanged |
| labelSmall | Plain | 11 / 16 | 500 -> 700 | 0.5 unchanged |

No role changes size, line height or family category between baseline and
emphasized. No additional emphasis property is defined by that source.
AndroidX baseline tracking differs slightly from Flutter for displayLarge,
bodyMedium and titleMedium; copy neither that baseline nor a second geometry
table. The only tracking overrides needed against the actual app baseline are
**displayLarge 0** and **bodyLarge 0.15**. Preserve tracking elsewhere, including
localized/custom baseline changes. Copy each resolved role, changing only its
emphasized weight and those two designated tracking values; preserve family,
height, size, color, fallback, locale, decoration, leadingDistribution,
textBaseline, features and non-weight variations. Do not copy the canonical
Roboto family over application Brand/Plain families.

Keep the adapter private in app_typography.dart with the pinned source comment.
Widgets request emphasized roles, not weight helper functions. Future native
support replaces this internal adapter only after verifying localization and
app-family preservation; do not promise forwarding an unknown future API.

### 5. Emphasis migration is selective

PostSectionHeader is the concrete emphasized.headlineLarge consumer; the
original unspecified "target screen" task is removed.

The app's NavigationRail labels and the material_ui 1.5.0 M3 defaults both
use labelMedium (navigation_rail.dart, _NavigationRailDefaultsM3). Retain this
role; there is no reason to change its size. Use emphasized.labelMedium when selected, and
context.textTheme.labelMedium.copyWith(fontWeight: FontWeight.normal) when
unselected. Retain the current selection determination and routing. Switching
unselected to baseline w500 would silently change its intended normal weight.
Preserve selected/unselected colors. Existing explicit resolved Text styles
have inherit:false and a color, so they override the rail DefaultTextStyle;
do not claim that native state styling overrides those label colors.

Weather primary temperature retains displayMedium.copyWith(fontWeight: bold):
w700 is a local hierarchy choice and emphasized.displayMedium would reduce it
to w500. Its family still changes through the declared global Brand mapping.
Other local weights, Markdown renderer metrics and content formatting remain.

### 6. Quill and Cupertino contracts

flutter_quill 11.6.0 builds inline styles by merging attributes with paragraph
styles; bold specifies FontWeight.bold, italic FontStyle.italic, underline and
links decoration/color. None requires resetting non-weight axes. Remove the
empty variation list from descriptionDeltaStyles and correct its documentation.
Normal bodyLarge is Lexend and has no SOFT; preserving SOFT matters only for an
inherited/custom Fraunces style, not because Quill paragraphs become brand text.
Retain paragraph/list spacing, link colors and all inline attribute semantics.
Test actual combined bold+italic+underline/link spans through existing editor
and read-only widgets, not just configuration fields.

The picker popup header is a title between cancel/confirm controls, so
Cupertino navTitleTextStyle is appropriate; dateTimePickerTextStyle belongs to
wheel values. In cupertino_ui 1.1.1 navTitleTextStyle is native 17/w600 with
CupertinoSystemText. Resolve it from a Builder **below the existing local
CupertinoTheme**, not dialogContext above that theme. No extra bold or custom
family override. This intentionally replaces Material 16/w700 plus undefined
'system' with the native toolbar title. Preserve picker wheel and buttons.

### 7. Bound the measurement and layout corrections

Exactly two app-owned TextPainters exist under lib. Both receive
MediaQuery.textScalerOf(context), Directionality.of(context) and
Localizations.maybeLocaleOf(context), using the same locale for their rendered
Text. Before measurement apply the same effective-style transformations as
Flutter 3.47.5 Text.build: FontWeight.bold when MediaQuery.boldTextOf(context)
is true, and the non-null values from
MediaQuery.maybeLineHeightScaleFactorOverrideOf,
MediaQuery.maybeLetterSpacingOverrideOf and
MediaQuery.maybeWordSpacingOverrideOf to height, letterSpacing and wordSpacing.
The height override replaces the ratio; do not multiply the previous height.
Copying omitted/null values preserves the baseline and SOFT. Leave rendered
Text to apply these ambient overrides normally; do not disable them. No shared
service or new public helper is necessary for two small call sites.
Text does not yet apply paragraphSpacingOverride (framework TODO), so do not
invent handling for it. Dispose temporary painters after reading their metrics.

- SnackBar: put measurement and the existing content row/column decision in
  a Builder inside SnackBar.content. Read typography/MediaQuery from that
  content context, so inherited changes while visible rebuild the measurement
  rather than leaving the call-site snapshot stale. Keep its explicit
  bodyMedium foreground style. Measure with the same two-line limit as content
  and use computed line count only for the existing placement heuristic.
  This fixes scaling/direction/locale and effective-style inputs;
  it does **not** establish exact horizontal layout parity. Existing measurement
  width ignores internal padding, icon and inline action, and the >40-character
  branch can omit an action for a single-line message. Those are separate
  SnackBar layout defects recorded below, not silently promised fixed here.
- Slideshow pause button: measure the existing single-line label with maxLines
  1 and no wrapping width. Use resolved labelLarge explicitly in both the
  painter and ButtonStyle.textStyle so a FilledButtonTheme override cannot
  change only the rendered label. Locale/scaling changes update the width
  through didChangeDependencies, including bold and spacing dependencies.
  Preserve animation and padding constants;
  finite viewport overflow at extreme scaling is a separate responsive-layout
  concern. Do not test private _calculateTextWidth directly.
- Suggestion carousel: use `0.45 * MediaQuery.sizeOf(context).height - 8.0`,
  retaining the existing section-bottom-spacing deduction, while removing
  the added TextStyle.height term and its 16-pixel fallback. The heading remains
  outside the viewport. This avoids the earlier .45H proposal's unrelated
  removal of the spacing deduction. With the actual resolved titleMedium
  height 1.5 the viewport decreases by 1.5 logical pixels. A custom fixture
  actually returning null height loses the 16-pixel fallback; ordinary
  MaterialApp fixtures are also localized and must not be assumed to return
  null. This removes an invalid adjustment without introducing a new
  measured-header sizing model.

## Testing Strategy

Manual implementation adds `test/ui/core/themes/app_typography_test.dart`,
matching existing test/ui/core/themes conventions. Use material_ui MaterialApp
and Builder with real AppThemeData.light/dark, plus photoViewer. Compare
resolved role properties to framework typography rather than copying all
baseline numbers. Separately assert raw appTextTheme has exactly seven partial
roles and no geometry/weight/color overrides; raw and runtime expectations must
not be conflated.

Cover all fifteen emphasized weights and the two tracking overrides; equality
of unrelated public style properties; SOFT preservation; absence of wght;
semantic colors/decorations; and recomputation after theme changes.
Use Italian/English for application coverage, and a **test-only Japanese locale**
with the existing material_ui localization delegate to exercise dense script
category. Assert ideographic versus alphabetic textBaseline survives into
emphasized. Neither adding an app locale nor font-glyph coverage for Japanese
is required. Default M3 script sizes happen to match: comparing only sizes
would not prove localization. A custom resolved style fixture can prove
locale/fallback/decoration/feature preservation via the public facade.

Extend, rather than replace, existing tests:

- `test/ui/core/ui/custom_snack_bar_test.dart`: scaled content and line/action
  heuristic with bounded pumps, LTR/RTL, boldText and spacing overrides, including
  inherited changes while visible; avoid an assertion of exact width parity.
- `test/ui/post/widgets/components/post_media_slideshow_test.dart`: use at
  least two media, the existing FakeCacheManager, controlled image-loading
  callbacks, and bounded pumps past expansion animation. Disable autoplay by
  public interaction; compare expanded widths at scaling 1 and 2 and ensure
  label width is accommodated, without waiting on a continuously running ticker.
  Include boldText and ambient letter/word/height spacing fixtures; test
  dependency changes after mount. Where metric differences matter, load the
  bundled Lexend using FontLoader rather than assume test-font weights differ.
  Compare public rendered paragraph metrics, not a private painter helper.
- `test/ui/weather/widgets/components/weather_forecast_hourly_list_test.dart`:
  resolved w300 with real app theme; retain existing forecast fixtures.
- `test/ui/content_submission/widgets/content_submission_date_chip_test.dart`:
  iOS compact popup, native local title properties, selection unchanged.
- `test/ui/explore/widgets/suggestion_horizontal_list_view_test.dart`: actual
  viewport formula with real app theme, multiple viewport sizes and text scales;
  changing typography height must not change carousel dimensions.
- existing `post_description_test.dart` and
  `content_submission_description_form_field_test.dart`: rendered combined
  inline formatting, list/link behavior and unchanged Markdown metrics.
- `events_calendar_test.dart`: preserve local weekday/month sources and colors.

Add one focused `test/ui/core/ui/app_navigation_rail_test.dart` for public
selected/unselected labels; existing routing tests do not verify typography.
Verify post headline style at the public header boundary in
`test/ui/post/widgets/components/post_section_header_test.dart`, reusing
existing content and weather fixtures; do not
assert only that the adapter is constructed. Keep unrelated bare ThemeData
harnesses and preview scaffolding unchanged; enable real app themes only where
these typography assertions require them. No production widget-preview system
was found. Use property/behavior tests, not goldens or wall-clock sleeps.

## Audit disposition and follow-ups

- SHOULD FIX IN THIS PLAN: stale baseline/package assumptions; omitted post
  styles; missing displayLarge emphasized tracking; redundant facade aliases;
  incorrect calendar-month provenance; pinned weights; Quill workaround;
  Cupertino context/title; scaler/direction/locale and effective-style omissions; invalid height
  arithmetic; localization and real-theme test gaps. Decisions above close them.
- NO ISSUE: seven-role Brand/Plain division matches primary tokens; partial
  ThemeData pattern and runtime localization boundary remain valid; flex color
  integration does not require a typography refactor; local Markdown metrics,
  deliberate weights and color-only DefaultTextStyle overrides need no cleanup.
- OUT OF SCOPE / FOLLOW-UP: SnackBar exact constraints/action-placement defects
  (including the dependency's own unscaled action TextPainter); CustomRichText
  noScaling on the outer WidgetSpan wrapper (nested Text widgets still inherit
  their own scaling, so do not describe it as uniformly disabling every label);
  submission terms RichText/WidgetSpan scaling behavior; extreme-scale clipping
  in fixed-height picker/slideshow surfaces; registering a real italic font.
  These require separate behavior/layout review rather than token centralization.
- BLOCKER: none after this rebase. No unresolved product decision is required
  to implement the declared contract. If declared visual changes are rejected,
  revise the plan before implementation instead of silently compensating locally.

## Migration Plan and Risks / Trade-offs

Implement in order: baseline ownership; tested runtime facade; all semantic
consumers and selective emphasis; Quill/native title; bounded measurement and
height corrections; focused/full verification and manual visual checks.

New brand metrics can alter wrapping -> inspect actual weather, progress,
post, picker/dialog and photo-viewer surfaces in light/dark on Android/iOS.
Temporary emphasis values can evolve -> keep one private adapter with a pinned
primary source and public role contract. Runtime allocations -> derive only
when requested; optimize only with evidence. Existing layout defects remain ->
record the follow-ups and do not claim general accessibility/layout readiness.

Rollback is the implementation's focused code/test diff; no database or asset
migration is involved. Archive/sync is a separate action after implementation.
