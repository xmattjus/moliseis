import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';

class EmptyBox extends LeafRenderObjectWidget {
  const EmptyBox({super.key});

  @override
  RenderObject createRenderObject(BuildContext context) => RenderConstrainedBox(
    additionalConstraints: const BoxConstraints.tightFor(width: 0, height: 0),
  );

  @override
  String toStringShort() {
    var type = 'EmptyBox';
    assert(() {
      type = runtimeType.toString();
      return true;
    }());

    return key == null ? type : '$type-$key';
  }
}
