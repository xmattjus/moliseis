import 'package:flutter/material.dart';
import 'package:moliseis/utils/constants.dart';

class HorizontalButtonList extends StatelessWidget {
  const HorizontalButtonList({super.key, this.padding, required this.items});

  final EdgeInsetsGeometry? padding;

  final List<Widget> items;

  @override
  Widget build(BuildContext context) {
    assert(items.isNotEmpty, 'The items list cannot be empty.');

    // Calculates the height including padding.
    final height = padding != null
        ? padding!.vertical + kButtonHeight
        : kButtonHeight;

    return SizedBox(
      height: height,
      child: ListView.separated(
        scrollDirection: Axis.horizontal,
        padding: padding,
        itemBuilder: (context, index) => items[index],
        separatorBuilder: (context, index) => const SizedBox(width: 8.0),
        itemCount: items.length,
        clipBehavior: Clip.none,
      ),
    );
  }
}
