import 'dart:async';

import 'package:material_symbols_icons/symbols.dart';
import 'package:material_ui/material_ui.dart';
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
void showSnackBarGenericError({required BuildContext context}) => showSnackBar(
  context: context,
  textContent: 'Si è verificato un errore, riprova più tardi',
  type: SnackBarType.error,
);

/// Removes the current and queued snack bars from the app-wide messenger.
///
/// This intentionally applies a global latest-feedback policy. Call it only
/// when newer feedback must revoke a previously actionable message. It also
/// invalidates any owned persistent presentation without changing its durable
/// draft or navigation intent.
void clearAppSnackBars() {
  _appSnackBarClearToken = Object();
  _persistentRequest?.cancel();
  _persistentRequest = null;
  ++_ordinarySnackBarGeneration;
  _ordinarySnackBarTail = null;

  final globalMessenger = $scaffoldMessengerKey.currentState;
  _ordinarySnackBarMessenger = globalMessenger;
  if (globalMessenger == null ||
      !identical(_persistentCloseTail?.messenger, globalMessenger)) {
    _persistentCloseTail = null;
  }
  if (globalMessenger == null) return;

  globalMessenger
    ..clearSnackBars()
    ..removeCurrentSnackBar();
}

Object _appSnackBarClearToken = Object();

/// Identifies the latest explicit global clear boundary.
///
/// Capture before deferred eligibility work and compare before registering a
/// persistent request, so clearing also revokes work not yet in the helper.
Object get appSnackBarClearToken => _appSnackBarClearToken;

_PersistentSnackBarRequest? _persistentRequest;
Future<void>? _ordinarySnackBarTail;
ScaffoldMessengerState? _ordinarySnackBarMessenger;
int _ordinarySnackBarGeneration = 0;

/// Shows an actionable recovery snack bar outside the native queue while
/// ordinary feedback is active. The returned callback cancels this request;
/// cancellation is safe to repeat and only closes its own visible entry.
///
/// After ordinary feedback settles, [revalidate] must still authorize the
/// request before it can be shown again. Native close and swipe call
/// [onDismissed]; temporary interruption does not.
VoidCallback showPersistentSnackBar({
  required BuildContext context,
  required String textContent,
  required String actionLabel,
  required VoidCallback onActionPressed,
  required Future<bool> Function() revalidate,
  required VoidCallback onDismissed,
}) {
  _persistentRequest?.cancel();
  final messenger = $scaffoldMessengerKey.currentState;
  if (messenger == null) {
    context.read<Logger?>()?.log(
      const SnackBarShowFailed(reason: 'The global ScaffoldMessenger is null'),
    );
    return () {};
  }
  _bindMessenger(messenger);

  late final _PersistentSnackBarRequest request;
  request = _PersistentSnackBarRequest(
    messenger: messenger,
    textContent: textContent,
    actionLabel: actionLabel,
    onActionPressed: onActionPressed,
    revalidate: revalidate,
    onDismissed: onDismissed,
  );
  _persistentRequest = request;
  _resumePersistentRequest(request);
  return request.cancel;
}

/// Shows a floating Material 3 snack bar through the app-wide scaffold
/// messenger, so it works from any context without a `Scaffold` ancestor
/// (e.g. after an async gap) and never clashes with per-screen messengers.
///
/// The snack bar text is [textContent] and its severity is [type], which
/// drives the background, foreground, and leading icon. When [replaceCurrent]
/// is true, the global messenger removes current and queued ordinary feedback
/// before presenting this one. An owned persistent recovery request is
/// suspended and remains eligible for later authoritative revalidation. If the
/// global messenger is unavailable, or an ordinary exception prevents
/// display, the failure is logged through the injected [Logger]. Flutter
/// contract errors and assertions remain visible.
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
  _bindMessenger(globalMessenger);

  try {
    _suspendPersistentRequest();
    if (replaceCurrent) {
      // Replacement intentionally clears ordinary feedback but keeps the
      // separately owned recovery request eligible for later revalidation.
      _clearOrdinarySnackBars(globalMessenger);
    }

    final controller = globalMessenger.showSnackBar(
      _buildSnackBar(
        context,
        textContent,
        type,
        action,
        _snackBarDurationEnumToDuration(duration),
      ),
    );
    final generation = ++_ordinarySnackBarGeneration;
    _ordinarySnackBarTail = controller.closed;
    unawaited(
      controller.closed.then((_) {
        if (_ordinarySnackBarGeneration == generation) {
          final request = _persistentRequest;
          if (request != null) _resumePersistentRequest(request);
        }
      }),
    );
  } on Exception catch (exception, stackTrace) {
    context.read<Logger?>()?.log(
      const SnackBarShowFailed(),
      error: exception,
      stackTrace: stackTrace,
    );
  }
}

