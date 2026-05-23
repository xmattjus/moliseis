import 'package:flutter/material.dart';
import 'package:moliseis/utils/logging/logging.dart';
import 'package:provider/provider.dart';

SnackBar _buildSnackBar(BuildContext context, String textContent) {
  return SnackBar(
    content: Text(
      textContent,
      style: Theme.of(context).textTheme.labelLarge?.copyWith(
        color: Theme.of(context).colorScheme.onInverseSurface,
      ),
    ),
    backgroundColor: Theme.of(context).colorScheme.inverseSurface,
    elevation: 3,
    margin: const EdgeInsetsDirectional.fromSTEB(24, 0, 24, 16),
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
    context.read<Logger?>()?.log(
      const SnackBarShowFailed(reason: 'ScaffoldMessenger is null'),
    );

    return;
  }

  try {
    scaffoldMessenger.showSnackBar(_buildSnackBar(context, textContent));
  } on Exception catch (exception, stackTrace) {
    context.read<Logger?>()?.log(
      const SnackBarShowFailed(),
      error: exception,
      stackTrace: stackTrace,
    );
  }

  return;
}
