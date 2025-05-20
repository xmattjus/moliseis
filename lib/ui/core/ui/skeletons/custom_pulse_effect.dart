import 'package:flutter/material.dart';
import 'package:skeletonizer/skeletonizer.dart';

PaintingEffect customPulseEffect({required BuildContext context}) {
  final colorScheme = Theme.of(context).colorScheme;
  return PulseEffect(
    from: colorScheme.surfaceContainerHigh,
    to: colorScheme.surfaceContainerLow,
  );
}
