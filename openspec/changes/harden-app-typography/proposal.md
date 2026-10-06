## Why

Application typography currently pins variable-font weights independently of
`FontWeight`, mixes app semantic styles with simple Material aliases, and has
text measurements that ignore ambient scaling. The plan needs a minimal
runtime typography boundary that preserves Material localization and the
current post presentation while providing a verified Expressive emphasized
scale unavailable in the resolved dependencies.

## What Changes

- Configure Lexend as the default family in both normal app themes and the
  independent photo-viewer theme; keep a partial `appTextTheme` with Fraunces
  and `SOFT: 50` only for display, headline and titleLarge roles. Flutter owns
  baseline geometry, weights, tracking and colors.
- Use `FontWeight` for standard weights throughout app typography, including
  the hourly weather light weight and the newly added post-name medium weight.
- Introduce a context-derived `AppTypography` with only `emphasized`, `section`
  and `link`. Keep existing `context.textTheme` for baseline roles. Derive
  emphasized styles on demand from the localized theme, preserving unrelated
  properties and applying the verified weight and two tracking differences.
- Migrate all current `AppTextStyles` consumers, including `postName` and
  `postCityName`. Keep calendar presentation styles local and remove the empty
  text-style ThemeExtension scaffold.
- Use emphasized headlineLarge for the post name and emphasized labelMedium
  for the selected rail label. Preserve weather's local displayMedium bold
  weight and the rail's deliberate unselected normal weight.
- Remove Quill's weight-axis clearing workaround, use the actual local
  Cupertino title theme for the picker header, and align the two app-owned
  TextPainter call sites with ambient scaling, direction, locale and effective
  accessible bold/spacing styles.
- Remove the erroneous line-height-multiplier contribution from the suggestion
  carousel height while retaining its existing viewport fraction and spacing
  deduction.

Intentional visual differences are documented in design.md, including brand
fonts on previously unspecified roles, titleSmall becoming Lexend, and local
weight overrides finally becoming effective after removal of pinned `wght`.
Markdown metrics, content formatting, unrelated component weights, color-system
construction and navigation behavior remain outside the migration.

## Capabilities

### New Capabilities

- `app-typography`: localized application typography, brand/plain typefaces,
  complete Expressive emphasis, native picker titles and scaling-aware text
  measurements.

### Modified Capabilities

None. No canonical spec edit is required by this audit.

## Impact

Manual implementation affects the existing theme files and BuildContext
extensions; adds `lib/ui/core/themes/app_typography.dart`; migrates semantic
consumers under core UI, post, event, explore, settings, geo-map and content
submission; and corrects hourly weather, picker and text measurement seams.

The audit baseline is local `main` at
`e9f792d0e468a8ccb1f8609e3934a549d102f411`. GitHub `main` observed during the
2026-10-06 audit is `925baa74d8feaeaee6865043207646f4adf8d687`; the local
checkout is one commit ahead. This plan includes that local post-presentation
commit rather than presenting it as already published remote state.
Resolved dependencies are Flutter 3.47.5, material_ui 1.5.0,
flex_seed_scheme 5.0.1, cupertino_ui 1.1.1 and flutter_quill 11.6.0.

No dependency, backend, ObjectBox, generated-file or other OpenSpec change is
part of implementation. This audit edits planning artifacts only.
