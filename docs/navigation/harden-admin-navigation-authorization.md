# Harden Admin navigation authorization

**Status — implementation prepared for independent review. Public release blocked.** The project
owner retains the release decision. Follow the
[OpenSpec change](../../openspec/changes/harden-admin-navigation-authorization/proposal.md).
This work is independent of [deferred route exits](harden-deferred-route-exits.md).

The investigation at `8c0e61ea42d98641bbb57d829627171bd1a3d279` reproduced
a pending imperative cover that installed Login above revoked Admin
history. Back restored a populated Dashboard with submission and
ignored-source data and could also restore malformed, Editor and Save
Progress routes. Stale Dashboard controls reached a synthetic repository
after revocation. A direct switch to another administrator retained the
old Dashboard and allowed prior intent and results to cross accounts.
The tested Editor paths rejected stale privileged operations and did
not disclose private drafts. The probes established client defects and
produced no unauthorized remote mutation.

The dependency checkpoint reproduced all four Admin findings on GoRouter
18.1.4. The implementation binds protected routes, presentation and work to
continuous observed authority and removes obsolete Admin history. NAV-01 is
enabled with its original Map-root Back and inactive Post retention assertions.
The upstream branch-activity correction passed the widget test. Physical
system and predictive Back remain part of device verification.

Reconciliation keeps committed public history above the clean prefix in
its original order, including a public form beneath a protected cover.
A Progress push requested but not yet committed is kept as well. A
signed-out restoration of a saved Admin base with a public cover may
safely restore Login alone; this is an accepted limitation.

The disposable Supabase run confirmed current server-role enforcement and
observed zero additional endpoint requests from a retired Dashboard
callback. A request that had already passed server authorization could
still complete after demotion. The local results do not establish
production deployment behavior.
[Verification record](../../openspec/changes/harden-admin-navigation-authorization/test-plan.md).

## Open release gates

- Record owner-observed
  [physical Android and iOS results](../../openspec/changes/harden-admin-navigation-authorization/test-plan.md#owner-executed-physical-device-release-gates).
- Resolve or explicitly record remaining runtime limits and obtain the
  project owner's release decision.
