import 'package:flutter/material.dart';
import 'package:moliseis/domain/models/core/content_base.dart';
import 'package:moliseis/domain/models/event/event_content.dart';
import 'package:moliseis/ui/core/themes/shapes.dart';
import 'package:moliseis/ui/core/ui/content/content_base_card_grid_item.dart';
import 'package:moliseis/ui/core/ui/content/event_content_start_date_time.dart';
import 'package:moliseis/ui/core/ui/empty_view.dart';
import 'package:moliseis/ui/core/ui/skeletons/custom_pulse_effect.dart';
import 'package:moliseis/ui/core/ui/skeletons/skeleton_content_grid_item.dart';
import 'package:moliseis/ui/core/ui/text_section_divider.dart';
import 'package:moliseis/ui/favourite/widgets/favourite_button.dart';
import 'package:moliseis/utils/command.dart';
import 'package:moliseis/utils/constants.dart';
import 'package:skeletonizer/skeletonizer.dart';

/// A reusable horizontal list widget that displays nearby content.
///
/// This widget can work with different view models as long as they provide:
/// - A [Command1] for loading nearby content by coordinates
/// - A list of nearby content items
class NearbyContentHorizontalList extends StatefulWidget {
  const NearbyContentHorizontalList({
    super.key,
    required this.coordinates,
    required this.onPressed,
    required this.loadNearContentCommand,
    required this.nearContent,
  });

  /// The coordinates to search nearby content from.
  final List<double> coordinates;

  /// Callback when a content item is pressed.
  final void Function(ContentBase content) onPressed;

  /// The command to execute for loading nearby content.
  final Command1<void, List<double>> loadNearContentCommand;

  /// The list of nearby content items.
  final List<ContentBase> nearContent;

  @override
  State<NearbyContentHorizontalList> createState() =>
      _NearbyContentHorizontalListState();
}

class _NearbyContentHorizontalListState
    extends State<NearbyContentHorizontalList> {
  @override
  void initState() {
    super.initState();
    widget.loadNearContentCommand.execute(widget.coordinates);
  }

  @override
  void didUpdateWidget(covariant NearbyContentHorizontalList oldWidget) {
    super.didUpdateWidget(oldWidget);

    // Reload data if coordinates changed
    if (oldWidget.coordinates.length != widget.coordinates.length ||
        (widget.coordinates.isNotEmpty &&
            oldWidget.coordinates.isNotEmpty &&
            (oldWidget.coordinates.first != widget.coordinates.first ||
                oldWidget.coordinates.last != widget.coordinates.last))) {
      widget.loadNearContentCommand.execute(widget.coordinates);
    }
  }

  @override
  Widget build(BuildContext context) {
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
            listenable: widget.loadNearContentCommand,
            builder: (context, child) {
              if (widget.loadNearContentCommand.completed) {
                final nearContent = widget.nearContent;

                if (nearContent.isEmpty) {
                  return const EmptyView(
                    text: Text('Nessun luogo trovato nelle vicinanze.'),
                  );
                }

                return ListView.separated(
                  scrollDirection: Axis.horizontal,
                  padding: padding,
                  itemBuilder: (_, index) {
                    final content = nearContent[index];

                    return ContentBaseCardGridItem(
                      content,
                      width: kGridViewCardWidth,
                      onPressed: (ContentBase content) =>
                          widget.onPressed(content),
                      verticalTrailing: content is EventContent
                          ? EventContentStartDateTime(content)
                          : null,
                      horizontalTrailing: FavouriteButton(
                        color: Colors.white,
                        content: content,
                        radius: Shapes.small,
                      ),
                    );
                  },
                  separatorBuilder: (_, _) => const SizedBox(width: 8.0),
                  itemCount: nearContent.length,
                );
              }

              if (widget.loadNearContentCommand.error) {
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
