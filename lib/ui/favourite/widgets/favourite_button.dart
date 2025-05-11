import 'package:flutter/material.dart';
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
    this.type = FavouriteButtonType.small,
  });

  /// Creates an actionable [OutlinedButton.icon] to set the saved state of an
  /// attraction.
  const FavouriteButton.wide({super.key, required this.id})
    : color = null,
      type = FavouriteButtonType.wide;

  final Color? color;
  final int id;
  final FavouriteButtonType type;

  @override
  Widget build(BuildContext context) {
    return Consumer<FavouriteViewModel>(
      builder: (_, viewModel, _) {
        final isSaved = viewModel.favourites.contains(id);

        if (type == FavouriteButtonType.small) {
          final feedbackColor = Theme.of(context).colorScheme.onSurfaceVariant;
          final splashColor = Theme.of(context).colorScheme.onSurface;

          return Tooltip(
            message: 'Salva nei preferiti',
            child: RawMaterialButton(
              onPressed: () {
                isSaved
                    ? viewModel.deleteFavourite.execute(id)
                    : viewModel.addFavourite.execute(id);
              },
              elevation: 0.0,
              focusElevation: 0.0,
              hoverElevation: 0.0,
              highlightElevation: 0.0,
              focusColor: feedbackColor.withValues(alpha: 0.08),
              hoverColor: feedbackColor.withValues(alpha: 0.08),
              splashColor: splashColor.withValues(alpha: 0.1),
              constraints: const BoxConstraints.expand(width: 40, height: 40),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(40),
              ),
              materialTapTargetSize: MaterialTapTargetSize.shrinkWrap,
              child: Icon(
                isSaved ? Icons.favorite : Icons.favorite_border,
                color: isSaved ? Colors.redAccent : color,
                size: 24,
              ),
            ),
          );
        } else {
          return OutlinedButton.icon(
            onPressed: () {
              isSaved
                  ? viewModel.deleteFavourite.execute(id)
                  : viewModel.addFavourite.execute(id);
            },
            icon: Icon(isSaved ? Icons.favorite : Icons.favorite_outline),
            label: Text(isSaved ? 'Rimuovi' : 'Salva'),
          );
        }
      },
    );
  }
}
