import 'package:flutter/material.dart';
import 'package:moliseis/utils/constants.dart';

class InformationGrid extends StatelessWidget {
  final bool _isSliver;
  final List<Widget> children;

  const InformationGrid({super.key, required this.children})
    : _isSliver = false;

  const InformationGrid.sliver({super.key, required this.children})
    : _isSliver = true;

  @override
  Widget build(BuildContext context) {
    const gridDelegate = SliverGridDelegateWithFixedCrossAxisCount(
      mainAxisSpacing: 8.0,
      crossAxisSpacing: 8.0,
      mainAxisExtent: kGridViewCardHeight / 1.5,
      crossAxisCount: 3,
    );
    final itemCount = children.length;

    return _isSliver
        ? SliverGrid(
            delegate: SliverChildBuilderDelegate((context, index) {
              return children[index];
            }, childCount: itemCount),
            gridDelegate: gridDelegate,
          )
        : GridView.builder(
            gridDelegate: gridDelegate,
            itemCount: itemCount,
            itemBuilder: (context, index) {
              return children[index];
            },
          );
  }
}
