import 'package:flutter/material.dart';
import 'package:moliseis/domain/models/content_category.dart';
import 'package:moliseis/ui/core/themes/color_schemes.dart';
import 'package:moliseis/utils/extensions.dart';

class CategoryButton extends StatelessWidget {
  const CategoryButton({
    super.key,
    required this.onPressed,
    required this.contentCategory,
  });

  final void Function() onPressed;
  final ContentCategory contentCategory;

  @override
  Widget build(BuildContext context) {
    return Theme(
      data: Theme.of(context).copyWith(
        colorScheme: CustomColorSchemes.fromContentCategory(
          contentCategory,
          Theme.of(context).brightness,
        ),
      ),
      child: FilledButton.tonalIcon(
        onPressed: onPressed,
        icon: Icon(contentCategory.iconAlt),
        label: Text(contentCategory.label, overflow: TextOverflow.ellipsis),
      ),
    );
  }
}
