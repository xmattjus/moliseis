import 'package:flutter/material.dart';
import 'package:moliseis/ui/core/themes/shapes.dart';

Future<T?> showCustomModalBottomSheet<T>({
  required BuildContext context,
  required WidgetBuilder builder,
  Clip clipBehavior = Clip.hardEdge,
  bool isScrollControlled = false,
  bool useSafeArea = true,
}) => showModalBottomSheet(
  context: context,
  builder: builder,
  backgroundColor: Theme.of(context).colorScheme.surface,
  shape: const RoundedRectangleBorder(
    borderRadius: BorderRadius.only(
      topLeft: Radius.circular(Shapes.extraLarge),
      topRight: Radius.circular(Shapes.extraLarge),
    ),
  ),
  clipBehavior: clipBehavior,
  constraints: const BoxConstraints(maxWidth: 720.0),
  isScrollControlled: isScrollControlled,
  useSafeArea: useSafeArea,
);
