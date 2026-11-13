# Design

## Context

At the inspected baseline (`main` = `886556409ef8e7254e8c241a77d643c5e9403fd1`), Admin and Public Content Submission share `ContentSubmissionFileThumbnail`: an 86×86 logical slot using `ResizeImagePolicy.fit` and `BoxFit.cover`. See proposal.md for the resulting undersampling defect.

There are five bounded `AppNetworkImage` call sites: content grid card, content list item, explore suggestions, post slideshow and admin associated media. They use cover. One full-resolution gallery call site uses contain for zoom/pan. `imageWidth/imageHeight` are supplied but unused. Flutter 3.47.5 and the locked `cached_network_image_ce` 4.13.1 are the compatibility baseline; no dependency update is part of this change. The app leaves the network provider's animation setting at its existing default, which is enabled.

`AppNetworkImage.fullResolution` currently bypasses the usual error/loading builders. Local thumbnails have no error builder. `EmptyView` uses a centered Column, 16 px outer padding, 16/16/16/8 icon padding and a default 40 px icon. It also serves spacious loading/error/action states and unbounded-height sliver hosts.

The supplied audits establish useful source/decode evidence, not device performance acceptance. Repository sources and applicable AGENTS.md, Flutter UI, async safety and logging/privacy contracts remain authoritative.

## Goals / Non-Goals

**Goals**
- Correct proportional cover decoding against local physical thumbnail targets and network bucket targets, within intrinsic source resolution.
- Share one cover-only wrapper without changing acquisition, cache ownership or staging lifecycle.
- Preserve network bucket limits, full-resolution gallery behavior, existing animation behavior and loading fade.
- Provide neutral accessible failure feedback and useful privacy-safe diagnostics; preserve admin path-resolution retry.
- Adapt existing EmptyView constructors to actual constraints while preserving spacious layouts and usable actions.
- Establish reproducible decode/memory comparisons and device acceptance without promising constant memory independent of aspect ratio.

**Non-goals**
- Metadata-only reads, new caches, staging copies, server transforms, URL variants, dependencies or dependency/SDK upgrades.
- A configurable decode-policy wrapper, strategy hierarchy, extra provider subclasses for non-cover fits, request coalescing or network infrastructure.
- Changes to staging/upload, domain metadata, persistence, gallery navigation, theme, animation policy or fade design.
- Compact constructors/flags, a responsive framework, per-corrupt-image retry, new logging services or remote event families.

## Decisions

### 1. One cover-specific provider

Use one small delegating `ImageProvider` shared by local thumbnails and bounded network cover images. Flutter's stock `ResizeImage` exposes fit/exact sizing but no equivalent intrinsic-aware cover policy; delegating its decoder callback avoids a separate metadata read or reimplementation of HTTP/file codecs.

The pure sizing rule uses actual decoder-reported intrinsic dimensions, including orientation as exposed by the codec:

`scale = min(1, max(targetWidth / intrinsicWidth, targetHeight / intrinsicHeight))`.

Request approximately `ceil(intrinsicWidth * scale)` × `ceil(intrinsicHeight * scale)`, capped to intrinsic dimensions. Define positive-size guards and codec rounding tolerance against the actual SDK; avoid systematic target-axis undersampling where source resolution permits. Do not derive decode decisions from database dimensions or request manufactured source detail.

Delegate `loadImage` to `FileImage` or `CachedNetworkImageProvider`, forwarding a cover-aware `getTargetSize`. Preserve synchronous `obtainKey` resolution and normal error propagation. Use a distinct immutable cover-key type containing the resolved inner source key and requested target dimensions. Equivalent cover requests reuse that key; stock `ResizeImage` keys must never collide with it. Error eviction must address the outer cover key as well as preserve underlying provider behavior. Use ephemeral error handling rather than a retained listener that keeps an unused stream alive. Avoid descriptors retained beyond codec ownership or new asynchronous thumbnail state.

