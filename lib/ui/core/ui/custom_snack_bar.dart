import 'package:flutter/material.dart';
import 'package:material_symbols_icons/symbols.dart';
import 'package:moliseis/config/dependencies.dart';
import 'package:moliseis/utils/extensions/extensions.dart';
import 'package:moliseis/utils/logging/logging.dart';
import 'package:provider/provider.dart';

enum SnackBarType { info, warning, error }

/// Shows a floating style Material3 snack bar.
void showSnackBar({
  required BuildContext context,
  required String textContent,
  SnackBarType type = SnackBarType.info,
}) {
  final globalMessenger = $scaffoldMessengerKey.currentState;

  if (globalMessenger == null) {
    context.read<Logger?>()?.log(
      const SnackBarShowFailed(reason: 'The global ScaffoldMessenger is null'),
    );

    return;
  }

  try {
    globalMessenger.showSnackBar(
      _buildSnackBar(context, textContent, type),
    );
  } on Exception catch (exception, stackTrace) {
    context.read<Logger?>()?.log(
      const SnackBarShowFailed(),
      error: exception,
      stackTrace: stackTrace,
    );
  }

  return;
}

SnackBar _buildSnackBar(
  BuildContext context,
  String textContent,
  SnackBarType type,
) {
  final background = switch (type) {
    SnackBarType.info => Colors.lightBlueAccent,
    SnackBarType.warning => Colors.yellowAccent,
    SnackBarType.error => context.colorScheme.errorContainer,
  };

  final foreground = switch (type) {
    SnackBarType.info => Colors.lightBlue.darken(0.3),
    SnackBarType.warning => Colors.yellow.darken(0.5),
    SnackBarType.error => context.colorScheme.onErrorContainer,
  };

  final icon = switch (type) {
    SnackBarType.info => Symbols.info,
    SnackBarType.warning => Symbols.warning,
    SnackBarType.error => Symbols.error,
  };

  return SnackBar(
    content: Row(
      spacing: 8,
      children: [
        Icon(
          icon,
          color: foreground,
        ),
        Expanded(
          child: Text(
            textContent,
            style: Theme.of(context).textTheme.labelLarge?.copyWith(
              color: foreground,
            ),
            softWrap: true,
          ),
        ),
      ],
    ),
    backgroundColor: background,
    elevation: 3,
    margin: const EdgeInsetsDirectional.fromSTEB(24, 0, 24, 16),
    behavior: SnackBarBehavior.floating,
    shape: RoundedRectangleBorder(
      borderRadius: context.appShapes.circular.cornerMedium,
    ),
  );
}
