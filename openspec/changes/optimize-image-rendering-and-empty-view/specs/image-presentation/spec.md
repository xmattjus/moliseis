# image-presentation Specification

## Purpose

Provide proportional local and remote image presentation with stable cache behavior, accessible failure feedback and verifiable rendering costs while preserving staging and gallery contracts.

## ADDED Requirements

### Requirement: Bounded cover decoding preserves proportions with an explicit output ceiling

Bounded cover SHALL use one proportional scale limited by intrinsic size, cover geometry and a 1728-pixel request ceiling. Requests SHALL be positive and respect those limits. Actual output SHALL preserve proportions within integer/codec tolerance on the declared backend envelope; sizing guarantees apply where codecs honor resizing. Full coverage SHALL be required only where source and ceiling permit it. Physical local targets and network bucket semantics SHALL remain unchanged.

#### Scenario: Positive bounded sizing

- **GIVEN** positive decoder-reported intrinsic dimensions and physical requested targets
- **WHEN** the cover size is calculated
- **THEN** scale is `min(1, max(targetWidth / intrinsicWidth, targetHeight / intrinsicHeight), 1728 / max(intrinsicWidth, intrinsicHeight))`
- **AND** both axes use that scale with ceil and final positive/intrinsic/1728 integer guards
- **AND** the output ceiling is a declared quality/resource policy, not a universal GPU or process-memory guarantee

#### Scenario: Non-square local photo in a square thumbnail

- **GIVEN** a valid staged local photo with a 4:3, 3:4, 4:1 or 1:4 aspect ratio
- **WHEN** the Admin or Public Content Submission form displays its 86×86 logical thumbnail at a supported device-pixel ratio
- **THEN** the image is decoded at an aspect-ratio-preserving size that covers the required physical rectangle where intrinsic resolution and the output ceiling permit
- **AND** painting with `BoxFit.cover` crops without stretching, with enlargement accepted only for the declared intrinsic/output-bound exceptions
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
- **AND** rendering remains proportional within integer/codec tolerance, using the detail permitted by source resolution and the output ceiling

#### Scenario: Oriented photo and fractional DPR

- **GIVEN** an image whose actual codec intrinsic dimensions reflect orientation metadata, and a destination with fractional DPR or non-square geometry
- **WHEN** the cover decode size is determined
- **THEN** sizing uses the actual decoder-reported dimensions rather than unverified database metadata
- **AND** the result preserves orientation and source proportions within decoder rounding tolerances

#### Scenario: Exceptional panorama output remains bounded and proportional

- **GIVEN** a single-frame 12000×1000 source or its transpose and an 864×864 physical requested target
- **WHEN** the bounded cover provider decodes it
- **THEN** the requested and observed output is 1728×144 or 144×1728 within documented one-pixel sizing/codec tolerance
- **AND** the short axis requires accepted 6× enlargement to fill the slot, without an independently clamped distorted aspect ratio
- **AND** at a 258-square local target the same bound explicitly permits 1728×144 instead of ideal 3096×258

#### Scenario: Output ceiling also affects a large ordinary source

- **GIVEN** a 4000×3000 source at a 1728-square requested bucket
- **WHEN** the output ceiling binds
- **THEN** output is 1728×1296, rather than ideal 2304×1728
- **AND** that declared enlargement is accepted, while an 864-square target still obtains uncapped ideal cover output 1152×864
- **AND** a sufficiently large square source still obtains the full 1728-square output

#### Scenario: Backend output-limit compatibility

- **GIVEN** a codec honoring target resizing and an identified backend supporting texture dimensions of at least 1728
- **WHEN** bounded cover fixtures cross the formerly oversized-output cases in both orientations
- **THEN** actual decoded output remains proportional within the documented integer/codec tolerance and does not exceed the output ceiling
- **AND** an observed 8192 limit is not treated as a portable guarantee or selected cap
- **AND** unverified lower-capability/legacy backends remain NOT VERIFIED until the supported-device contract is established, without silently changing platform filters or adding a capability-query system

### Requirement: ImageProvider reuse preserves framework cache and error contracts

The shared provider SHALL preserve acquisition, synchronous key resolution, key/decode error propagation and error ownership. Its immutable key SHALL distinguish source and requested target, reuse equivalent retained requests, and remain distinct from incompatible stock decodes. Failed outer entries SHALL be evicted so fresh resolution can recover.

