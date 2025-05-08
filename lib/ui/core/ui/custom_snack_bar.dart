import 'package:flutter/material.dart';
import 'package:moliseis/main.dart';

SnackBar _buildSnackBar(BuildContext context, String textContent) {
  return SnackBar(
    content: Text(
      textContent,
      style: Theme.of(context).textTheme.labelLarge?.copyWith(
        color: Theme.of(context).colorScheme.onInverseSurface,
      ),
    ),
    backgroundColor: Theme.of(context).colorScheme.inverseSurface,
    elevation: 3.0,
    margin: const EdgeInsetsDirectional.fromSTEB(24.0, 0, 24.0, 16.0),
    behavior: SnackBarBehavior.floating,
  );
}

/// Shows a floating style Material3 snack bar.
void showSnackBar({
  required BuildContext context,
  required String textContent,
}) {
  final scaffoldMessenger = ScaffoldMessenger.maybeOf(context);

  if (scaffoldMessenger == null) {
    logger.warning('ScaffoldMessenger.maybeOf(context) is null.');
    return;
  }

  scaffoldMessenger.showSnackBar(_buildSnackBar(context, textContent));
}
