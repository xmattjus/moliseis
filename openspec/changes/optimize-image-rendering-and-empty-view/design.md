# Design

## Context

At the inspected baseline (`main` = `886556409ef8e7254e8c241a77d643c5e9403fd1`), local staged photographs are displayed by `ContentSubmissionFileThumbnail` through `ResizeImage(FileImage(...), width, height, policy: fit)` and then `BoxFit.cover` in an 86×86 logical slot. Both public content submission and admin new-contribution paths reuse the same thumbnail widget.

`AppNetworkImage` similarly wraps `CachedNetworkImageProvider` with `ResizeImagePolicy.fit` for a bucketed physical-size target; all six bounded network consumers use cover, whereas `.fullResolution` is intended for gallery/zoom with `BoxFit.contain`. `imageWidth/imageHeight` are declared and supplied but unused. The project uses `cached_network_image_ce` 4.13.1 and `ImageSizeBucket`; the network provider fetches/caches the original URL and resized decodes are separate Flutter image-cache entries.

The provided independent audit (TASK-43 + TASK-16) reports real decode reproductions of undersampling and safe existing local staging/identity behavior, but no device profiling. Treat reported timings/sharpness as baseline comparison material, not unconditionally reproducible device measurements. Repository sources, actual SDK and dependent package implementations are authoritative when implementing.

`AppNetworkImage.fullResolution` currently returns a bare `Image` before its usual frame/error builders. Local thumbnail rendering has no error builder. `EmptyView` is a general reusable centered Column with 16 px outer padding, 16/16/16/8 icon padding and default icon size 40; that composition does not fit some image slots. It is used for normal empty, loading, errors and actions elsewhere: this change must not redesign those screens.

Applicable repo rules: root `AGENTS.md`, Flutter UI engineering and async safety skills, OpenSpec conventions and logging/privacy contracts. A single shared `ImageProvider` wrapper and removal of unused image size API parameters have explicit user authorization.

## Goals / Non-Goals

**Goals**
- Preserve intrinsic image aspect ratio while decoding enough pixels to draw cover-cropped images without avoidable upscale, within source resolution.
- Reuse one minimal, testable sizing rule and provider wrapper across local and network images.
- Maintain network disk cache identity/traffic, useful existing size buckets, gallery full-resolution rendering and local staging/session ownership.
- Give local, remote and full-resolution image failures a visible, accessible `EmptyView` with `Symbols.broken_image`, without a per-corrupt-image retry.
- Make the *existing* `EmptyView` layout constraint-adaptive: unchanged spacious appearance when it fits, small noninteractive states never overflow, important actions remain usable.
- Document public image APIs and verify decoded images, cache semantics, loading/error paths, constrained accessibility and performance budgets.
- Preserve Molise Is's current static-only image contract: multi-frame network media must not play as animation.

**Non-goals**
- New server transforms, new URLs, disk caches, staging files, metadata I/O, providers at domain/data boundaries, image editing, new dependencies or Flutter upgrade.
- Rewrite staging integrity/reconciliation, upload, cloud storage, gallery navigation, app-wide loading, or theme design.
- Replace `EmptyView` with specialized image variants, add a `compact` flag/new constructor, or hide interactive actions to achieve compactness.
- Blanket logging changes; leave `ImageLoadFailed` policy and privacy boundary intact.
- Add animated-image playback support, playback controls or a new media-animation abstraction.

## Decisions

### 1. One narrow provider wrapper and sizing rule

Implement a pure `coverDecodeSize(intrinsicWidth, intrinsicHeight, targetPhysicalWidth, targetPhysicalHeight)` (name illustrative). It computes:

`scale = max(targetWidth / intrinsicWidth, targetHeight / intrinsicHeight)`.

If `scale >= 1`, decode no larger than source dimensions. Otherwise use a proportion-preserving size approximating `ceil(intrinsicWidth * scale)` × `ceil(intrinsicHeight * scale)`, capped to source dimensions and avoiding avoidable target-axis undersampling from integer rounding where possible. Explicitly define rounding, zero/invalid guard behavior and codec constraints based on the checked-out Flutter SDK. Use decoder-reported intrinsic dimensions, including EXIF orientation as provided by the codec; do not trust database width/height for decode decisions.