#### Scenario: Key resolution fails

- **WHEN** an inner key fails synchronously or asynchronously
- **THEN** the failure propagates through the framework error path without a hanging future or poisoned cover key

#### Scenario: Different targets converge on the output ceiling

- **WHEN** different requested buckets produce equal bounded dimensions
- **THEN** their original requested-target outer keys remain distinct, sharing only existing URL/disk identity

#### Scenario: Same source and requested bucket

- **GIVEN** the same local staged source or remote URL and same image decode target
- **WHEN** the consumer rebuilds with an equivalent provider
- **THEN** the image-cache identity is equal and a retained decoded image is reused without avoidable new file or network reads

#### Scenario: Source or size changes

- **WHEN** the content-addressed staged path or remote provider identity changes, or a network image moves into a different size bucket
- **THEN** the image-cache key changes appropriately and the corresponding content/size is decoded
- **AND** obsolete source completions do not replace the current displayed image

#### Scenario: Released exceptional working set reuses retained decodes

- **GIVEN** a clean default Flutter ImageCache, no competing entries, and 1, 5, 10 or 20 distinct 12000×1000 image identities at one 864-square or 1728-square requested target
- **WHEN** each is resolved, all consumer listeners are released, and the identical source order is revisited
- **THEN** the bounded 1728×144 outputs remain retained and the revisit requires no new decode or unnecessary file/cache-manager read
- **AND** pending/live counts return to zero after release, separately from retained bytes/entries
- **AND** larger or mixed working sets may legitimately evict entries; retention is not claimed to bound all live/native/GPU/process memory

#### Scenario: Released ordinary photographs increase decoded-cache pressure

- **GIVEN** thirty distinct 4000×3000 image identities at an 864×864 target, identical access/revisit order and the same clean default cache configuration for old fit and bounded cover
- **WHEN** each cohort resolves, releases all consumer listeners and revisits those identities
- **THEN** evidence compares decoded dimensions, estimated decoded bytes, retained/live/pending entries and revisit decode counts
- **AND** acquisition measurements distinguish cache-manager reads from HTTP sends
- **AND** increased decoded-cache eviction is evaluated against improved quality and observed physical-device behavior, without requiring thirty retained images or unconditional fit/cover cache-hit parity

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
- **AND** evidence records bounded-cover requested dimensions separately from observed frame dimensions where supported
- **AND** existing multiframe codecs may bypass target resizing and exceed 1728 in observed output; this is a codec/backend limitation, not a different application sizing policy or a process-memory guarantee
- **AND** delegation does not freeze frames or introduce new playback functionality, manual animated-frame resizing or fallback transformations

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
- **THEN** the gallery keeps its original unresized provider request, with actual intrinsic output subject to existing codec/backend limits and `BoxFit.contain`
- **AND** the bounded-cover provider/output ceiling is not applied to this path
- **AND** the display keeps its existing gallery navigation/zoom/pan behavior
- **AND** shared error/loading handling is available without replacing the full-resolution path with a thumbnail decode

#### Scenario: Bounded contain or unusual fit

- **WHEN** `AppNetworkImage` is configured with `BoxFit.contain`, `scaleDown` or another supported fit
- **THEN** contain/scaleDown retain appropriate stock Flutter proportional decoding outside the cover-specific wrapper
- **AND** other fits retain their existing Flutter behavior without expanding the custom abstraction
- **AND** changes preserve existing visual geometry, cache policy and intrinsic resolution limits

### Requirement: Image rendering costs have reproducible acceptance evidence

Image performance acceptance SHALL distinguish deterministic decode correctness from device-dependent memory and scrolling behavior. Comparisons SHALL account for source/target aspect-ratio mismatch, the selected output ceiling and the remaining pixel cost of cover. A per-image output-pixel bound SHALL NOT be presented as a total process/live-memory bound. Existing cache limits and network buckets SHALL remain unchanged; no constant-memory guarantee independent of aspect ratio SHALL be claimed.

#### Scenario: Compare fit, cover and full-resolution costs

