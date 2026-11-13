# image-presentation Specification

## Purpose

Provide proportional local and remote image presentation with stable cache behavior, accessible failure feedback and verifiable rendering costs while preserving staging and gallery contracts.

## ADDED Requirements

### Requirement: Cover images decode proportionally for their physical rendering targets

Cover images SHALL preserve intrinsic proportions and avoid avoidable upscaling relative to their authorized decode target, subject to source resolution and codec rounding. Local thumbnails SHALL target their physical slot dimensions; bounded network images SHALL target existing clamped buckets. Requests SHALL NOT exceed intrinsic resolution.

#### Scenario: Non-square local photo in a square thumbnail

- **GIVEN** a valid staged local photo with a 4:3, 3:4, 4:1 or 1:4 aspect ratio
- **WHEN** the Admin or Public Content Submission form displays its 86×86 logical thumbnail at a supported device-pixel ratio
- **THEN** the image is decoded at an aspect-ratio-preserving size that covers the required physical rectangle where intrinsic source resolution permits
- **AND** painting with `BoxFit.cover` crops without stretching or avoidable upscaling
- **AND** neither form introduces an additional file copy, metadata-only read, persistent cache or independently owned asynchronous preview state

#### Scenario: Network destination exceeds the bucket cap

- **GIVEN** a 1000×1000 logical network slot at DPR 2 and a sufficiently large square source
- **WHEN** the existing bucket policy resolves the decode target
- **THEN** the requested target remains 1728×1728, and proportional cover decoding covers that bucket
- **AND** upscale to the 2000×2000 physical display is an accepted consequence of the existing clamp
- **AND** avoidable undersampling from fit decoding is corrected relative to the bucket without raising or removing the cap

#### Scenario: Small original photograph

- **GIVEN** the intrinsic image is smaller than the target along an axis
- **WHEN** its preview is decoded
- **THEN** the decoder does not request pixels above intrinsic source resolution to manufacture detail
- **AND** rendering remains proportional and displays the best available source without distortion

#### Scenario: Oriented photo and fractional DPR

- **GIVEN** an image whose actual codec intrinsic dimensions reflect orientation metadata, and a destination with fractional DPR or non-square geometry
- **WHEN** the cover decode size is determined
- **THEN** sizing uses the actual decoder-reported dimensions rather than unverified database metadata
- **AND** the result preserves orientation and source proportions within decoder rounding tolerances

### Requirement: ImageProvider reuse preserves framework cache and error contracts

The shared cover-specific provider SHALL preserve acquisition, decoding, key-resolution and error ownership. Its stable key SHALL distinguish source identity and requested target, reuse equivalent cover requests and remain distinct from incompatible stock-provider decodes. Synchronous key resolution, correct error eviction and fresh resolution after failure SHALL be preserved.

#### Scenario: Same source and requested bucket

- **GIVEN** the same local staged source or remote URL and same image decode target
- **WHEN** the consumer rebuilds with an equivalent provider
- **THEN** the image-cache identity is equal and a retained decoded image is reused without avoidable new file or network reads

#### Scenario: Source or size changes

- **WHEN** the content-addressed staged path or remote provider identity changes, or a network image moves into a different size bucket
- **THEN** the image-cache key changes appropriately and the corresponding content/size is decoded
- **AND** obsolete source completions do not replace the current displayed image

#### Scenario: Underlying decode fails

- **WHEN** the wrapped file or network decoder emits an error
- **THEN** the error reaches the image display's failure handling without an unhandled Flutter framework exception
- **AND** eviction addresses the failed cover key without leaving a permanently poisoned entry that blocks a future fresh resolution
- **AND** error handling does not retain an unused stream through an extra permanent listener

#### Scenario: Cover and contain use the same source and target

- **GIVEN** a non-square source whose cover and contain decoded dimensions differ for the same target
- **WHEN** cover is resolved before contain, and the reverse order is tested independently
- **THEN** each path receives its correct actual decoded result without reusing the incompatible result
- **AND** repeated equivalent cover requests reuse their retained cover entry, and repeated equivalent contain requests reuse their retained stock entry

#### Scenario: Existing multiframe behavior survives delegation

