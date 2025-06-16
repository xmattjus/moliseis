import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:moliseis/ui/core/themes/shapes.dart';
import 'package:moliseis/ui/favourite/view_models/favourite_view_model.dart';
import 'package:provider/provider.dart';

enum FavouriteButtonType { small, wide }

class FavouriteButton extends StatelessWidget {
  /// Creates an actionable [IconButton] or [OutlinedButton.icon] to set the
  /// saved state of an attraction.
  ///
  /// Defaults to [IconButton].
  const FavouriteButton({
    super.key,
    this.color,
    required this.id,
    this.radius,
    this.type = FavouriteButtonType.small,
  });

  /// Creates an actionable [OutlinedButton.icon] to set the saved state of an
  /// attraction.
  const FavouriteButton.wide({super.key, required this.id, this.radius})
    : color = null,
      type = FavouriteButtonType.wide;

  final Color? color;
  final int id;
  final double? radius;
  final FavouriteButtonType type;

  @override
  Widget build(BuildContext context) {
    return Consumer<FavouriteViewModel>(
      builder: (_, viewModel, _) {
        final colorScheme = Theme.of(context).colorScheme;

        final isSaved = viewModel.favourites.contains(id);

        final shape = RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(
            radius ?? (isSaved ? Shapes.medium : Shapes.full),
          ),
        );

        switch (type) {
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
                  onPressed: () {
                    HapticFeedback.lightImpact();

                    isSaved
                        ? viewModel.deleteFavourite.execute(id)
                        : viewModel.addFavourite.execute(id);
                  },
                  fillColor: isSaved ? colorScheme.errorContainer : null,
                  elevation: 0.0,
                  focusElevation: 0.0,
                  hoverElevation: 0.0,
                  highlightElevation: 0.0,
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
              onPressed: () {
                isSaved
                    ? viewModel.deleteFavourite.execute(id)
                    : viewModel.addFavourite.execute(id);
              },
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
}
