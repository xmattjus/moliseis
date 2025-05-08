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
    required this.id,
    this.type = FavouriteButtonType.small,
  });

  /// Creates an actionable [OutlinedButton.icon] to set the saved state of an
  /// attraction.
  const FavouriteButton.wide({super.key, required this.id})
    : type = FavouriteButtonType.wide;

  final int id;
  final FavouriteButtonType type;

  @override
  Widget build(BuildContext context) {
    return Consumer<FavouriteViewModel>(
      builder: (_, viewModel, _) {
        final isSaved = viewModel.favourites.contains(id);

        if (type == FavouriteButtonType.small) {
          return IconButton(
            onPressed: () {
              isSaved
                  ? viewModel.deleteFavourite.execute(id)
                  : viewModel.addFavourite.execute(id);
            },
            tooltip: 'Salva nei preferiti',
            isSelected: isSaved,
            selectedIcon: const Icon(Icons.favorite, color: Colors.redAccent),
            icon: const Icon(Icons.favorite_outline_outlined),
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