void _bindMessenger(ScaffoldMessengerState messenger) {
  final request = _persistentRequest;
  if (request != null && !identical(request.messenger, messenger)) {
    request.cancel();
  }
  if (!identical(_ordinarySnackBarMessenger, messenger)) {
    ++_ordinarySnackBarGeneration;
    _ordinarySnackBarTail = null;
    _ordinarySnackBarMessenger = messenger;
  }
  final closing = _persistentCloseTail;
  if (closing != null && !identical(closing.messenger, messenger)) {
    _persistentCloseTail = null;
  }
}

void _clearOrdinarySnackBars(ScaffoldMessengerState messenger) {
  ++_ordinarySnackBarGeneration;
  _ordinarySnackBarTail = null;
  messenger
    ..clearSnackBars()
    ..removeCurrentSnackBar();
}

void _suspendPersistentRequest() {
  final request = _persistentRequest;
  if (request == null) return;
  request.suspend();
}

void _resumePersistentRequest(_PersistentSnackBarRequest request) {
  if (request.canceled || !identical(_persistentRequest, request)) return;
  final closing = _persistentCloseTail;
  if (closing != null) {
    if (!identical(closing.messenger, request.messenger)) {
      _persistentCloseTail = null;
      _resumePersistentRequest(request);
      return;
    }
    unawaited(
      closing.future.then((_) {
        if (identical(_persistentCloseTail, closing)) {
          _persistentCloseTail = null;
          final current = _persistentRequest;
          if (current != null) _resumePersistentRequest(current);
        }
      }),
    );
    return;
  }
  final messenger = $scaffoldMessengerKey.currentState;
  if (messenger == null || !identical(messenger, request.messenger)) {
    request.cancel();
    return;
  }
  if (_ordinarySnackBarTail != null) {
    final tail = _ordinarySnackBarTail!;
    unawaited(
      tail.then((_) {
        if (identical(_ordinarySnackBarTail, tail)) {
          _ordinarySnackBarTail = null;
          final current = _persistentRequest;
          if (current != null) _resumePersistentRequest(current);
        }
      }),
    );
    return;
  }
  if (request.validating || request.controller != null) return;
  request.validating = true;
  final validationGeneration = _ordinarySnackBarGeneration;
  unawaited(
    request.revalidate().then<void>(
      (isValid) {
        if (!isValid ||
            request.canceled ||
            !identical(_persistentRequest, request)) {
          request.validating = false;
          return;
        }
        if (validationGeneration != _ordinarySnackBarGeneration ||
            _ordinarySnackBarTail != null) {
          request.validating = false;
          _resumePersistentRequest(request);
          return;
        }
        if (!identical($scaffoldMessengerKey.currentState, request.messenger)) {
          request
            ..validating = false
            ..cancel();
          return;
        }
        WidgetsBinding.instance.addPostFrameCallback((_) {
          if (request.canceled || !identical(_persistentRequest, request)) {
            request.validating = false;
            return;
          }
          if (validationGeneration != _ordinarySnackBarGeneration ||
              _ordinarySnackBarTail != null) {
            request.validating = false;
            _resumePersistentRequest(request);
            return;
          }
          if (!identical(
            $scaffoldMessengerKey.currentState,
            request.messenger,
          )) {
            request
              ..validating = false
              ..cancel();
            return;
          }
          request
            ..validating = false
            ..present();
        });
        WidgetsBinding.instance.ensureVisualUpdate();
      },
      onError: (Object error, StackTrace stack) {
        request.validating = false;
        Error.throwWithStackTrace(error, stack);
      },
    ),
  );
}

final class _PersistentSnackBarRequest {
  _PersistentSnackBarRequest({
    required this.messenger,
    required this.textContent,
    required this.actionLabel,
    required this.onActionPressed,
    required this.revalidate,
    required this.onDismissed,
  });

  final ScaffoldMessengerState messenger;
  final String textContent;
  final String actionLabel;
  final VoidCallback onActionPressed;
  final Future<bool> Function() revalidate;
  final VoidCallback onDismissed;
  ScaffoldFeatureController<SnackBar, SnackBarClosedReason>? controller;
  bool validating = false;
  bool canceled = false;

  void present() {
    if (canceled || controller != null) return;
    controller = messenger.showSnackBar(
      _buildSnackBar(
        messenger.context,
        textContent,
        SnackBarType.info,
        SnackBarAction(
          label: actionLabel,
          onPressed: () {
            if (canceled ||
                !identical(_persistentRequest, this) ||
                !identical($scaffoldMessengerKey.currentState, messenger)) {
              return;
            }
            onActionPressed();
          },
        ),
        const Duration(days: 1),
        persist: true,
        showCloseIcon: true,
      ),
    );
    unawaited(
      controller!.closed.then((reason) {
        controller = null;
        if (canceled || !identical(_persistentRequest, this)) return;
        if (reason == SnackBarClosedReason.dismiss ||
            reason == SnackBarClosedReason.swipe) {
          cancel();
          onDismissed();
        }
      }),
    );
  }