- **WHEN** an existing supported multiframe network fixture is displayed through bounded cover and full-resolution paths
- **THEN** provider configuration and playback behavior remain equivalent to the existing dependency behavior
- **AND** delegation does not freeze frames or introduce new playback functionality

### Requirement: Network image sizing preserves network and disk-cache behavior

Network decode sizing SHALL preserve original URL/cache-key and persistent disk identity, with separate in-memory identities for incompatible decodes. Cache-manager reads and HTTP requests SHALL NOT increase unnecessarily relative to the existing pipeline under equivalent conditions. Concurrent cold misses SHALL NOT imply a single HTTP request. Full-resolution gallery decoding SHALL remain unbucketed.

#### Scenario: Same remote URL displayed in multiple sizes

- **WHEN** the same remote URL is displayed in two network size buckets and later revisited in the first
- **THEN** the remote/disk identity remains the same original URL
- **AND** each physical decode target has its appropriate in-memory cache identity
- **AND** revisiting a still-cached target does not generate an unnecessary extra cache-manager read or network fetch

#### Scenario: Warm disk entry serves a new decode bucket

- **GIVEN** a valid warm original disk entry and a new decoded target not retained in ImageCache
- **WHEN** that target is resolved
- **THEN** a manager read and decode may occur while the original disk identity is reused
- **AND** manager reads and actual HTTP sends are measured separately against equivalent baseline conditions without new persistent resize variants

#### Scenario: Concurrent cold-cache resolutions

- **GIVEN** no disk entry and concurrent consumers of the same URL in the same or different buckets
- **WHEN** the images resolve
- **THEN** equivalent cover keys share their pending image stream, while different buckets may acquire and decode separately
- **AND** HTTP request counts are compared with the old pipeline under equivalent conditions rather than constrained to one request
- **AND** no request-coalescing layer, URL variant or replacement cache manager is introduced

#### Scenario: Expired original cache entry

- **GIVEN** a deterministically expired original entry where the test harness supports expiry
- **WHEN** a network image resolves
- **THEN** refresh behavior preserves the existing manager policy and original identity
- **AND** regression verification distinguishes manager activity from actual HTTP sends and records any untested expiry behavior

#### Scenario: Gallery shows full-resolution image

- **WHEN** a user opens an image in the zoomable gallery
- **THEN** the displayed image uses its full intrinsic resolution with `BoxFit.contain` in the current gallery path
- **AND** the display keeps its existing gallery navigation/zoom/pan behavior
- **AND** shared error/loading handling is available without replacing the full-resolution path with a thumbnail decode

#### Scenario: Bounded contain or unusual fit

- **WHEN** `AppNetworkImage` is configured with `BoxFit.contain`, `scaleDown` or another supported fit
- **THEN** contain/scaleDown retain appropriate stock Flutter proportional decoding outside the cover-specific wrapper
- **AND** other fits retain their existing Flutter behavior without expanding the custom abstraction
- **AND** changes preserve existing visual geometry, cache policy and intrinsic resolution limits

### Requirement: Image rendering costs have reproducible acceptance evidence

Image performance acceptance SHALL distinguish deterministic decode correctness from device-dependent memory and scrolling behavior. Comparisons SHALL account for source/target aspect-ratio mismatch and the increased pixel cost of cover. Existing cache limits and network buckets SHALL remain unchanged; no constant-memory guarantee independent of aspect ratio SHALL be claimed.

#### Scenario: Compare fit, cover and full-resolution costs

- **WHEN** typical square, portrait, landscape and extreme-ratio fixtures are verified
- **THEN** evidence records source geometry/format, target, DPR/bucket, expected and observed decoded dimensions for old fit, proposed cover and full-resolution paths
- **AND** estimated pixel-buffer cost uses decoded width × decoded height × bytes per pixel with its pixel-format assumption stated
- **AND** compressed file size and buffer estimates are not presented as total decoder, GPU, cache or process memory
- **AND** requests stay within intrinsic resolution and increased cover cost is explained without a new cap, fallback or transform

#### Scenario: Representative-device performance acceptance

