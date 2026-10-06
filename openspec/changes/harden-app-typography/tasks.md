## 0. Verify the manual implementation baseline

- [ ] 0.1 Record `git status --short`, `git rev-parse HEAD`, `git log -5 --oneline`
      and the live remote main revision. Compare to design.md's explicit local
      baseline and resolved versions; reconcile material drift before coding.
      Use the existing change, not `openspec new change`.
- [ ] 0.2 Record current searches for `FontVariation.weight`, `AppTextStyles`,
      `fontFamily: 'system'` and `TextPainter(` under lib. Confirm postName and
      postCityName are present and only two app TextPainters exist.
- [ ] 0.3 Run `flutter analyze` and the existing focused test files listed in
      design.md, recording results before changes. Distinguish pre-existing
      failures; do not fix unrelated behavior as part of this migration.

## 1. Establish the minimal baseline theme

- [ ] 1.1 Set Lexend default in BaseThemeData.get and AppThemeData.photoViewer;
      reduce appTextTheme to seven partial Fraunces/SOFT-50 brand roles. Remove
      all theme wght variations and the unsupported WONK speculation. Verify
      raw theme declarations contain no geometry, weight or color overrides.
- [ ] 1.2 Add `test/ui/core/themes/app_typography_test.dart` using material_ui
      MaterialApp/Builder and actual light/dark/photoViewer themes. Assert all
      role families, framework-supplied runtime geometry and no wght variation;
      keep raw partial-theme assertions distinct from resolved assertions.
      Verify titleSmall is Lexend and display/headlines are Fraunces.

## 2. Add and verify the runtime typography boundary

- [ ] 2.1 Add app_typography.dart and the existing context extension getter.
      Expose only emphasized, section and link; privately retain the resolved
      material_ui theme. Derive emphasized on access, so ordinary semantic
      reads do not build the scale. Verify consumers can use the public API
      without a second baseline accessor, cache or ThemeExtension.
- [ ] 2.2 Implement one private fifteen-role adapter using the weights in
      design Decision 4, displayLarge tracking 0 and bodyLarge tracking 0.15.
      Copy all other resolved properties, and add the pinned primary-source
      replacement-seam comment. Verify all fifteen roles against the table in
      app_typography_test, with property preservation and SOFT assertions.
- [ ] 2.3 Extend that public-boundary test to Italian/English and test-only
      Japanese/dense script with the existing localization delegate. Assert
      textBaseline localization is preserved, not only matching font sizes.
      Verify changed theme/scheme recomputes emphasis and semantic colors;
      cover custom fallback, locale, decoration and features through a resolved
      style fixture. Do not add Japanese to production supportedLocales.

## 3. Migrate the complete current helper surface

- [ ] 3.1 Replace subtitle/title/titleSmaller with context.textTheme
      bodyMedium/titleLarge/titleMedium; section/link with appTypography's
      corresponding semantic getters. Preserve Markdown link size/height
      overrides and consumer-local colors. Verify existing description,
      submission, map, settings and event tests retain behavior.
- [ ] 3.2 Replace PostSectionHeader postName with emphasized.headlineLarge and
      postCityName with baseline titleMedium. Add
      test/ui/post/widgets/components/post_section_header_test.dart using
      existing content/weather fixtures; verify
      Fraunces/w500/SOFT and Lexend/titleMedium without changing post layout.
- [ ] 3.3 Move calendar helpers privately into EventsVerticalCalendarMonth:
      weekday remains DatePickerTheme-derived; month remains titleMedium with
      its brightness color. Verify existing calendar tests plus focused public
      style assertions preserve both sources and colors.
- [ ] 3.4 Remove text_styles.dart, the empty app_text_styles_theme_extension.dart
      and its barrel export only after all nine helpers are migrated. Verify
      zero production references to both obsolete classes and rerun analysis.

## 4. Correct weight ownership and preserve content semantics

- [ ] 4.1 Use emphasized.labelMedium for selected rail text, and baseline
      labelMedium with explicit FontWeight.normal for unselected text. Keep
      current role size, colors and selection/routing logic. Add
      test/ui/core/ui/app_navigation_rail_test.dart asserting both public label
      styles; run existing routing regression tests.
