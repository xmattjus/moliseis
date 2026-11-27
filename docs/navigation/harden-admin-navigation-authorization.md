# Harden Admin navigation authorization

**Status — planning ready for review. Public release blocked.** The project
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

## Open release gates

- Verify authorization remediation together with the stable GoRouter
  upgrade and the [autonomous and local runtime checks](../../openspec/changes/harden-admin-navigation-authorization/test-plan.md).
- Record owner-observed
  [physical Android and iOS results](../../openspec/changes/harden-admin-navigation-authorization/test-plan.md#owner-executed-physical-device-release-gates).
- Resolve or explicitly record remaining runtime limits and obtain the
  project owner's release decision.
