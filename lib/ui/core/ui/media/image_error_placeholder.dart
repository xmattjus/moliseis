import 'dart:math' as math;

import 'package:material_symbols_icons/symbols.dart';
import 'package:material_ui/material_ui.dart';
import 'package:moliseis/ui/core/ui/empty_view.dart';

/// Noninteractive image failure with one description, including in tiny slots.
///
/// Full [EmptyView] decoration is used only when the actual label fits. Smaller
/// slots keep a bounded icon and the same independent accessible description.
class ImageErrorPlaceholder extends StatelessWidget {
  /// Creates neutral feedback without exposing the image's source or exception.
  const ImageErrorPlaceholder({super.key});

  static const _label = 'Immagine non disponibile';

  @override
  Widget build(BuildContext context) => Semantics(
    label: _label,
    excludeSemantics: true,
    child: LayoutBuilder(
      builder: (context, constraints) {
        final style = Theme.of(context).textTheme.bodyLarge!.copyWith(
          fontWeight: MediaQuery.boldTextOf(context) ? FontWeight.bold : null,
          height: MediaQuery.maybeLineHeightScaleFactorOverrideOf(context),
          letterSpacing: MediaQuery.maybeLetterSpacingOverrideOf(context),
          wordSpacing: MediaQuery.maybeWordSpacingOverrideOf(context),
        );
        final painter = TextPainter(
          text: TextSpan(text: _label, style: style),
          textAlign: TextAlign.center,
          textDirection: Directionality.of(context),
          textScaler: MediaQuery.textScalerOf(context),
          locale: Localizations.maybeLocaleOf(context),
          textHeightBehavior: DefaultTextHeightBehavior.maybeOf(context),
        )..layout(maxWidth: math.max(0, constraints.maxWidth - 32));
        final fits =
            constraints.maxWidth >= 104 &&
            constraints.maxHeight >= 96 + painter.height;
        painter.dispose();

        final color = Theme.of(context).colorScheme.onSurfaceVariant;
        if (fits) {
          return EmptyView(
            icon: Icon(
              Symbols.broken_image,
              color: color,
              applyTextScaling: false,
            ),
            text: const Text(_label),
          );
        }

        return Center(
          child: Icon(
            Symbols.broken_image,
            size: math.min(
              40,
              math.min(constraints.maxWidth, constraints.maxHeight),
            ),
            color: color,
            applyTextScaling: false,
          ),
        );
      },
    ),
  );
}