- [ ] 4.2 Replace hourly-weather light wght with FontWeight.w300; verify its
      existing widget test with an app-theme fixture. Keep primary temperature
      displayMedium+w700 and other local bold overrides. Review the diff for
      unchanged weight intent outside the named migrations.
- [ ] 4.3 Remove Quill's empty variation-list workaround and update its
      documentation. Extend existing post_description and submission
      description-form-field tests for rendered bold+italic+underline/link
      combinations, list/paragraph behavior and preserved non-weight axes in
      a custom theme. Keep Markdown H1-H6 and link metrics unchanged. Verify
      zero `FontVariation.weight` or explicit wght entries in app typography.

## 5. Native title and bounded measurement/layout fixes

- [ ] 5.1 Resolve navTitleTextStyle with a Builder under the popup's local
      CupertinoTheme; remove Material/bold/'system' header styling. Extend
      content_submission_date_chip_test for the compact iOS date and time
      headers and unchanged selection. Verify no synthetic family remains.
- [ ] 5.2 Move SnackBar measurement and the existing content decision into a
      content Builder. Use its scaler/direction/locale, matching two-line limit
      and the effective bold/height/letter/word style overrides specified in
      design Decision 7; dispose the painter. Extend custom_snack_bar_test at
      scale 1/2, LTR/RTL, boldText and spacing overrides, including updates while
      visible, to verify the existing heuristic consumes current inputs. Record
      the exact-width/action-placement follow-ups; do not claim this task fixes
      those separate layout defects.
- [ ] 5.3 Supply the same scaler, direction, locale and single-line role to
      slideshow measurement/rendering. Set ButtonStyle.textStyle to resolved
      labelLarge and apply Text's ambient bold/spacing overrides to the measured
      style as in Decision 7; dispose the painter. Extend
      post_media_slideshow_test through public interactions with two media and
      controlled loading; use bounded animation pumps, not pumpAndSettle on
      active autoplay. Verify expanded width changes at elevated scaling and
      responds to changed dependencies, including boldText and spacing overrides,
      without private-method assertions. Load the bundled font with FontLoader
      where differing metrics are required rather than rely on the test font.
- [ ] 5.4 Remove only the invalid style-height/fallback addition from suggestion
      viewport sizing: keep `.45 * viewportHeight - sectionTextBottomPadding`
      with existing 8-pixel spacing. Extend suggestion_horizontal_list_view_test
      using real app theme at multiple viewports/scales; verify typography
      line-height changes no longer change carousel geometry and existing
      loading/content/navigation behavior remains.

## 6. Integration and manual visual gates

- [ ] 6.1 Format only changed Dart files; run all focused tests above, full
      `flutter test`, and `flutter analyze`. Record actual outcomes and explain
      unrelated baseline failures rather than treating them as new regressions.
- [ ] 6.2 Visually verify light/dark, Italian/English, Android/iOS, normal and
      elevated scaling. Inspect post headline/city, rail states, weather hourly
      and primary temperature, submission progress, native picker header,
      Material dialogs/date-time pickers, suggestion viewport and independent
      photoViewer. Confirm design.md's declared family/weight changes without
      compensating with an unrelated redesign.
- [ ] 6.3 Search lib for zero FontVariation.weight, explicit wght assignments,
      synthetic 'system', AppTextStyles and AppTextStylesThemeExtension.
      Verify preserved Markdown metrics, inline formatting and intentional
      AppBar branding, and no modifications to dependencies/backend/ObjectBox/
      generated files or unrelated accessibility behavior.
- [ ] 6.4 Run `openspec validate harden-app-typography --strict --no-interactive`,
      `git diff --check` and `git status --short`. Review implementation against
      all four artifacts, with unresolved regressions preventing completion.
      Keep archive/spec sync as a separate finalization action after acceptance.

## Definition of Done

The localized Material baseline owns geometry; the app owns Brand/Plain
families and SOFT only. The complete emphasized API uses the verified weights
and two tracking differences, without a duplicated public baseline or unused
semantic aliases. All current helpers, including post styles, are migrated;
content formatting, local weights and calendar provenance are preserved.
Native title and named measurement inputs are correct; suggestion sizing no
longer interprets TextStyle.height as pixels. Focused/full checks and visual
acceptance are recorded; relevant regressions are closed, and separate
SnackBar/accessibility follow-ups remain explicitly outside this contract.
