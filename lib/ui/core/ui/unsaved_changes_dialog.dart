import 'dart:ui' show SemanticsRole;

import 'package:material_ui/material_ui.dart';
import 'package:moliseis/utils/extensions/build_context_extensions.dart';
import 'package:moliseis/utils/extensions/window_size_class_extensions.dart';

/// A presentation decision; callers own persistence and route authority.
enum UnsavedChangesDecision {
  /// Ask the caller to confirm its save boundary before exiting.
  saveAndExit,

  /// Ask the caller to discard only its eligible field changes before exiting.
  discardAndExit,

  /// Retain the editor without changing its fields.
  cancel,
}

/// Presents unsaved-field choices without performing application operations.
///
/// Callers show this widget in their own dialog route and treat dismissal as
/// cancellation. Supporting copy explains their local or remote save boundary.
class UnsavedChangesDialog extends StatelessWidget {
  /// Uses the existing Public exit wording unless the caller supplies a title.
  const UnsavedChangesDialog({
    this.title = 'Salvare le modifiche?',
    this.supportingText,
    super.key,
  });

  /// Accessible heading for this decision.
  final String title;

  /// Caller-owned explanation of what saving and discarding actually affect.
  final String? supportingText;

  @override
  Widget build(BuildContext context) {
    final spacing = context.windowSizeClass.spacing;
    void decide(UnsavedChangesDecision decision) {
      if (!context.mounted) return;
      if (ModalRoute.of(context)?.isCurrent != true) return;
      Navigator.of(context).pop(decision);
    }

    return Dialog(
      semanticsRole: SemanticsRole.alertDialog,
      backgroundColor: context.colorScheme.surfaceContainerHigh,
      shape: RoundedRectangleBorder(
        borderRadius: context.appShapes.circular.cornerExtraLarge,
      ),
      insetPadding: EdgeInsets.all(spacing),
      constraints: const BoxConstraints(maxWidth: 560),
      clipBehavior: Clip.antiAlias,
      child: Semantics(
        scopesRoute: true,
        namesRoute: true,
        explicitChildNodes: true,
        label: title,
        child: SizedBox(
          width: 560,
          // Actions scroll with content so large text remains reachable even
          // when all three actions cannot fit in a short landscape window.
          child: SingleChildScrollView(
            padding: EdgeInsets.all(spacing),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Text(
                  title,
                  style: context.textTheme.headlineSmall?.copyWith(
                    color: context.colorScheme.onSurface,
                  ),
                ),
                if (supportingText case final copy?) ...[
                  SizedBox(height: spacing),
                  Text(
                    copy,
                    style: context.textTheme.bodyMedium?.copyWith(
                      color: context.colorScheme.onSurfaceVariant,
                    ),
                  ),
                ],
                SizedBox(height: spacing),
                Wrap(
                  alignment: WrapAlignment.end,
                  spacing: 8,
                  runSpacing: 8,
                  children: [
                    TextButton(
                      autofocus: true,
                      onPressed: () => decide(UnsavedChangesDecision.cancel),
                      child: const Text('Annulla'),
                    ),
                    TextButton(
                      onPressed: () =>
                          decide(UnsavedChangesDecision.discardAndExit),
                      child: const Text('Esci senza salvare'),
                    ),
                    FilledButton(
                      onPressed: () =>
                          decide(UnsavedChangesDecision.saveAndExit),
                      child: const Text('Salva ed esci'),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
