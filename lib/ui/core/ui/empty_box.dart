import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';

class EmptyBox extends LeafRenderObjectWidget {
  const EmptyBox({super.key});

  @override
  RenderObject createRenderObject(BuildContext context) => RenderConstrainedBox(
    additionalConstraints: const BoxConstraints.tightFor(width: 0, height: 0),
  );

  /// Returns a short description of this widget.
  ///
  /// Reports the concrete runtime type in debug builds so subclasses can be
  /// told apart while debugging, and the stable 'EmptyBox' name in release
  /// builds.
  @override
  String toStringShort() {
    var type = 'EmptyBox';
    // In debug builds, report the concrete runtime type (also of subclasses)
    // instead of the stable 'EmptyBox' name. The assert statement is removed
    // in release builds, where the fixed string is used.
    assert(() {
      type = runtimeType.toString();
      return true;
    }(), 'runtimeType is only assigned in debug builds');

    return key == null ? type : '$type-$key';
  }
}
