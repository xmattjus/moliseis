import 'dart:io' show Platform;

import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:moliseis/domain/models/core/content_category.dart';
import 'package:moliseis/domain/models/core/content_type.dart';
import 'package:moliseis/ui/core/ui/bottom_sheet_drag_handle.dart';
import 'package:moliseis/ui/core/ui/custom_modal_bottom_sheet.dart';
import 'package:moliseis/utils/extensions.dart';

class CategorySelectionList extends StatefulWidget {
  final Color? chipBackgroundColor;
  final void Function(Set<ContentCategory> selectedCategories)
  onCategoriesSelectionChanged;
  final void Function(Set<ContentType> selectedTypes) onTypesSelectionChanged;
  final Set<ContentCategory> selectedCategories;

  const CategorySelectionList({
    super.key,
    this.chipBackgroundColor,
    required this.onCategoriesSelectionChanged,
    required this.onTypesSelectionChanged,
    this.selectedCategories = const {},
  });

  @override
  State<CategorySelectionList> createState() => _CategorySelectionListState();
}

class _CategorySelectionListState extends State<CategorySelectionList> {
  var _selectedCategories = const <ContentCategory>{};
  final _selectedTypes = {ContentType.place, ContentType.event};

  @override
  void initState() {
    super.initState();

    if (widget.selectedCategories.isNotEmpty) {
      _selectedCategories = widget.selectedCategories;
    } else {
      _selectedCategories = ContentCategory.values.minusUnknown.toSet();
    }
  }

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      height: 64.0,
      child: ListView(
        padding: const EdgeInsets.symmetric(vertical: 8.0, horizontal: 16.0),
        scrollDirection: Axis.horizontal,
        children: <Widget>[
          RawChip(
            label: Text(
              _selectedTypes.containsAll({ContentType.event, ContentType.place})
                  ? 'Tipo'
                  : _selectedTypes.contains(ContentType.event)
                  ? 'Eventi'
                  : 'Luoghi',
            ),
            deleteIcon: const Icon(Icons.arrow_drop_down),
            onDeleted: _onTypeChipPressed,
            deleteButtonTooltipMessage: 'Seleziona per tipo',
            onPressed: _onTypeChipPressed,
          ),
          const SizedBox(width: 8.0),
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
            deleteIcon: const Icon(Icons.arrow_drop_down),
            onDeleted: _onCategoryChipPressed,
            deleteButtonTooltipMessage: 'Seleziona per categoria',
            onPressed: _onCategoryChipPressed,
          ),
        ],
      ),
    );
  }

  Future<void> _onTypeChipPressed() async {
    await _showGenericSelectionBottomSheet(
      title: 'Seleziona per tipo',
      children: ContentType.values
          .map<Widget>(
            (type) => ListTile(
              title: Text(type.label),
              trailing: StatefulBuilder(
                builder: (_, setState) {
                  return _SelectionWidget(
                    key: ValueKey<ContentType>(type),
                    isSelected: _selectedTypes.contains(type),
                    onChanged: (value) {
                      _changeSelectedTypes(value, type, setState);
                    },
                  );
                },
              ),
            ),
          )
          .toList(growable: false),
    );

    if (mounted) {
      setState(() {
        // If the user has selected no types, resets to the default
        // selection of all types.
        if (_selectedTypes.isEmpty) {
          _selectedTypes.addAll([ContentType.place, ContentType.event]);
        }
      });

      widget.onTypesSelectionChanged.call(_selectedTypes);
    }
  }

  Future<void> _onCategoryChipPressed() async {
    await _showGenericSelectionBottomSheet(
      title: 'Seleziona per categoria',
      children: ContentCategory.values.minusUnknown
          .map<Widget>(
            (category) => ListTile(
              title: Text(category.label),
              trailing: StatefulBuilder(
                builder: (_, setState) {
                  return _SelectionWidget(
                    key: ValueKey<ContentCategory>(category),
                    isSelected: _selectedCategories.contains(category),
                    onChanged: (value) {
                      _changeSelectedCategories(value, category, setState);
                    },
                  );
                },
              ),
            ),
          )
          .toList(growable: false),
    );

    if (mounted) {
      setState(() {
        // If the user has selected no categories, resets to the
        // default selection of all categories.
        if (_selectedCategories.isEmpty) {
          _selectedCategories.addAll(ContentCategory.values.minusUnknown);
        }
      });

      widget.onCategoriesSelectionChanged.call(_selectedCategories);
    }
  }

  Future<T?> _showGenericSelectionBottomSheet<T>({
    required String title,
    required List<Widget> children,
  }) {
    return showCustomModalBottomSheet(
      context: context,
      builder: (_) {
        return DraggableScrollableSheet(
          expand: false,
          builder: (_, scrollController) {
            return ListView(
              controller: scrollController,
              children: <Widget>[
                const BottomSheetDragHandle(),
                AppBar(
                  leading: IconButton(
                    onPressed: () => Navigator.of(context).pop(true),
                    tooltip: 'Chiudi',
                    icon: const Icon(Icons.close),
                  ),
                  title: Text(
                    title,
                    style: Theme.of(context).textTheme.bodyLarge,
                  ),
                  forceMaterialTransparency: true,
                ),
                ...children,
                const SizedBox(height: 16.0),
              ],
            );
          },
        );
      },
      isScrollControlled: true,
    );
  }

  void _changeSelectedTypes(
    bool? value,
    ContentType type,
    void Function(void Function()) setState,
  ) => setState(() {
    final test = value ?? false;

    if (test) {
      _selectedTypes.add(type);
    } else {
      _selectedTypes.remove(type);
    }
  });

  void _changeSelectedCategories(
    bool? value,
    ContentCategory category,
    void Function(void Function()) setState,
  ) => setState(() {
    final test = value ?? false;

    if (test) {
      _selectedCategories.add(category);
    } else {
      _selectedCategories.remove(category);
    }
  });
}

class _SelectionWidget extends StatelessWidget {
  const _SelectionWidget({
    super.key,
    required this.isSelected,
    required this.onChanged,
  });

  final bool isSelected;
  final void Function(bool? value) onChanged;

  @override
  Widget build(BuildContext context) => Platform.isIOS
      ? CupertinoSwitch(value: isSelected, onChanged: onChanged)
      : Checkbox(value: isSelected, onChanged: onChanged);
}
