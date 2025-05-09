import 'package:flutter/material.dart';

class LinkTextButton extends StatelessWidget {
  /// Creates a [TextButton.icon] with the appropriate styling to be used as a
  /// link.
  const LinkTextButton({super.key, this.onPressed, required this.label});

  final void Function()? onPressed;
  final Widget label;

  @override
  Widget build(BuildContext context) {
    return TextButton.icon(
      icon: Transform.rotate(
        angle: -0.775,
        child: const Icon(Icons.arrow_forward),
      ),
      style: const ButtonStyle(
        visualDensity: VisualDensity.compact,
        tapTargetSize: MaterialTapTargetSize.shrinkWrap,
      ),
      onPressed: onPressed,
      label: label,
    );
  }
}
