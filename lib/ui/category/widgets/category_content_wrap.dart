import 'dart:collection' show UnmodifiableListView;

import 'package:flutter/material.dart';
import 'package:moliseis/domain/models/content_category.dart';
import 'package:moliseis/ui/category/widgets/category_chip.dart';
import 'package:moliseis/utils/extensions/extensions.dart';

class CategoryContentWrap extends StatelessWidget {
  final Color? chipBackgroundColor;
  final ContentCategory? selectedCategory;
  final void Function(ContentCategory)? onCategoryDeleted;
  final void Function(ContentCategory) onCategorySelected;

  const CategoryContentWrap({
    super.key,
    this.chipBackgroundColor,
    this.selectedCategory,
    this.onCategoryDeleted,
    required this.onCategorySelected,
  });

  @override
  Widget build(BuildContext context) {
    return Wrap(
      spacing: 8.0,
      runSpacing: 8.0,
      children: UnmodifiableListView(
        ContentCategory.values.minusUnknown.map((category) {
          final isSelected = selectedCategory == category;
          return CategoryChip(
            category,
            backgroundColor: chipBackgroundColor,
            isSelected: isSelected,
            onDeleted: onCategoryDeleted != null && isSelected
                ? () {
                    onCategoryDeleted!(category);
                  }
                : null,
            onPressed: () => onCategorySelected(category),
          );
        }),
      ),
    );
  }
}
