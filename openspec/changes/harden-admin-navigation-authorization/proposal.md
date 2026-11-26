# Investigate and harden Admin navigation authorization

**Status — investigation required before the next public release.** The
project owner retains the release decision after investigation and severity
assessment. This work can proceed independently of
[deferred route exits](../harden-deferred-route-exits/proposal.md).

## Demonstrated behavior

1. With Admin authority, push the malformed submission diagnostic and let it
   settle. Push an Admin Dashboard cover and drain microtasks without a
   frame. The cover has committed while the diagnostic is still the
   Navigator's installed top Route.
2. Revoke Admin authority. The auth refresh can reinterpret the outstanding
   push, redirect its destination to Login and retain the existing Admin
   entries beneath Login.
3. Reconcile the screen and send system Back. The diagnostic can become
   visible again while `isAdmin` is false.

The investigation reproduced this sequence both at the pre-remediation
baseline (`e15233f`) and with the deferred-exit workaround (`38ddca5`). The
ordering matters. After the cover is installed, the auth refresh can replace
the stack with Login.

Private-data exposure and backend authorization bypass were not demonstrated.
The diagnostic's visibility establishes a presentation and history issue.
Evaluate client-side presentation and action admission independently of
server-side data and action authorization.

## Investigation scope

Determine whether retained history can expose Admin Dashboard data, editor
state or private drafts, previous-account data, or protected feature actions.
Cover sign-out, role revocation and account replacement. Verify both the
visible history and applicable server enforcement before assigning severity
or proposing a correction.