- **WHEN** typical square, portrait, landscape and extreme-ratio fixtures are verified
- **THEN** evidence records source geometry/format, target, DPR/bucket, expected and observed decoded dimensions for old fit, proposed cover and full-resolution paths
- **AND** estimated pixel-buffer cost uses decoded width × decoded height × bytes per pixel with its pixel-format assumption stated
- **AND** compressed file size and buffer estimates are not presented as total decoder, GPU, cache or process memory
- **AND** all requests stay within intrinsic resolution; only bounded-cover requests use the selected 1728 output ceiling, explaining ordinary cover gains and bounded-quality exceptions without new transforms or cache tuning

#### Scenario: Representative-device performance acceptance

- **WHEN** TASK-43 and TASK-16 performance completion is evaluated
- **THEN** a focused Profile-mode comparison remains required on identified representative physical Android hardware/builds using ordinary/extreme fixtures, the same list/grid density and scrolling interaction
- **AND** equivalent physical iOS Profile-mode validation, including memory pressure and scrolling/raster behavior, is required when suitable hardware becomes available; until then those iOS results remain NOT VERIFIED
- **AND** memory pressure and scroll/raster observations, expected pixel-cost increases and residual risks are documented
- **AND** unexplained extra work or observed memory-pressure/scroll failures are investigated before declaring the performance DoD complete
- **AND** unavailable devices/backends or unverified formats remain explicit NOT VERIFIED gaps rather than claimed passes
- **AND** focused implementation verification does not require duplicating the entire earlier benchmark campaign

#### Scenario: Deterministic correctness and iOS compatibility evidence

- **WHEN** implementation verification is evaluated
- **THEN** applicable automated decoded-dimension/proportion, cache identity/reuse, provider/slideshow lifecycle/ownership/stale-callback/disposal, error/accessibility and acquisition/loading/rendering/gallery regressions remain mandatory
- **AND** iOS compilation and simulator functional checks provide additional compatibility evidence where supported by the available toolchain
- **AND** simulator success does not demonstrate physical-device memory or GPU performance; emulator, simulator, Android and estimated-buffer results do not substitute for physical iOS observations

#### Scenario: Implementation merge with unavailable physical iOS measurements

- **GIVEN** physical iOS performance results remain NOT VERIFIED
- **WHEN** all other applicable verification requirements have been satisfied
- **THEN** that absence alone SHALL NOT automatically block the future implementation PR merge
- **AND** NOT VERIFIED is neither PASSED nor automatically ACCEPTED; physical follow-up remains outstanding and merge approval is not iOS release authorization
- **AND** physical Android and all other applicable gates remain mandatory; demonstrated material regressions can still block implementation merge or release

#### Scenario: iOS release with outstanding physical-device verification

- **GIVEN** physical iOS performance verification remains unresolved
- **WHEN** an iOS release is considered
- **THEN** release SHALL require an explicit, recorded residual-risk decision by the release decision owner identifying unavailable verification, alternative evidence and its limits, possible memory/performance consequences, who accepts the risk and outstanding physical-device follow-up
- **AND** risk acceptance does not mark missing measurements PASSED or remove follow-up, and no acceptance is inferred from implementation merge approval

### Requirement: Image loading callbacks report state transitions

AppNetworkImage.onImageLoading SHALL report current-effective-request loading in both constructors. Success and failure SHALL settle non-loading. Obsolete request events and unchanged frame/build notifications SHALL NOT republish current loading. PostMediaSlideshow SHALL own active-page admission independently of repeated child notifications.

#### Scenario: Parent rebuilds while loading state is unchanged

- **WHEN** an `AppNetworkImage` rebuilds repeatedly while the same effective request remains loading, loaded or failed
- **THEN** `onImageLoading` avoids unnecessary duplicate notifications for the unchanged state without imposing extra callback-state machinery unrelated to consumer needs

#### Scenario: Active source succeeds or fails

- **WHEN** the current effective image request reaches terminal success or terminal failure
- **THEN** `onImageLoading` reports `false` for that request
- **AND** slideshow or other consumers are not left stuck in loading state

#### Scenario: Effective request changes while an earlier request is unresolved

- **WHEN** request A is replaced by B before A completes, including source/provider, same-URL target/fit or full-resolution path changes
- **THEN** loading notifications reflect request B, whose pending state cannot inherit A’s terminal readiness even when the media identity is unchanged
- **AND** a late completion from A does not mutate or notify B's loading state

### Requirement: Slideshow page ownership controls loading and autoplay