Use a small delegating `ImageProvider` wrapper (instead of reimplementing HTTP/file codecs). Delegate load, preserve compatible `obtainKey` behavior including synchronous resolution, use a distinct immutable key containing the inner key and bucketed requested physical dimensions, and forward a cover-aware `getTargetSize` to the decoder. Preserve error propagation and Flutter `ImageCache` eviction semantics; check relevant `loadImage`/codec signatures in Flutter 3.47.5 and `cached_network_image_ce` 4.13.1 before implementation. Avoid extra file reads, retained image descriptors, async state in thumbnails or a new cache layer. Do not assume a custom provider implementation is automatically robust: test cache equality, synchronous hits, errors/eviction, and actual decode outputs.

Resolve `cached_network_image_ce` from the current 4.13.1 lock to 4.13.2 within the existing dependency constraint before implementation. The patch fixes `DefaultCacheManager` initialization after an OS-cleared cache directory; inspect the resolved provider/cache implementation and keep this as a focused patch update rather than a broader dependency refresh.

Use the same pure rule for unit testing and both pipelines; keep provider-specific resource ownership in existing components. Do not alter the raw staged file, ownership digest or copy/cleanup contracts.

### 2. Bounded local thumbnails and network images

For `ContentSubmissionFileThumbnail`, request the 86×86 logical slot multiplied by DPR (rounded appropriately); paint with `BoxFit.cover` as before. Shared usage across admin and public is unchanged; no staging or upload modifications.

For `AppNetworkImage` bounded constructor, keep `ImageSizeBucket.resolveAndClamp`. Use the cover provider on cover-painted slots with bucketed target width/height. For `BoxFit.contain` or `scaleDown`, retain proportional contain-style decoding; for other supported fits, explicitly test or document a conservative no-underdecode policy rather than forcing an incorrect one. Preserve stable image-cache keys within the same bucket.

For `.fullResolution`, do not constrain decoding; keep zoom/pan suitability and source aspect ratio. Unify image loading/error presentation where needed without introducing a surprising full-screen layout change.

Remove `imageWidth/imageHeight` from both public constructors and all actual Flutter call sites/tests. Keep media/asset width and height in domain and persistence for their real uses; avoid unrelated model or schema changes.

Molise Is currently treats application images as static media. Configure `CachedNetworkImageProvider` with animation disabled so a multi-frame network image renders its first frame without continuing animation decode/playback. Preserve that setting as part of provider/cache identity and do not introduce animated-media support through this change. Local staged-photo handling remains static and gains no animated-media capability.

### 3. Image failure presentation and logging

On image decoding/read or network load failure (including `.fullResolution`), show `EmptyView` with `Symbols.broken_image` and concise, neutral description such as "Immagine non disponibile". A network timeout or missing file must not be reported to users as positively corrupt. Keep existing bounded image dimensions and clipping; the full-screen case must use available constraints and stay visible over the gallery background. No automatic per-image retry or retry action for a corrupt staged image. Preserve the existing admin staged-path *resolution* retry: it addresses a different boundary, and is not a retry of the image decoder.

Ensure `onImageLoading` is implemented for both `AppNetworkImage` constructors and represents semantic loading-state transitions rather than `frameBuilder`/rebuild notifications. Do not emit duplicate consecutive values solely because an image frame or parent build repeats; terminal success and terminal failure transition to `false`, and source replacement establishes the new source's state without allowing stale completions to notify consumers. Preserve existing typed logging (`ImageLoadFailed`) for network failures, with original error/stack retained for local debug handling and without new sensitive URL/path reporting to Sentry. Avoid emitting repeated logs for rebuilds of the same failed image if this can be addressed locally without additional architecture; do not add a new global logger or remote event family. Handle local errors without unhandled framework exceptions or leaking private staging paths.

Audit the current `AnimatedOpacity` loading fade, including its `Durations.extralong4` duration, on representative dense list/grid consumers. Synchronous/cache hits remain transition-free. For asynchronous loads, choose the simplest transition behavior that preserves acceptable feedback without introducing visible raster/scroll regressions; shortening or removing the fade for dense bounded images is allowed, while adding a new public animation-configuration API is out of scope unless implementation evidence demonstrates a concrete need.

### 4. Adaptive EmptyView, unchanged API

Keep all existing `EmptyView`, `EmptyView.error` and `EmptyView.loading` signatures and default icon/typography. Do not add a constructor, boolean compact flag, external size variant or image-only widget. Base adaptation on effective constraints (`LayoutBuilder` or equally simple constraint-aware composition), not the device/window class.