  void suspend() {
    final current = controller;
    controller = null;
    if (current != null &&
        identical($scaffoldMessengerKey.currentState, messenger)) {
      final closing = current.closed.then<void>((_) {});
      _persistentCloseTail = _PersistentCloseTail(messenger, closing);
      current.close();
      unawaited(
        closing.then((_) {
          if (identical(_persistentCloseTail?.future, closing)) {
            _persistentCloseTail = null;
            final request = _persistentRequest;
            if (request != null) _resumePersistentRequest(request);
          }
        }),
      );
    }
  }

  void cancel() {
    if (canceled) return;
    canceled = true;
    final current = controller;
    controller = null;
    if (identical(_persistentRequest, this)) _persistentRequest = null;
    if (current != null &&
        identical($scaffoldMessengerKey.currentState, messenger)) {
      _persistentCloseTail = _PersistentCloseTail(
        messenger,
        current.closed.then<void>((_) {}),
      );
      current.close();
    }
  }
}

final class _PersistentCloseTail {
  const _PersistentCloseTail(this.messenger, this.future);

  final ScaffoldMessengerState messenger;
  final Future<void> future;
}

_PersistentCloseTail? _persistentCloseTail;

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
  Duration duration, {
  bool persist = false,
  bool showCloseIcon = false,
}) {
  const contentMaxLines = 2;
  const horizontalMargin = 24.0;
  const contentSpacing = 8.0;
  const leadingIconSize = 20.0;
  const fullWidthTextLength = 40;

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
    content: Builder(
      builder: (context) {
        final contentStyle = context.textTheme.bodyMedium!.copyWith(
          color: foreground,
        );
        // Match Text's effective accessibility style without changing the role.
        final measuredStyle = contentStyle.copyWith(
          fontWeight: MediaQuery.boldTextOf(context) ? FontWeight.bold : null,
          height: MediaQuery.maybeLineHeightScaleFactorOverrideOf(context),
          letterSpacing: MediaQuery.maybeLetterSpacingOverrideOf(context),
          wordSpacing: MediaQuery.maybeWordSpacingOverrideOf(context),
        );
        final locale = Localizations.maybeLocaleOf(context);
        final width = MediaQuery.sizeOf(context).width;
        final textSpan = TextSpan(text: textContent, style: measuredStyle);
        final availableWidth =
            width - (horizontalMargin * 2) - (showCloseIcon ? 48 : 0);
        final snackBarContentWidth = availableWidth > 1 ? availableWidth : 1.0;

        final textPainter = TextPainter(
          text: textSpan,
          textDirection: Directionality.of(context),
          textScaler: MediaQuery.textScalerOf(context),
          locale: locale,
          maxLines: contentMaxLines,
        )..layout(maxWidth: snackBarContentWidth);

        final contentLinesSpan = textPainter.computeLineMetrics().length;
        textPainter.dispose();

        // Keep long feedback readable below the leading icon. TextPainter may
        // run before the app font has loaded, so the character threshold keeps
        // this conservative.
        final usesFullWidthText =
            contentLinesSpan > 1 || textContent.length > fullWidthTextLength;

        final leadingIcon = Icon(
          icon,
          color: foreground,
          size: leadingIconSize,
        );

        final contentText = Text(
          textContent,
          style: contentStyle,
          locale: locale,
          maxLines: contentMaxLines,
          overflow: TextOverflow.ellipsis,
        );

        final row = Row(
          spacing: contentSpacing,
          children: [
            leadingIcon,
            Expanded(child: contentText),
            if (!usesFullWidthText && contentLinesSpan == 1) ?recoloredAction,
          ],
        );

        return !usesFullWidthText
            ? row
            : Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                spacing: contentSpacing,
                children: [
                  row,
                  if (recoloredAction != null)
                    Align(
                      alignment: AlignmentGeometry.bottomEnd,
                      child: recoloredAction,
                    ),
                ],
              );
      },
    ),
    backgroundColor: background,
    elevation: 3,
    margin: const EdgeInsetsDirectional.symmetric(
      horizontal: horizontalMargin,
      vertical: 16,
    ),
    shape: RoundedRectangleBorder(
      borderRadius: context.appShapes.circular.cornerMedium,
    ),
    behavior: SnackBarBehavior.floating,
    duration: duration,
    persist: persist,
    showCloseIcon: showCloseIcon,
    closeIconColor: foreground,
  );
}
