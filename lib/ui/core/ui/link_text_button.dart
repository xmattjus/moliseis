import 'package:flutter/material.dart';

// TODO: Add Widget 'child' (to be used as label.).
class LinkTextButton extends StatelessWidget {
  final int? id;
  final void Function()? onPressed;

  /// Creates a [TextButton.icon] with the appropriate styling to be used as a
  /// link to an Attraction Post screen.
  const LinkTextButton(this.id, {super.key, this.onPressed});

  @override
  Widget build(BuildContext context) {
    return TextButton.icon(
      icon: Transform.rotate(
        angle: -0.775,
        child: const Icon(Icons.arrow_forward),
      ),
      // iconAlignment: IconAlignment.end,
      style: const ButtonStyle(
        visualDensity: VisualDensity.compact,
        tapTargetSize: MaterialTapTargetSize.shrinkWrap,
      ),
      onPressed: () {
        if (id != null) {
          onPressed?.call();
        }
      },
      label: const Text('Apri dettagli'),
    );
  }
}
