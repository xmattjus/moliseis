# Proposal

## Why

The current image presentation uses `ResizeImagePolicy.fit` to decode within a rectangular target and then paints the decoded image with `BoxFit.cover`. For nonmatching aspect ratios this can decode too few pixels along the cropped axis and upscale the result. A supplied independent audit at `main` commit `886556409ef8e7254e8c241a77d643c5e9403fd1` reports reproduced undersampling for both locally staged previews and the shared network image widget. Existing tests mainly assert provider configuration rather than the actual decoded result.

A second defect affects failure presentation: local staged thumbnails do not show a stable error state, and `AppNetworkImage.fullResolution` bypasses the normal image loading/error builders. The reusable `EmptyView` assumes generous constraints and its padding, icon and column layout can overflow inside small image slots. Compact image errors need an explicit description owned by their caller: arbitrary widget-valued text cannot be removed while implicitly preserving its semantic string. A separate existing action-bearing consumer also overflows its finite-height slot at enlarged text, justifying focused shared vertical reachability without an image-specific EmptyView API.

This change combines two existing Notion work items into one coherent implementation:
- TASK-43 — Local staged image preview rendering and performance
- TASK-16 — Audit and optimization of AppNetworkImage

The original unbounded cover rule is also insufficient. Real Android decoding independently clamped an oversized axis and changed the source aspect ratio; released panorama working sets caused repeated decoding. The revised policy caps the proportional decode-size request at 1728 pixels per axis, separately from the unchanged requested bucket; actual multiframe output retains the existing codec limitation described in design.md section 2. Slideshow callbacks also require page ownership: a source-local bool alone cannot identify the page authorized to control autoplay.

## What Changes

- Introduce one minimal cover-specific image-provider wrapper and pure sizing calculation shared by local staged previews and bounded remote images painted with `BoxFit.cover`. Local targets use physical thumbnail dimensions; remote targets use the existing buckets capped at 1728 px per axis. Use one common scale capped by intrinsic resolution and a 1728-pixel requested-output dimension. Preserve source proportions; full cover is required only when source and output bound permit it. Upscale caused by that explicit exception and by the existing network bucket clamp is accepted. Retain stock Flutter decoding for non-cover fits, with distinct cache identities.
- Preserve the existing network size buckets and full-resolution gallery behavior. Remove the unused `imageWidth` / `imageHeight` arguments from both `AppNetworkImage` constructors and migrate their real call sites; retain domain media dimensions.
- Provide a narrow noninteractive image-error composition using Material Symbols `broken_image`, an explicit caller-owned accessible description and the existing `EmptyView` when its normal composition fits, for local and network failures including the full-resolution gallery. Keep the existing admin staged-file **path-resolution retry** but add no per-image retry for corrupted media.
- Keep `EmptyView` constructors and widget-valued content unchanged. Add only shared finite-height vertical reachability for existing content/actions, preserving spacious layouts and unbounded sliver hosts. Compact icon/text selection belongs to the known-label image-error composition; do not infer semantic strings or omit arbitrary shared content.
- Preserve and document URL/disk identity, decoded-image reuse and read/download behavior relative to the existing implementation under equivalent cache conditions; do not promise single-request coalescing. Preserve staging/upload, animation behavior and loading fade. AppNetworkImage owns current-request loading; PostMediaSlideshow owns active-page readiness, obsolete publication rejection and autoplay admission without relying on repeated frame notifications.
- Replace configuration-only tests with real decoded-size/rendering regressions. Compare fit, cover and full-resolution pixel-buffer costs, including aspect-ratio mismatch, and verify memory pressure and scrolling on representative devices. Cover may use more decoded memory; no universal memory bound is claimed. Retain useful local diagnostics through the existing logger and approved remote privacy policy.

## Capabilities

### New Capabilities

- `image-presentation`: Local and network decoding, cache identity, visible failure feedback, API contracts and related performance/lifecycle expectations.
- `empty-view-presentation`: Constraint-adaptive `EmptyView` behavior with unchanged established layout, semantics and action access.

### Modified Capabilities

None in canonical specs. The stale decode wording in the still-active `redesign-admin-submission-editor` delta is corrected at its source to reference `image-presentation`; its staged-resolution lifecycle remains unchanged. That scenario is not yet canonical, so this change adds no duplicate MODIFIED requirement. Neither synchronization order introduces a second sizing policy. Staging, upload, moderation, routing and data-domain contracts remain unchanged.

## Impact

The 1728 requested-output bound is an application quality/resource policy derived from the existing largest requested bucket, not a universal GPU or process-memory guarantee. Backend compatibility and physical-device performance are separate verification categories. Physical Android Profile-mode acceptance remains required. Missing physical iOS performance measurements alone do not block implementation merge when all other applicable requirements pass; those results remain NOT VERIFIED. An iOS release with that gap requires explicit, recorded residual-risk acceptance by the release decision owner under design.md; merge approval is not release authorization.

Primary implementation surfaces: `lib/ui/core/ui/media/`, `lib/ui/core/ui/empty_view.dart`, `lib/ui/content_submission/widgets/content_submission_file_thumbnail.dart`, `lib/ui/core/ui/media/app_network_image.dart`, five bounded network-image call sites (including focused PostMediaSlideshow ownership) and one full-resolution gallery call site and their tests.

Explicitly authorized: one shared bounded-cover `ImageProvider` and sizing function with the fixed output ceiling, the known-label noninteractive image-error composition, focused shared EmptyView vertical reachability, local slideshow ownership correction and removal of unused image-dimension parameters. Explicitly rejected: a dedicated compact `EmptyView` constructor, a general media framework, new image caches, speculative copies or metadata reads, dependency upgrades, new dependencies, request coalescing, fade redesign, per-image retry of corrupted media, and a Flutter SDK upgrade solely for this change.

This is **planning only**. The supplied audit reported a green baseline analyzer and 278 related tests plus disposable decode experiments; those observations are external report evidence, not re-executed verification by this planning author. Implementation must establish its own tests, CI and device evidence, recording outstanding physical iOS verification separately under design.md rather than claiming performance completion. Task closure remains a separate authorized decision.
