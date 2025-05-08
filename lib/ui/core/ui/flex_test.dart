import 'package:flutter/material.dart';

// TODO(xmattjus): better naming.
class FlexTest extends StatelessWidget {
  final Widget left;
  final Widget right;

  const FlexTest({super.key, required this.left, required this.right});

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: <Widget>[
        Expanded(child: Align(alignment: Alignment.topLeft, child: left)),
        Align(alignment: Alignment.topRight, child: right),
      ],
    );
  }
}