- **WHEN** TASK-43 and TASK-16 performance completion is evaluated
- **THEN** the same representative fixtures, list/grid density and scrolling interaction are compared on identified real devices/builds
- **AND** memory pressure and scroll/raster observations, expected pixel-cost increases and residual risks are documented
- **AND** unexplained extra work or observed memory-pressure/scroll failures are investigated before declaring the performance DoD complete
- **AND** unavailable devices or unverified formats remain explicit gaps rather than claimed passes

### Requirement: Image loading callbacks report state transitions

`AppNetworkImage.onImageLoading` SHALL describe loading for the active source in both constructors. Success and failure SHALL leave consumers non-loading; rebuild/frame activity SHALL NOT cause unnecessary duplicate notifications, and obsolete-source completions SHALL NOT publish current loading state. Existing slideshow behavior SHALL remain correct.

#### Scenario: Parent rebuilds while loading state is unchanged

- **WHEN** an `AppNetworkImage` rebuilds repeatedly while the same source remains loading, loaded or failed
- **THEN** `onImageLoading` avoids unnecessary duplicate notifications for the unchanged state without imposing extra callback-state machinery unrelated to consumer needs

#### Scenario: Active source succeeds or fails

- **WHEN** the current image reaches terminal success or terminal failure
- **THEN** `onImageLoading` reports `false` for that source
- **AND** slideshow or other consumers are not left stuck in loading state

#### Scenario: Source changes while an earlier source is unresolved

- **WHEN** source A is replaced by source B before A completes
- **THEN** loading notifications reflect source B
- **AND** a late completion from A does not mutate or notify B's loading state

### Requirement: Local and remote image failures provide accessible empty states

Failed local image reads/decodes and remote image loads/decodes, including full-resolution gallery images, SHALL display a meaningful `EmptyView` containing a Material Symbols `broken_image` icon and an accessible neutral image-unavailable description. A corrupt file SHALL NOT present a per-image retry control; the existing admin staged-path resolution retry SHALL remain a separate, unchanged recovery action. The failure view SHALL obey the image slot's bounds without overflow.

#### Scenario: Local file is unreadable, absent, empty or corrupt

- **WHEN** the local thumbnail provider fails to read or decode a staged file
- **THEN** a bounded `EmptyView` with the broken-image symbol replaces the failed image, and error semantics remain available even if visible text cannot fit
- **AND** the original failure cause and available stack remain useful in local Debug diagnostics through the existing typed logger, without a private path in the event source label
- **AND** no raw staging path is rendered or forwarded to inappropriate remote telemetry
- **AND** no retry button is added for retrying the corrupt image decoder

#### Scenario: Remote image fails in list, card, slideshow or gallery

- **WHEN** a remote image fails to load or decode
- **THEN** the same neutral image-unavailable presentation is available in every `AppNetworkImage` constructor
- **AND** the existing typed image-failure diagnostic retains local cause/stack under the established logger policy without repeated rebuild noise
- **AND** approved remote telemetry excludes full URLs, private paths and raw URL-bearing messages/stacks, without a new capture owner or remote event family
- **AND** the error does not remain a blank/black image with no user feedback
- **AND** terminal failure does not leave a consumer's loading callback or slideshow behavior stuck in an incorrect loading state

#### Scenario: Admin cannot resolve a staged path

- **WHEN** the admin staged-file repository cannot resolve an available staged descriptor
- **THEN** the existing path-resolution placeholder and guarded `Riprova anteprima foto` action remain available
- **AND** this recovery is not confused with a retry of an already resolved but corrupt image

### Requirement: Network image API exposes only effective parameters

`AppNetworkImage` SHALL document its bounded and full-resolution constructors, fit, dimensions, cache, animation compatibility and loading semantics and SHALL NOT require unused source `imageWidth` or `imageHeight` arguments. Existing domain and persisted media metadata SHALL remain unchanged.

#### Scenario: All current consumers migrate to the effective API

- **WHEN** bounded cards/lists/carousel/slideshow/admin media and full-resolution gallery construct `AppNetworkImage`
- **THEN** they pass only functional parameters and compile without `imageWidth` or `imageHeight`
- **AND** the unchanged intrinsic metadata remains available to unrelated domain and navigation contracts
- **AND** the widget documentation describes the actual image-sizing, preserved animation behavior, loading, cache and error behavior