Keep the wrapper exclusively cover-specific: no policy property or non-cover strategy. For contain/scaleDown retain stock `ResizeImage(policy: ResizeImagePolicy.fit)` where compatible. Other fits keep their existing Flutter path and geometry, without expanding the wrapper or claiming that this change fixes every pre-existing fit limitation. Verify cover→contain, contain→cover and repeated equivalent requests using actual decoded results, not just runtime types.

### 2. Targets, identity and compatibility

Local thumbnails use `ceil(86 * DPR)` on both axes and continue painting with cover. Bounded network images keep `ImageSizeBucket.resolveAndClamp` on logical bounds and DPR. Their no-avoidable-underdecode guarantee is relative to the resulting bucket, capped at 1728 px per requested axis, not the unrestricted screen target. For example, 1000×1000 logical at DPR 2 requests a 1728×1728 bucket, so render-time upscale to 2000×2000 is accepted. This intentional cap differs from the fit/cover mismatch being fixed. A proportional decode may exceed 1728 on its uncropped axis; the cap bounds the requested rectangle, not every output dimension.

Keep five separate invariants:

| Boundary | Preserved contract |
| --- | --- |
| URL/cache key | Original URL and existing underlying cache-key configuration; no size-derived variants |
| Persistent disk cache | Same original entry; do not pass decode targets as disk-resize parameters or add persistent variants |
| Flutter ImageCache | Distinct entries for incompatible source/target/provider keys; equivalent retained requests reuse their decoded stream |
| Cache-manager activity | No unnecessary extra reads relative to the old pipeline under equivalent conditions; a retained decoded hit bypasses acquisition |
| Actual HTTP requests | No unnecessary increase relative to the old pipeline with equivalent cache state and access pattern; no single-request promise for concurrent cold misses |

Different buckets can require separate decodes and manager reads while sharing disk identity. The real manager can issue multiple HTTP requests for concurrent cold reads of one URL and may refresh expired entries. Regression checks must measure manager reads and HTTP sends separately: same/different buckets, warm cache, concurrent cold cache and deterministic expiry where practical. Retain existing manager, cache limits and configuration; add no coalescing layer.

Full-resolution images keep their intrinsic decode and gallery contain/zoom/pan behavior. Preserve network provider animation configuration and multiframe completer behavior in both paths; a compatibility fixture checks that delegation does not freeze or break existing playback. Preserve the bounded loading fade, including synchronous-hit behavior, by default. Device checks look for regressions, not a fade optimization workstream or new configuration API.

Remove unused `imageWidth/imageHeight` from both AppNetworkImage constructors and all six call sites/tests. Retain domain, persistence and navigation dimensions. Document effective fit, bounds, DPR/buckets, cache, loading/error and animation compatibility contracts.

### 3. Failure feedback, diagnostics and loading callbacks

Use the existing EmptyView with `Symbols.broken_image` and neutral feedback such as "Immagine non disponibile" for local missing/empty/corrupt/unreadable files and remote timeout/HTTP/decode failures, including full-resolution gallery. Keep clipping and slot geometry; ensure gallery feedback remains visible against its background. Add no per-image corrupt-media retry. The existing admin staged-path resolution retry remains unchanged and separate.

Separate presentation, local Debug diagnostics and approved remote telemetry. For network errors retain `ImageLoadFailed`, original error/stack and AppLogger's existing bounded projection. For resolved local-file decode/read failures, reuse that typed logging boundary with a fixed non-sensitive source label rather than a private path in the event's URL field; retain the original cause/stack for Debug inspection. Do not pre-render exception messages. The existing event has no application exception capture and its remote projection excludes raw URL/message/stack; keep that policy, consent and terminal-owner rules unchanged. This preserves useful local evidence when errorBuilder consumes the framework error without adding a logger or remote event family. Suppress repeated diagnostics caused only by rebuilds of the same failure locally, without global deduplication or concealing a genuinely new failure.

