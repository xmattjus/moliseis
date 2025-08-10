/*
import 'package:flutter/material.dart';
import 'package:moliseis/domain/models/core/content_base.dart';
import 'package:moliseis/domain/models/place/place.dart';
import 'package:moliseis/ui/core/ui/content/place_content_card_grid_item.dart';
import 'package:moliseis/ui/core/ui/empty_box.dart';
import 'package:moliseis/ui/core/ui/empty_view.dart';
import 'package:moliseis/ui/core/ui/skeletons/custom_pulse_effect.dart';
import 'package:moliseis/ui/core/ui/skeletons/skeleton_content_grid_item.dart';
import 'package:moliseis/ui/core/ui/text_section_divider.dart';
import 'package:moliseis/ui/explore/view_models/explore_view_model.dart';
import 'package:moliseis/utils/constants.dart';
import 'package:provider/provider.dart';
import 'package:skeletonizer/skeletonizer.dart';

class NearbyContentHorizontalList extends StatefulWidget {
  const NearbyContentHorizontalList({
    super.key,
    required this.coordinates,
    required this.onPressed,
  });

  /// The list of coordinates to search near [Place]s from.
  final List<double> coordinates;

  final void Function(ContentBase content) onPressed;

  @override
  State<NearbyContentHorizontalList> createState() =>
      _NearbyContentHorizontalListState();
}

class _NearbyContentHorizontalListState
    extends State<NearbyContentHorizontalList> {
  late final ExploreViewModel _exploreViewModel;

  @override
  void initState() {
    super.initState();

    ///
    _exploreViewModel = context.read();

    // FIXME: setState() or markNeedsBuild() called during build.
    Future.delayed(Duration.zero, () {
      _exploreViewModel.loadNear.execute(widget.coordinates);
    });
  }

  @override
  void didUpdateWidget(covariant NearbyContentHorizontalList oldWidget) {
    super.didUpdateWidget(oldWidget);

    if (widget.coordinates[0] != oldWidget.coordinates[0] ||
        widget.coordinates[1] != oldWidget.coordinates[1]) {
      // FIXME: setState() or markNeedsBuild() called during build.
      Future.delayed(Duration.zero, () {
        _exploreViewModel.loadNear.execute(widget.coordinates);
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    if (widget.coordinates.isEmpty) {
      return const EmptyBox();
    }

    const padding = EdgeInsetsDirectional.fromSTEB(16.0, 0, 16.0, 4.0);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      mainAxisSize: MainAxisSize.min,
      children: <Widget>[
        const Padding(
          padding: EdgeInsetsDirectional.fromSTEB(16.0, 0, 16.0, 8.0),
          child: TextSectionDivider('Nelle vicinanze'),
        ),
        SizedBox(
          height: kGridViewCardHeight,
          child: ListenableBuilder(
            listenable: _exploreViewModel.loadNear,
            builder: (context, child) {
              if (_exploreViewModel.loadNear.completed) {
                if (_exploreViewModel.near.isEmpty) {
                  return const EmptyView(
                    text: Text('Nessun luogo trovato nelle vicinanze.'),
                  );
                }

                return ListView.separated(
                  scrollDirection: Axis.horizontal,
                  padding: padding,
                  itemBuilder: (_, index) => PlaceContentCardGridItem(
                    _exploreViewModel.near[index],
                    width: kGridViewCardWidth,
                    onPressed: () =>
                        widget.onPressed(_exploreViewModel.near[index]),
                  ),
                  separatorBuilder: (_, _) => const SizedBox(width: 8.0),
                  itemCount: _exploreViewModel.near.length,
                );
              }

              if (_exploreViewModel.loadNear.error) {
                return const EmptyView.error(
                  text: Text(
                    'Si è verificato un errore durante il caricamento.',
                  ),
                );
              }

              return Skeletonizer(
                effect: CustomPulseEffect(context: context),
                child: ListView.separated(
                  scrollDirection: Axis.horizontal,
                  padding: padding,
                  itemBuilder: (_, _) => const SkeletonContentGridItem(
                    width: kGridViewCardWidth,
                    height: kGridViewCardHeight,
                  ),
                  separatorBuilder: (_, _) => const SizedBox(width: 8.0),
                  itemCount: 5,
                ),
              );
            },
          ),
        ),
      ],
    );
  }
}
*/
