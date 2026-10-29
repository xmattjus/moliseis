# unsaved-changes-dialog Specification

## Purpose
Provide one accessible unsaved-field decision presentation whose callers retain all persistence, authorization and navigation responsibility.

## Requirements

### Requirement: Shared dialog reports a typed decision only
The shared presentation SHALL offer exactly Save and Exit, Discard and Exit, and Cancel, returning the typed decisions `saveAndExit`, `discardAndExit`, and `cancel`. It SHALL contain no persistence, navigation policy, ViewModel, Command or repository behavior. Dismissal SHALL grant no affirmative permission.

#### Scenario: Select each decision
- **WHEN** a user activates any of the three choices
- **THEN** only its corresponding typed result is returned to the caller
- **AND** no checkpoint, remote Save, upload or database mutation occurs inside the dialog

#### Scenario: Escape Back or barrier dismissal
- **WHEN** the dialog is dismissed without an affirmative choice
- **THEN** the caller treats the result as Cancel and the editor remains open
- **AND** dismissal cannot pop the underlying editor

### Requirement: Supporting copy describes the caller's save boundary
The presentation SHALL accept caller-supplied supporting copy. Admin copy SHALL explicitly explain that Save and Exit saves fields to a local draft on this device and does not save remotely; remote Save remains a separate action. Discard copy SHALL describe discarding only changes since the effective field baseline, retaining staged photos and previously saved draft work. Public SHALL retain its existing exit meaning.

#### Scenario: Admin reviews the decision
- **WHEN** the Admin dirty-exit dialog opens
- **THEN** the user can distinguish local checkpoint from remote Save and field discard from deleting staged work
- **AND** no remote validation is required for the local choice

### Requirement: Dialog adapts to all supported window classes
The presentation SHALL reuse the app's Material 3 Expressive shape, color and typography tokens across compact, medium, expanded, large and extraLarge windows. Safe insets, constrained readable width, wrapping or stacked actions and scrollable content SHALL keep all choices reachable in narrow landscape and with accessibility text scaling, without clipped text or overflow.

#### Scenario: Responsive theme and scaling matrix
- **WHEN** the dialog renders at 320, 390, 700, 1000, 1300 and 1700 dp, in light and dark themes, at default and large text scale
- **THEN** title, supporting copy and three actions are readable and reachable without layout exceptions or overflow
- **AND** a 700 by 320 dp landscape viewport retains reachable actions and dismiss controls

### Requirement: Dialog supports desktop keyboard and assistive navigation
The dialog SHALL expose labeled semantics, visible focus, modal focus containment and deterministic Tab/Shift-Tab traversal. Enter/Space SHALL activate only the focused action; Escape SHALL cancel. Initial focus SHALL be non-destructive and text scaling SHALL NOT be suppressed.

#### Scenario: Keyboard-only decision
- **WHEN** a desktop user opens the dialog and traverses its actions
- **THEN** focus remains in the modal, every action can be reached and activated, and Escape returns cancellation
- **AND** no default key activation silently discards fields
