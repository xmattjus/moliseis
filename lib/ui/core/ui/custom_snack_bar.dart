import 'package:flutter/material.dart';
import 'package:material_symbols_icons/symbols.dart';
import 'package:moliseis/config/dependencies.dart';
import 'package:moliseis/utils/extensions/extensions.dart';
import 'package:moliseis/utils/logging/logging.dart';
import 'package:provider/provider.dart';

/// The severity of a snack bar, which drives its background, foreground and
/// action foreground (if not provided in the call site) colors as well as the
/// leading icon shown by [showSnackBar].
///
/// - [info]: neutral informational feedback.
/// - [warning]: alerts the user that an action needs attention.
/// - [error]: signals a failed operation.
enum SnackBarType { info, warning, error }

/// The duration of a snack bar.
///
/// * [extrashort] - 1000ms.
/// * [short] - 1500ms.
/// * [medium] - 3000ms, matches current SnackBar standard duration.
/// * [long] - 5000ms.
enum SnackBarDuration { extrashort, short, medium, long }

/// Shows the standard generic error snack bar, reusing the same localized
/// message across the app.
///
/// Convenience wrapper around [showSnackBar] for failures whose specific
/// cause should not be shown to the user; the message is a fixed Italian
/// string ("Si è verificato un errore, riprova più tardi").
void showSnackBarGenericError({
  required BuildContext context,
}) => showSnackBar(
  context: context,
  textContent: 'Si è verificato un errore, riprova più tardi',
  type: SnackBarType.error,
);

/// Removes the current and queued snack bars from the app-wide messenger.
///
/// This intentionally applies a global latest-feedback policy. Call it only
/// when newer feedback must revoke a previously actionable message.
void clearAppSnackBars() {
  final globalMessenger = $scaffoldMessengerKey.currentState;
  if (globalMessenger == null) return;

  globalMessenger
    ..clearSnackBars()
    ..removeCurrentSnackBar();
}

/// Shows a floating Material 3 snack bar through the app-wide scaffold
/// messenger, so it works from any context without a `Scaffold` ancestor
/// (e.g. after an async gap) and never clashes with per-screen messengers.
///
/// The snack bar text is [textContent] and its severity is [type], which
/// drives the background, foreground, and leading icon. When [replaceCurrent]
/// is true, the global messenger removes all current and queued feedback
/// before presenting this one. If the global messenger is unavailable, or an
/// ordinary exception prevents display, the failure is logged through the
/// injected [Logger]. Flutter contract errors and assertions remain visible.
void showSnackBar({
  required BuildContext context,
  required String textContent,
  SnackBarType type = SnackBarType.info,
  SnackBarAction? action,
  SnackBarDuration duration = SnackBarDuration.medium,
  bool replaceCurrent = false,
}) {
  final globalMessenger = $scaffoldMessengerKey.currentState;

  if (globalMessenger == null) {
    context.read<Logger?>()?.log(
      const SnackBarShowFailed(reason: 'The global ScaffoldMessenger is null'),
    );

    return;
  }

  try {
    if (replaceCurrent) {
      clearAppSnackBars();
    }

    globalMessenger.showSnackBar(
      _buildSnackBar(
        context,
        textContent,
        type,
        action,
        _snackBarDurationEnumToDuration(duration),
      ),
    );
  } on Exception catch (exception, stackTrace) {
    context.read<Logger?>()?.log(
      const SnackBarShowFailed(),
      error: exception,
      stackTrace: stackTrace,
    );
  }
}

Duration _snackBarDurationEnumToDuration(SnackBarDuration duration) =>
    switch (duration) {
      SnackBarDuration.extrashort => const Duration(milliseconds: 1000),
      SnackBarDuration.short => const Duration(milliseconds: 1500),
      SnackBarDuration.medium => const Duration(milliseconds: 3000),
      SnackBarDuration.long => const Duration(milliseconds: 5000),
    };

SnackBar _buildSnackBar(
  BuildContext context,
  String textContent,
  SnackBarType type,
  SnackBarAction? action,
  Duration duration,
) {
  final appColors = context.appColors;

  final background = switch (type) {
    SnackBarType.info => appColors.infoSnackBar.background,
    SnackBarType.warning => appColors.warningSnackBar.background,
    SnackBarType.error => appColors.errorSnackBar.background,
  };

  final foreground = switch (type) {
    SnackBarType.info => appColors.infoSnackBar.foreground,
    SnackBarType.warning => appColors.warningSnackBar.foreground,
    SnackBarType.error => appColors.errorSnackBar.foreground,
  };

  final actionForeground = switch (type) {
    SnackBarType.info => appColors.infoSnackBar.actionForeground,
    SnackBarType.warning => appColors.warningSnackBar.actionForeground,
    SnackBarType.error => appColors.errorSnackBar.actionForeground,
  };

  final icon = switch (type) {
    SnackBarType.info => Symbols.info,
    SnackBarType.warning => Symbols.warning,
    SnackBarType.error => Symbols.error,
  };

  /// Rebuilds the call-site action with a per-type `textColor` so its label
  /// reads as a tappable text button on this snack bar's container background.
  ///
  /// Call sites pass only `label` and `onPressed`, leaving
  /// [SnackBarAction.textColor] null. The null resolves to the M3 default —
  /// [ColorScheme.inversePrimary] (see `_SnackbarDefaultsM3`) — which is
  /// tuned for the dark default background; this app's info, warning, and
  /// error backgrounds are light containers, so the default label washes out.
  ///
  /// A single [SnackBarThemeData.actionTextColor] cannot fix this, because the
  /// three backgrounds differ in hue. Instead `actionForeground` holds an
  /// intermediate tone of the *same* per-type seed palette (tone 40 in light,
  /// tone 80 in dark), mirroring how [ColorScheme.inversePrimary] relates to
  /// [ColorScheme.inverseSurface]. It is deliberately distinct from the body
  /// `foreground`, giving the label a tinted-button affordance rather than
  /// looking like plain text.
  ///
  /// `disabledTextColor` receives the same per-type treatment, since the M3
  /// default does not visually distinguish the disabled action.
  /// `backgroundColor` and `disabledBackgroundColor` pass through untouched
  /// so the action stays a transparent text button.
  final recoloredAction = action == null
      ? null
      : SnackBarAction(
          textColor: action.textColor ?? actionForeground,
          disabledTextColor: action.disabledTextColor ?? actionForeground,
          backgroundColor: action.backgroundColor,
          disabledBackgroundColor: action.disabledBackgroundColor,
          label: action.label,
          onPressed: action.onPressed,
        );

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
    shape: RoundedRectangleBorder(
      borderRadius: context.appShapes.circular.cornerMedium,
    ),
    behavior: SnackBarBehavior.floating,
    action: recoloredAction,
    duration: duration,
    persist: false,
  );
}
