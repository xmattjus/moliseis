import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:material_symbols_icons/symbols.dart';
import 'package:moliseis/domain/models/content_base.dart';
import 'package:moliseis/domain/models/event_content.dart';
import 'package:moliseis/ui/core/ui/blurred_box.dart';
import 'package:moliseis/ui/favourite/view_models/favourite_view_model.dart';
import 'package:moliseis/utils/extensions/extensions.dart';
import 'package:provider/provider.dart';

enum FavouriteButtonType { small, wide }

class FavouriteButton extends StatelessWidget {
  /// Creates an actionable [IconButton] or [OutlinedButton.icon] to set the
  /// saved state of the content.
  ///
  /// Defaults to [IconButton].
  const FavouriteButton({
    super.key,
    this.color,
    required this.content,
    this.borderRadius,
  }) : _type = FavouriteButtonType.small;

  /// Creates an actionable [OutlinedButton.icon] to set the saved state of the
  /// content.
  const FavouriteButton.wide({
    super.key,
    required this.content,
    this.borderRadius,
  }) : color = null,
       _type = FavouriteButtonType.wide;

  final Color? color;
  final ContentBase content;
  final BorderRadius? borderRadius;
  final FavouriteButtonType _type;

  @override
  Widget build(BuildContext context) {
    final colorScheme = context.colorScheme;
    final appShapes = context.appShapes;

    return Consumer<FavouriteViewModel>(
      builder: (_, viewModel, _) {
        final isSaved = viewModel.isFavourite(content);

        final shape = RoundedRectangleBorder(
          borderRadius:
              borderRadius ??
              (isSaved
                  ? appShapes.circular.cornerMedium
                  : appShapes.circular.cornerFull),
        );

        switch (_type) {
          case FavouriteButtonType.small:
            final feedbackColor = colorScheme.onSurfaceVariant;
            final splashColor = colorScheme.onSurface;

            return Tooltip(
              message: "${isSaved ? 'Rimuovi dai' : 'Salva nei'} preferiti",
              child: AnimatedSwitcher(
                duration: Durations.short3,
                transitionBuilder: (child, animation) {
                  return FadeTransition(opacity: animation, child: child);
                },
                child: BlurredBox(
                  backgroundColor: isSaved
                      ? Color.alphaBlend(
                          Colors.red.withAlpha(36),
                          colorScheme.surfaceContainer.withAlpha(64),
                        )
                      : null,
                  borderRadius: shape.borderRadius as BorderRadius?,
                  child: IconButton(
                    key: ValueKey<bool>(isSaved),
                    onPressed: onPressed(content, isSaved, viewModel),
                    focusColor: feedbackColor.withValues(alpha: 0.08),
                    hoverColor: feedbackColor.withValues(alpha: 0.08),
                    splashColor: splashColor.withValues(alpha: 0.1),
                    constraints: const BoxConstraints.expand(
                      width: 40.0,
                      height: 40.0,
                    ),
                    icon: Icon(
                      isSaved ? Symbols.favorite : Symbols.favorite_border,
                      fill: isSaved ? 1.0 : 0.0,
                      color: isSaved ? Colors.redAccent : color,
                      size: 24.0,
                    ),
                  ),
                ),
              ),
            );
          case FavouriteButtonType.wide:
            return OutlinedButton.icon(
              onPressed: onPressed(content, isSaved, viewModel),
              style: ButtonStyle(
                side: WidgetStateProperty.resolveWith((states) {
                  if (isSaved && !states.contains(WidgetState.pressed)) {
                    return BorderSide(
                      color: Colors.redAccent,
                      width: context.appSizes.borderSide.large,
                    );
                  }

                  return null;
                }),
                shape: WidgetStateProperty.resolveWith((states) {
                  if (states.contains(WidgetState.pressed)) {
                    return RoundedRectangleBorder(
                      borderRadius: appShapes.circular.cornerMedium,
                    );
                  }

                  return shape;
                }),
                foregroundColor: WidgetStateProperty.resolveWith((states) {
                  if (states.contains(WidgetState.pressed)) {
                    return colorScheme.onSurfaceVariant;
                  }

                  return isSaved ? Colors.redAccent : null;
                }),
              ),
              icon: Icon(
                isSaved ? Symbols.favorite : Symbols.favorite_border,
                fill: isSaved ? 1.0 : 0.0,
              ),
              label: Text(isSaved ? 'Rimuovi' : 'Salva'),
            );
        }
      },
    );
  }

  void Function() onPressed(
    ContentBase content,
    bool isSaved,
    FavouriteViewModel viewModel,
  ) {
    return () {
      HapticFeedback.lightImpact();

      if (content is EventContent) {
        if (isSaved) {
          viewModel.removeEvent.execute(content.remoteId);
        } else {
          viewModel.addEvent.execute(content.remoteId);
        }
      } else {
        if (isSaved) {
          viewModel.removePlace.execute(content.remoteId);
        } else {
          viewModel.addPlace.execute(content.remoteId);
        }
      }
    };
  }
}
