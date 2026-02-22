import 'package:flutter/material.dart';
import 'package:moliseis/domain/models/content_category.dart';
import 'package:moliseis/utils/extensions/extensions.dart';

class CategoryButton extends StatelessWidget {
  const CategoryButton({
    super.key,
    required this.onPressed,
    required this.contentCategory,
  });

  final void Function() onPressed;
  final ContentCategory contentCategory;

  @override
  Widget build(BuildContext context) => Theme(
    data: context.theme.copyWith(
      colorScheme: context.appColorSchemes.byCategory(contentCategory),
    ),
    child: FilledButton.tonalIcon(
      onPressed: onPressed,
      icon: Icon(contentCategory.icon, weight: 500),
      label: Text(contentCategory.label, overflow: TextOverflow.ellipsis),
    ),
  );
}
