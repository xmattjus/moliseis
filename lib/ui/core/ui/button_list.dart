import 'package:flutter/material.dart';
import 'package:moliseis/utils/constants.dart';

class ButtonList extends StatelessWidget {
  const ButtonList({super.key, this.padding, required this.items});

  final EdgeInsetsGeometry? padding;

  final List<Widget> items;

  @override
  Widget build(BuildContext context) {
    /// Calculates the total widget height.
    final height = padding != null
        ? padding!.vertical + kButtonHeight
        : kButtonHeight;

    return SizedBox(
      height: height,
      child: ListView.separated(
        padding: padding,
        scrollDirection: Axis.horizontal,
        itemBuilder: (context, index) => items[index],
        separatorBuilder: (context, index) => const SizedBox(width: 8.0),
        itemCount: items.length,
      ),
    );
  }
}
