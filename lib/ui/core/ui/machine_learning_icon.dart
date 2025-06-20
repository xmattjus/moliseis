import 'package:flutter/material.dart';
import 'package:material_symbols_icons/symbols.dart';

class MachineLearningIcon extends StatelessWidget {
  const MachineLearningIcon({super.key});

  @override
  Widget build(BuildContext context) {
    return ShaderMask(
      blendMode: BlendMode.srcIn,
      shaderCallback: (bounds) => LinearGradient(
        begin: Alignment.topLeft,
        end: Alignment.bottomRight,
        colors: [Colors.deepPurpleAccent.shade100, Colors.deepPurple],
      ).createShader(bounds),
      child: const Icon(Symbols.magic_button_rounded),
    );
  }
}
