import 'package:flutter/material.dart';
import 'package:moliseis/ui/core/ui/custom_ink_well.dart';
import 'package:moliseis/ui/core/ui/empty_box.dart';

enum _CardBaseType { elevated, filled, outlined }

enum CardBaseActionAlignment { start, center, end }

class CardBase extends StatelessWidget {
  const CardBase({
    super.key,
    this.width,
    this.height,
    this.color,
    this.elevation,
    this.shape,
    this.onPressed,
    this.actions = const <Widget>[],
    this.actionAlignment = CardBaseActionAlignment.center,
    required this.child,
  }) : _variant = _CardBaseType.elevated;

  const CardBase.filled({
    super.key,
    this.width,
    this.height,
    this.color,
    this.elevation,
    this.shape,
    this.onPressed,
    this.actions = const <Widget>[],
    this.actionAlignment = CardBaseActionAlignment.center,
    required this.child,
  }) : _variant = _CardBaseType.filled;

  const CardBase.outlined({
    super.key,
    this.width,
    this.height,
    this.color,
    this.elevation,
    this.shape,
    this.onPressed,
    this.actions = const <Widget>[],
    this.actionAlignment = CardBaseActionAlignment.center,
    required this.child,
  }) : _variant = _CardBaseType.outlined;

  /// If non-null, requires the child to have exactly this width.
  final double? width;

  /// If non-null, requires the child to have exactly this height.
  final double? height;

  /// The card's background color.
  final Color? color;

  /// The z-coordinate at which to place this card. This controls the size of
  /// the shadow below the card.
  ///
  /// Defines the card's [Material.elevation].
  ///
  /// If this property is null then [CardTheme.elevation] of
  /// [ThemeData.cardTheme] is used. If that's null, the default value is 1.0.
  final double? elevation;

  /// The shape of the card's [Material].
  ///
  /// Defines the card's [Material.shape].
  ///
  /// If this property is null then [CardTheme.shape] of [ThemeData.cardTheme]
  /// is used. If that's null then the shape will be a [RoundedRectangleBorder]
  /// with a circular corner radius of 12.0 and if [ThemeData.useMaterial3] is
  /// false, then the circular corner radius will be 4.0.
  final ShapeBorder? shape;

  /// Called when the user presses this part of the material.
  final void Function()? onPressed;

  final List<Widget> actions;

  final CardBaseActionAlignment actionAlignment;

  /// The widget below this widget in the tree.
  ///
  /// {@macro flutter.widgets.ProxyWidget.child}
  final Widget child;

  final _CardBaseType _variant;

  @override
  Widget build(BuildContext context) {
    final card = switch (_variant) {
      _CardBaseType.elevated => Card(
        color: color,
        elevation: elevation,
        shape: shape,
        margin: EdgeInsets.zero,
        clipBehavior: Clip.antiAlias,
        child: ExcludeFocusTraversal(
          excluding: onPressed != null,
          child: child,
        ),
      ),
      _CardBaseType.filled => Card.filled(
        color: color,
        elevation: elevation,
        shape: shape,
        margin: EdgeInsets.zero,
        clipBehavior: Clip.antiAlias,
        child: ExcludeFocusTraversal(
          excluding: onPressed != null,
          child: child,
        ),
      ),
      _CardBaseType.outlined => Card.outlined(
        color: color,
        elevation: elevation,
        shape: shape,
        margin: EdgeInsets.zero,
        clipBehavior: Clip.antiAlias,
        child: ExcludeFocusTraversal(
          excluding: onPressed != null,
          child: child,
        ),
      ),
    };

    Widget ink = const EmptyBox();
    Widget act = const EmptyBox();

    /// Creates a pressable ink layer on top of the card content if the onTap
    /// callback has been defined.
    if (onPressed != null) {
      ink = Positioned.fill(
        child: Material(
          type: MaterialType.transparency,
          child: CustomInkWell(onPressed: onPressed!, shape: shape),
        ),
      );
    }

    if (actions.isNotEmpty) {
      act = Positioned.fill(
        left: null,
        top:
            (actionAlignment == CardBaseActionAlignment.start ||
                actionAlignment == CardBaseActionAlignment.center)
            ? 0
            : null,
        bottom:
            (actionAlignment == CardBaseActionAlignment.end ||
                actionAlignment == CardBaseActionAlignment.center)
            ? 0
            : null,
        child: Row(children: actions),
      );
    }

    final content = SizedBox(width: width, height: height, child: card);

    return Stack(children: [content, ink, act]);
  }
}
