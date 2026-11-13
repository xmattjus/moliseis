# Proposal

## Why

The current image presentation uses `ResizeImagePolicy.fit` to decode within a rectangular target and then paints the decoded image with `BoxFit.cover`. For nonmatching aspect ratios this can decode too few pixels along the cropped axis and upscale the result. A supplied independent audit at `main` commit `886556409ef8e7254e8c241a77d643c5e9403fd1` reports reproduced undersampling for both locally staged previews and the shared network image widget. Existing tests mainly assert provider configuration rather than the actual decoded result.

A second defect affects failure presentation: local staged thumbnails do not show a stable error state, and `AppNetworkImage.fullResolution` bypasses the normal image loading/error builders. The reusable `EmptyView` assumes generous constraints and its padding, icon and column layout can overflow inside small image slots. Its shared layout should accommodate small constraints without adding an image-specific constructor or changing its established presentation elsewhere.

This change combines two existing Notion work items into one coherent implementation:
- [TASK-43 — Local staged image preview rendering and performance](https://app.notion.com/p/4171b5e75aa78142a14cdda2cbedafdc)
- [TASK-16 — Audit and optimization of AppNetworkImage](https://app.notion.com/p/40d1b5e75aa780f7b38ceae75b53fa52)

## What Changes

- Introduce one authorized, narrowly scoped image-provider wrapper and pure cover-sizing calculation shared by local staged preview decoding and bounded remote-image decoding. Use actual decoder-reported intrinsic dimensions (including orientation) and the physical display target, without a separate metadata read or cache layer.
- Preserve the existing network size buckets and full-resolution gallery behavior. Remove the unused `imageWidth` / `imageHeight` arguments from both `AppNetworkImage` constructors and migrate their real call sites; retain domain media dimensions.
- Provide a visible `EmptyView` with Material Symbols `broken_image` for local-file and network decode/load failures, including the full-resolution gallery. Keep the existing admin staged-file **path-resolution retry** but add no per-image retry for corrupted media.
- Make `EmptyView` responsive within its **existing constructors and public API**, preserving the current spacious appearance wherever it fits. Adapt padding/spacing/icon/text to actual constraints, preserve meaningful accessibility semantics and interactive actions, and avoid overflow for small noninteractive image errors.
- Preserve and document existing cache, upload/staging, logging privacy and loading-callback contracts. Replace configuration-only tests with real decoded-size/rendering tests and cover failure, cache and constrained-layout regressions.

## Capabilities

### New Capabilities

- `image-presentation`: Local and network decoding, cache identity, visible failure feedback, API contracts and related performance/lifecycle expectations.
- `empty-view-presentation`: Constraint-adaptive `EmptyView` behavior with unchanged established layout, semantics and action access.

### Modified Capabilities

None. This change does not redefine existing staging, upload, moderation, routing or data-domain contracts.

## Impact

Primary implementation surfaces: `lib/ui/core/ui/media/`, `lib/ui/core/ui/empty_view.dart`, `lib/ui/content_submission/widgets/content_submission_file_thumbnail.dart`, `lib/ui/core/ui/media/app_network_image.dart`, six existing network-image call sites and their tests.

Explicitly authorized: a shared `ImageProvider` wrapper and removal of unused image-dimension parameters. Explicitly rejected: a dedicated compact `EmptyView` constructor, a general media framework, new image caches, speculative copies or metadata reads, extra dependencies, per-image retry of corrupted media, and a Flutter SDK upgrade solely for this change.

This is **planning only**. The supplied audit reported a green baseline analyzer and 278 related tests plus disposable decode experiments; those observations are external report evidence, not re-executed verification by this planning author. Implementation must establish its own tests, CI and device evidence before these Notion tasks can be closed.