Both constructors' `onImageLoading` must let consumers leave loading on success or failure, avoid unnecessary repeated notifications from frame/build activity, and reject obsolete-source completions. Use the smallest local lifecycle bookkeeping needed by actual consumers; do not impose an extra state machine or a universal callback sequence. Test synchronous hits, pending success/error, rebuilds, replacement, disposal and slideshow autoplay admission. Preserve existing consumer behavior rather than relying on repeated frame notifications to repair it.

### 4. Adaptive EmptyView with unchanged API

Keep EmptyView, EmptyView.error and EmptyView.loading signatures, default typography/icon and spacious composition. Base adaptation on allocated constraints, using LayoutBuilder or equally simple composition. A constraint reader alone does not prove arbitrary child content fits.

For compact noninteractive image errors, reduce decorative padding/spacing and icon size first. At 32×32, 48×48, 72×72 and 86×86 logical pixels, require a visibly nonzero, unclipped meaningful icon and no overflow. Omit visible text only when necessary, retaining its meaning in accessible semantics without duplicate decorative announcements. Respect ambient text scaling when text is shown; no indiscriminate FittedBox or suppression of scaling.

The small square matrix does not apply to arbitrary actions. Test existing action-bearing consumers under their actual supported parent constraints, including short/narrow layouts, text scaling, keyboard/SafeArea and assistive technology. Preserve callbacks, focus and visible usable hit geometry. Where content exceeds finite space, a bounded scroll fallback may keep actions reachable; do not introduce nested unbounded viewports or unbounded flex under existing scroll/sliver hosts. A viewport smaller than a 48×48 target cannot expose that entire target simultaneously: do not claim otherwise, shrink it to fit, or accept a test based only on widget presence. Verify reachable/tappable geometry after scrolling where appropriate. Preserve existing loading and full-screen states wherever their normal content fits.

### 5. Verification and memory acceptance

Use real local/network-provider decodes for ratios 1:1, 4:3, 3:4, 4:1, 1:4 and an extreme panorama, small sources, non-square targets and DPR 1/2/2.625/3. Include EXIF orientation where feasible. Compare old fit, proposed cover and full-resolution dimensions using the same fixture and target. Deterministic acceptance requires proportional output within documented codec rounding, no requested dimensions above source, local coverage where source permits, and network coverage relative to the authorized bucket including its above-cap exception.

Record a reproducible table with fixture dimensions/format/orientation, slot, DPR, bucket, expected and observed decode dimensions, pixel counts and estimated buffer cost `decodedWidth * decodedHeight * bytesPerPixel`. State the pixel-format assumption (for example 4 bytes for RGBA8888); this is a buffer estimate, not total decoder/native/GPU/cache/process memory. Cover can cost substantially more than fit because it retains pixels later cropped. Memory proportionality depends on destination geometry and source/target aspect-ratio mismatch, not compressed file bytes or slot area alone. Preserve existing cache limits and network buckets; add no new cap, fallback or transform.

Device-dependent acceptance compares the same fixtures, list/grid density and scrolling interaction on representative supported hardware, recording device/build, memory pressure, scrolling/raster observations and residual risks. The expected sharper decode cost is not itself a regression failure; unexplained extra decoding/reads or observed memory-pressure/scroll failures require investigation before declaring the performance DoD complete. Unavailable devices, formats or observations remain explicit verification gaps, never invented passes. No universal memory budget or constant-memory claim is made.

Tasks assign decode/cache, local lifecycle, remote/gallery and EmptyView regressions to their respective groups. Integration acceptance additionally runs analyzer, relevant suite and CI, verifies both Notion DoDs and records the device comparison. Do not commit scratch logs, experimental harnesses or generated evidence clutter.

## Risks / Tradeoffs

- **Extreme aspect ratios** → quantify the intentional pixel increase and device impact; source and existing cache limits do not promise a universal slot-sized memory bound.
- **Provider lifecycle** → verify synchronous keys, policy separation, error eviction, listener release and late source changes against the locked dependency.
- **Shared EmptyView** → test actual visible/interactive geometry, semantics and unbounded hosts as well as spacious-layout equivalence.
- **Handled errors** → preserve original local diagnostics and the existing sanitized remote boundary without duplicate capture.
