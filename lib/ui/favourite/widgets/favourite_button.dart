import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:moliseis/domain/models/core/content_base.dart';
import 'package:moliseis/domain/models/event/event_content.dart';
import 'package:moliseis/ui/core/themes/shapes.dart';
import 'package:moliseis/ui/favourite/view_models/favourite_view_model.dart';
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
    this.radius,
  }) : _type = FavouriteButtonType.small;

  /// Creates an actionable [OutlinedButton.icon] to set the saved state of the
  /// content.
  const FavouriteButton.wide({super.key, required this.content, this.radius})
    : color = null,
      _type = FavouriteButtonType.wide;

  final Color? color;
  final ContentBase content;
  final double? radius;
  final FavouriteButtonType _type;

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;

    return Consumer<FavouriteViewModel>(
      builder: (_, viewModel, _) {
        final isSaved = viewModel.isFavourite(content);

        final shape = RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(
            radius ?? (isSaved ? Shapes.medium : Shapes.full),
          ),
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
                child: RawMaterialButton(
                  key: ValueKey<bool>(isSaved),
                  onPressed: onPressed(content, isSaved, viewModel),
                  fillColor: isSaved ? colorScheme.errorContainer : null,
                  elevation: 0,
                  focusElevation: 0,
                  hoverElevation: 0,
                  highlightElevation: 0,
                  focusColor: feedbackColor.withValues(alpha: 0.08),
                  hoverColor: feedbackColor.withValues(alpha: 0.08),
                  splashColor: splashColor.withValues(alpha: 0.1),
                  constraints: const BoxConstraints.expand(
                    width: 40.0,
                    height: 40.0,
                  ),
                  shape: shape,
                  materialTapTargetSize: MaterialTapTargetSize.shrinkWrap,
                  child: Icon(
                    isSaved ? Icons.favorite : Icons.favorite_border,
                    color: isSaved ? colorScheme.error : color,
                    size: 24.0,
                  ),
                ),
              ),
            );
          case FavouriteButtonType.wide:
            return OutlinedButton.icon(
              onPressed: onPressed(content, isSaved, viewModel),
              style: ButtonStyle(
                shape: WidgetStateProperty.resolveWith((states) {
                  if (states.contains(WidgetState.pressed)) {
                    return RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(Shapes.medium),
                    );
                  }

                  return shape;
                }),
              ),
              icon: Icon(isSaved ? Icons.favorite : Icons.favorite_outline),
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