PostMediaSlideshow SHALL retain readiness only for valid page owners and their effective child requests; only the active owner/request SHALL control loading, pause controls and autoplay. Slot identity SHALL NOT imply request continuity. The callback SHALL remain bool-valued. Obsolete publications SHALL be rejected at entry and after deferral; mounted alone SHALL NOT establish ownership. Source loading and page ownership SHALL remain separate.

#### Scenario: Offscreen image settles before the active pending page

- **GIVEN** B is actually built during a transition, without assuming PageView prefetch
- **WHEN** offscreen B succeeds or fails while visible active A remains pending
- **THEN** B updates only its own readiness and cannot enable or disable A's controls or ticker
- **AND** selecting already-settled B admits it without requiring another image transition callback only while B’s current child/request readiness remains valid
- **AND** a late A event after selecting pending B cannot admit B

#### Scenario: Delayed events and unchanged rebuilds

- **WHEN** multiple callbacks queue in a frame, a page changes, or an unrelated parent rebuild occurs
- **THEN** deferred UI publication reflects the latest valid active-owner state rather than a captured stale bool
- **AND** an unknown/pending current page cannot start autoplay even when child notifications are deduplicated
- **AND** terminal success or handled failure settles that owner's loading and allows existing controls/autoplay when all other gates permit

#### Scenario: Media owners are replaced or reordered

- **WHEN** an index changes media identity, the list reorders/shrinks/becomes empty, or an ordered identity changes through in-place list mutation
- **THEN** replaced/removed owner handles and their callbacks lose publication authority, including A→C→A list replacement
- **AND** unchanged slots preserve readiness without callback replay when their effective child requests remain valid, such as ready A in [A,B]→[A,C]
- **AND** child identity is bound to its valid owner and controller/active indices remain valid
- **AND** readiness is scoped/pruned to current slots, not a new media cache or application state layer

#### Scenario: Remounted page starts a fresh request after failure or eviction

- **GIVEN** image B has failed or its decoded entry has been evicted after settling
- **WHEN** navigation away unmounts B’s page child and returning to the same media slot initiates a fresh pending image request
- **THEN** B’s obsolete terminal readiness cannot enable pause controls or activate autoplay while that request is pending
- **AND** success or handled failure of the current request settles readiness and permits normal admission under the existing gates
- **AND** obsolete child/request events cannot settle the replacement request
- **AND** an immediately available cached image remains admissible without redundant callbacks; unchanged rebuilds retaining the effective request preserve valid readiness

#### Scenario: Visibility, user intent and resource lifetime

- **WHEN** visibility changes without a parent rebuild, the notifier is replaced, media count crosses zero/one/many, or the widget is disposed
- **THEN** autoplay admission requires a mounted, visible, enabled slideshow with multiple media and a settled valid current owner
- **AND** manual pause/user-scroll intent and existing gallery pause/return behavior remain respected
- **AND** visibility listeners are rebound/released and the ticker is initialized/disposed by State lifetime, without late callbacks touching disposed resources

#### Scenario: Gallery future owns an autoplay pause

- **GIVEN** scroll visibility remains true while the existing gallery route Future is pending
- **WHEN** the current image completes or the parent rebuilds during that pause
- **THEN** the slideshow ticker remains stopped independently of image readiness and scroll visibility
- **AND** repeated opens do not create competing owners for the local suspension
- **AND** return releases suspension and rechecks current owner/readiness, visibility and user intent; obsolete or disposed state cannot restart autoplay
- **AND** route failures retain their existing exception propagation while releasing the local pause safely

### Requirement: Local and remote image failures provide accessible empty states

Local and remote image failures, including gallery, SHALL display the known-label noninteractive image-error composition with a visible broken-image symbol and one neutral accessible description. Feedback SHALL respect slot bounds and privacy. Corrupt-media retry SHALL NOT be added; admin staged-path resolution retry SHALL remain separate.

#### Scenario: Local file is unreadable, absent, empty or corrupt

- **WHEN** the local thumbnail provider fails to read or decode a staged file
- **THEN** the bounded image-error composition replaces the failed image, and its explicit label remains in the semantics tree even when visible text is omitted
- **AND** decorative icon/text semantics do not duplicate it; no arbitrary-widget string extraction or EmptyView public API addition is required
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
