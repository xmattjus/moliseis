import 'dart:collection' show UnmodifiableListView;

import 'package:flutter/material.dart';
import 'package:material_symbols_icons/symbols.dart';
import 'package:moliseis/domain/models/content_category.dart';
import 'package:moliseis/domain/models/content_type.dart';
import 'package:moliseis/ui/core/ui/app_bottom_sheet_drag_handle.dart';
import 'package:moliseis/ui/core/ui/app_bottom_sheet_title.dart';
import 'package:moliseis/ui/core/ui/app_show_modal_bottom_sheet.dart';
import 'package:moliseis/utils/enums.dart';
import 'package:moliseis/utils/extensions/extensions.dart';

class CategoryContentAndTypeSelection extends StatefulWidget {
  final Color? chipBackgroundColor;
  final Set<ContentCategory> selectedCategories;
  final Set<ContentType> selectedTypes;
  final void Function(Set<ContentCategory> categories)
  onContentSelectionChanged;
  final void Function(Set<ContentType> types) onTypeSelectionChanged;

  const CategoryContentAndTypeSelection({
    super.key,
    this.chipBackgroundColor,
    required this.selectedCategories,
    required this.selectedTypes,
    required this.onContentSelectionChanged,
    required this.onTypeSelectionChanged,
  });

  @override
  State<CategoryContentAndTypeSelection> createState() =>
      _CategoryContentAndTypeSelectionState();
}

class _CategoryContentAndTypeSelectionState
    extends State<CategoryContentAndTypeSelection> {
  late Set<ContentCategory> _selectedCategories;
  late Set<ContentType> _selectedTypes;

  @override
  void initState() {
    super.initState();
    _selectedCategories = Set.of(widget.selectedCategories);
    _selectedTypes = Set.of(widget.selectedTypes);
  }

  @override
  void didUpdateWidget(covariant CategoryContentAndTypeSelection oldWidget) {
    super.didUpdateWidget(oldWidget);

    if (oldWidget.selectedCategories != widget.selectedCategories) {
      _selectedCategories = Set.of(widget.selectedCategories);
    }

    if (oldWidget.selectedTypes != widget.selectedTypes) {
      _selectedTypes = Set.of(widget.selectedTypes);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 8.0, horizontal: 16.0),
      child: Wrap(
        spacing: 8.0,
        runSpacing: 8.0,
        children: <Widget>[
          InputChip(
            label: Text(
              _selectedTypes.containsAll({ContentType.event, ContentType.place})
                  ? 'Tipo'
                  : _selectedTypes.contains(ContentType.event)
                  ? 'Eventi'
                  : 'Luoghi',
            ),
            deleteIcon: const Icon(Symbols.arrow_drop_down),
            onDeleted: _onTypeChipPressed,
            deleteButtonTooltipMessage: 'Seleziona per tipo',
            onPressed: _onTypeChipPressed,
          ),
          InputChip(
            label: Text(
              _selectedCategories.length ==
                      ContentCategory.values.minusUnknown.length
                  ? 'Categoria'
                  : _selectedCategories.first.label +
                        (_selectedCategories.length > 1
                            ? ' + ${_selectedCategories.length - 1}'
                            : ''),
            ),
            deleteIcon: const Icon(Symbols.arrow_drop_down),
            onDeleted: _onCategoryChipPressed,
            deleteButtonTooltipMessage: 'Seleziona per categoria',
            onPressed: _onCategoryChipPressed,
          ),
        ],
      ),
    );
  }

  Future<void> _onTypeChipPressed() async {
    await _showAdaptiveSelectionWidget(
      title: 'Seleziona per tipo',
      children: UnmodifiableListView(
        ContentType.values.map<Widget>(
          (type) => _buildSelectionRow(
            label: type.label,
            itemKey: ValueKey<ContentType>(type),
            isSelected: _selectedTypes.contains(type),
            onChanged: (value) => _toggleItem(_selectedTypes, type, value),
          ),
        ),
      ),
    );

    if (mounted) {
      setState(() {
        // If the user has selected no types, resets to the default
        // selection of all types.
        if (_selectedTypes.isEmpty) {
          _selectedTypes.addAll(ContentType.values);
        }
      });

      widget.onTypeSelectionChanged.call(Set.from(_selectedTypes));
    }
  }

  Future<void> _onCategoryChipPressed() async {
    await _showAdaptiveSelectionWidget(
      title: 'Seleziona per categoria',
      children: UnmodifiableListView(
        ContentCategory.values.minusUnknown.map<Widget>(
          (category) => _buildSelectionRow(
            label: category.label,
            itemKey: ValueKey<ContentCategory>(category),
            isSelected: _selectedCategories.contains(category),
            onChanged: (value) =>
                _toggleItem(_selectedCategories, category, value),
          ),
        ),
      ),
    );

    if (mounted) {
      setState(() {
        // If the user has selected no categories, resets to the
        // default selection of all categories.
        if (_selectedCategories.isEmpty) {
          _selectedCategories.addAll(ContentCategory.values.minusUnknown);
        }
      });

      widget.onContentSelectionChanged.call(Set.from(_selectedCategories));
    }
  }

  Future<T?> _showAdaptiveSelectionWidget<T>({
    required String title,
    required List<Widget> children,
  }) async {
    if (context.windowSizeClass.isAtMost(WindowSizeClass.medium)) {
      return await _showGenericSelectionBottomSheet<T>(
        title: title,
        children: children,
      );
    } else {
      return await showDialog<T?>(
        context: context,
        builder: (context) => AlertDialog(
          title: Text(title, style: context.textTheme.bodyLarge),
          content: SingleChildScrollView(
            child: Column(mainAxisSize: MainAxisSize.min, children: children),
          ),
          actions: <Widget>[
            TextButton(
              onPressed: () => Navigator.of(context).pop(),
              child: const Text('Salva'),
            ),
          ],
        ),
      );
    }
  }

  Future<T?> _showGenericSelectionBottomSheet<T>({
    required String title,
    required List<Widget> children,
  }) => appShowModalBottomSheet<T?>(
    context: context,
    builder: (context) => SingleChildScrollView(
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: <Widget>[
            const Align(child: AppBottomSheetDragHandle()),
            const SizedBox(height: 16.0),
            AppBottomSheetTitle(
              title: title,
              tooltipMessage: 'Salva',
              icon: Symbols.check,
              onClose: () => Navigator.of(context).pop(),
            ),
            const SizedBox(height: 16.0),
            ...children,
            SizedBox(height: context.bottomPadding),
          ],
        ),
      ),
    ),
    isScrollControlled: true,
  );

  Widget _buildSelectionRow({
    required String label,
    required Key itemKey,
    required bool isSelected,
    required void Function(bool?) onChanged,
  }) {
    var selected = isSelected;
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      spacing: 16.0,
      children: <Widget>[
        Text(label),
        StatefulBuilder(
          builder: (_, setState) => Checkbox(
            key: itemKey,
            value: selected,
            onChanged: (value) {
              setState(() {
                selected = value ?? false;
                onChanged(value);
              });
            },
          ),
        ),
      ],
    );
  }

  void _toggleItem<T>(Set<T> set, T item, bool? value) {
    value ?? false ? set.add(item) : set.remove(item);
  }
}