When existing outer/icon padding, a 40-pixel icon, text and action fit, preserve the established spacious layout and visual hierarchy. For *bounded compact space*, shrink discretionary padding/spacing and icon size first. For noninteractive image errors with very little space, render the meaningful icon alone, centered, with accessible error semantics even if the visible text is omitted. Do not render an illegibly scaled text or a tiny interactive control. Ensure textScaleFactor / MediaQuery.textScaler is respected when text is shown, and no `RenderFlex` overflow is produced for supported compact slot sizes (including 32, 48, 72 and 86 logical pixels).

Actions cannot be discarded simply to fit. Preserve focus, semantics and usable interactive targets: for constrained hosts containing actions, permit a bounded scrollable fallback or a similar simple solution that keeps actions reachable. Determine the finite-axis/unbounded-axis cases from actual call sites before choosing exact widget composition; avoid a `LayoutBuilder` branch that assumes finite height inside a `SliverToBoxAdapter` or scroll view. Scope adaptations to avoid unnecessary layout churn across full-sized existing screens. Do not hardcode image-specific thresholds in the general widget.

### 5. Test and verification strategy

Use real decodes (not only constructor/provider type assertions) to verify physical decode dimensions and cover crop for source ratios 1:1, 4:3, 3:4, 4:1, 1:4 and an extreme panoramic case; test source-smaller-than-target, EXIF orientation when feasible, DPR 1, 2, 2.625 and 3, and non-square rendered slots. Do not enforce an impossible no-upscale assertion when intrinsic source is smaller than the requested physical region. Verify that integer rounding cannot systematically undersample a target axis.

Check `ImageCache` key identity and error eviction, same-URL same-bucket reuse, different buckets producing separate in-memory entries, and unchanged `CacheManager` disk key/request behavior. Memory estimates must compare decoded-pixel counts (current vs corrected vs full-resolution) with explicit source and DPR, rather than asserting that total process RSS drops; sharper cover decodes intentionally use more decoded pixels. Review scrolling fluidity on a real device if available and do not invent measurements.

Exercise local missing/corrupt/empty file paths and remote load failures, including gallery. Assert visible error with `Symbols.broken_image`, no raw exception surfaced, no unwarranted retry, edge-triggered loading callback sequences without consecutive duplicates, terminal `false` on success/failure, no stale-source callback, no duplicate failure logging on repeated build, and no private path/full URL in privacy-sensitive telemetry. Add a multi-frame network fixture proving the static-only contract: the first frame may render, but later animation frames are not decoded/played. Preserve admin owner/activation and path-resolution behavior.

Cover `EmptyView` at 32×32, 48×48, 72×72, 86×86, representative large views and bounded narrow/short layouts, with/without icon/text/action, with text scaling, keyboard/SafeArea where relevant, and with unbounded scroll/sliver constraints. Assert no overflow, correct semantics for icon-only presentation, preservation of action focus/reachability, and unchanged appearance when space allows.

Run focused tests, analyzer, then full relevant automated suite and GitHub CI. Complete a targeted manual device pass on real camera photos, HEIC/HEIF where supported, gallery/error states and long image lists/grids, noting unresolved platforms. Include the current-vs-chosen `AnimatedOpacity` behavior in the dense list/grid device pass and record observed scroll/raster behavior without inventing performance gains. No incidental snapshots, scratchpad logs or experimental binaries in Git commits.

## Risks / Tradeoffs

- **Cache/memory:** cover correctness increases decoded pixels, sometimes substantially for extreme aspect ratios; keep bounded by source resolution and image-cache policy, verify actual memory/scroll behavior. Do not silently reduce sharpness to regain memory.
- **Provider compatibility:** Flutter provider key/error/loading semantics are subtle; no broad provider hierarchy, and deterministic provider tests are required.
- **EmptyView scope:** its reused layout includes full-screen actionable error and loading states; compact adaptations must not regress those and must not hide required actions.
- **Error telemetry:** handling image exceptions prevents default framework error bubbling; retain useful typed logs within the approved reporting boundary without exposing sensitive paths or entire URLs.

## Open Questions

No outstanding authorization is required for the shared provider or the responsive existing widget: both were explicitly chosen. Implementation must verify Flutter 3.47.5 codec/delegation API details and establish a simple bounded action fallback for `EmptyView` from real constraints. Manual device performance/HEIC verification remains a merge-readiness check; no unproven device measurements are treated as baseline facts.
