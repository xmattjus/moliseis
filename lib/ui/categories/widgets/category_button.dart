import 'package:flutter/material.dart';
import 'package:moliseis/domain/models/attraction/attraction_type.dart';
import 'package:moliseis/utils/extensions.dart';

class CategoryButton extends StatelessWidget {
  const CategoryButton({
    super.key,
    required this.type,
    required this.onPressed,
  });

  final AttractionType type;
  final void Function() onPressed;

  @override
  Widget build(BuildContext context) {
    return ElevatedButton.icon(
      onPressed: () => onPressed.call(),
      style: const ButtonStyle().byAttractionType(
        type,
        primary: Theme.of(context).colorScheme.primary,
        brightness: Theme.of(context).brightness,
      ),
      icon: Icon(type.getIcon()),
      label: Text(type.readableName),
    );
  }
}
