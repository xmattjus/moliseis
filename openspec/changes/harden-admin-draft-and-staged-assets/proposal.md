# Proposal

## Why

Admin lacks reusable durable draft and private staged-file boundaries. Activating those boundaries alongside the current remote Save workflow would require disposable compatibility states, while the installed Android picker cannot safely settle or correlate every interrupted operation. Deliver the local foundation without changing either feature's working production path.

## What Changes

- Add an immutable, account-owned Admin draft, explicit checkpoint persistence and a small local-only session component with separate effective, physical and remote baselines.
- Add Admin-specific ObjectBox entities, mapping and private staged-file acquisition, deduplication, capacity checks and reconciliation. Preserve owners and inactive sessions; field snapshot replacement never deletes asset ownership.
- Keep these foundations unregistered and unreachable from production routes, startup and pickers until Plan 2. Their source/real-store tests are the first consumer; Plan 2's editor is the defined production consumer.
- Reuse staged-file acquisition as the low-level intake for a future verified recovery handoff. Do not implement speculative tickets, inbox schemas, a platform coordinator or native changes in Plan 1.
- Preserve Public's existing recovery, staging, submission and navigation contracts and Admin's existing Create/Update, moderation and immediate persisted-image path.
- Preserve the obsolete Admin proposal with an accurate supersession/disposition notice, without claiming its implementation or synchronizing unimplemented requirements.

## Capabilities

### New Capabilities

- `admin-draft-persistence`: reusable local identity, incomplete immutable snapshots, checkpoint/baseline semantics, exact-owner recovery and retention. This capability does not activate the editor.
- `admin-local-asset-staging`: account/session-owned private files, safe commit ordering, limits, reconciliation and owner preservation without upload or platform access.

### Modified Capabilities

- `content-submission-local-asset-staging`: add storage-boundary isolation from Admin and prohibit local storage from independently consuming picker recovery. Existing Public requirements are not replaced or weakened.

## Impact

Plan 1 implementation is limited to Admin domain/local orchestration, two additive ObjectBox entities and their generated mappings, data repositories/filesystem code and focused tests. It adds no dependencies, Provider registration, auth subscription, route/startup/picker changes, UI, Supabase contract or Cloudinary operation.

Plan 2 must activate application-owned Admin editing, durable restoration, integrated Save/Progress, remote ID adoption and staged persistence together. It must first evaluate server-authoritative Admin Create/association idempotency and obtain a verified picker attribution/settlement contract before shared recovery activation. The current plugin's gap remains an explicit blocked integration dependency, not a globally blocking product behavior shipped by Plan 1. Plan 3 retains stale/outcome recovery; Plan 4 retains dirty exit. All implementation tasks remain future work.
