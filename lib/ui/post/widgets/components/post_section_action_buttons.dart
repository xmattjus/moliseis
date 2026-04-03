import 'package:flutter/material.dart';
import 'package:material_symbols_icons/symbols.dart';
import 'package:moliseis/data/services/url_launch_service.dart';
import 'package:moliseis/domain/models/content_base.dart';
import 'package:moliseis/ui/category/widgets/category_button.dart';
import 'package:moliseis/ui/core/ui/custom_snack_bar.dart';
import 'package:moliseis/ui/core/ui/horizontal_button_list.dart';
import 'package:moliseis/ui/favourite/widgets/favourite_button.dart';
import 'package:provider/provider.dart';

/// Displays action buttons for content: category, favourite, and directions.
///
/// Provides a horizontally scrollable list of action buttons with consistent
/// behavior. The category button is disabled when onCategoryPressed is null,
/// allowing contexts (e.g., modals) to hide category navigation functionality.
class PostSectionActionButtons extends StatelessWidget {
  const PostSectionActionButtons({
    super.key,
    required this.content,
    this.onCategoryPressed,
  });

  final ContentBase content;

  /// Callback when the category button is pressed, or null to disable.
  ///
  /// When null, the category button is rendered disabled.
  final void Function()? onCategoryPressed;

  @override
  Widget build(BuildContext context) {
    return SliverToBoxAdapter(
      child: HorizontalButtonList(
        padding: const EdgeInsets.all(16.0),
        items: <Widget>[
          CategoryButton(
            onPressed: onCategoryPressed,
            contentCategory: content.category,
          ),
          FavouriteButton.wide(content: content),
          OutlinedButton.icon(
            onPressed: () async {
              if (!await context.read<UrlLaunchService>().openGoogleMaps(
                content.name,
                content.city.target?.name ?? 'Molise',
              )) {
                if (context.mounted) {
                  showSnackBar(
                    context: context,
                    textContent:
                        'Si è verificato un errore, riprova più tardi.',
                  );
                }
              }
            },
            icon: const Icon(Symbols.directions),
            label: const Text('Indicazioni'),
          ),
        ],
      ),
    );
  }
}
