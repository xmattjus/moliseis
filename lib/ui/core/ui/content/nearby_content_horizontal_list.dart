import 'package:flutter/material.dart';
import 'package:latlong2/latlong.dart';
import 'package:moliseis/domain/models/content_base.dart';
import 'package:moliseis/domain/models/event_content.dart';
import 'package:moliseis/ui/core/ui/blurred_box.dart';
import 'package:moliseis/ui/core/ui/content/content_base_card_grid_item.dart';
import 'package:moliseis/ui/core/ui/content/content_event_card_grid_item.dart';
import 'package:moliseis/ui/core/ui/empty_view.dart';
import 'package:moliseis/ui/core/ui/skeletons/app_pulse_effect.dart';
import 'package:moliseis/ui/core/ui/skeletons/skeleton_content_grid_item.dart';
import 'package:moliseis/ui/core/ui/text_section_divider.dart';
import 'package:moliseis/ui/favourite/widgets/favourite_button.dart';
import 'package:moliseis/utils/command.dart';
import 'package:moliseis/utils/constants.dart';
import 'package:moliseis/utils/extensions/extensions.dart';
import 'package:skeletonizer/skeletonizer.dart';

/// A reusable horizontal list widget that displays nearby content.
///
/// This widget can work with different view models as long as they provide:
/// - A [Command1] for loading nearby content by coordinates
/// - A list of nearby content items
class NearbyContentHorizontalList extends StatefulWidget {
  /// The coordinates to search nearby content from.
  final LatLng coordinates;

  /// Callback when a content item is pressed.
  final void Function(ContentBase content) onPressed;

  /// The command to execute for loading nearby content.
  final Command1<void, LatLng> loadNearContentCommand;

  /// The list of nearby content items.
  final List<ContentBase> nearContent;

  const NearbyContentHorizontalList({
    super.key,
    required this.coordinates,
    required this.onPressed,
    required this.loadNearContentCommand,
    required this.nearContent,
  });

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
    if (oldWidget.coordinates != widget.coordinates ||
        widget.coordinates.isValid) {
      widget.loadNearContentCommand.execute(widget.coordinates);
    }
  }

  @override
  Widget build(BuildContext context) {
    final colorScheme = context.colorScheme;

    const padding = EdgeInsetsDirectional.fromSTEB(16.0, 0, 16.0, 4.0);
    const skeletonItems = 5;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      mainAxisSize: MainAxisSize.min,
      children: <Widget>[
        const TextSectionDivider(
          'Nelle vicinanze',
          padding: EdgeInsetsDirectional.fromSTEB(16.0, 0, 16.0, 8.0),
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

                    if (content is EventContent) {
                      return ContentEventCardGridItem(
                        event: content,
                        onPressed: widget.onPressed,
                      );
                    }

                    return ContentBaseCardGridItem(
                      content,
                      width: kGridViewCardWidth,
                      onPressed: (ContentBase content) =>
                          widget.onPressed(content),
                      trailing: Wrap(
                        alignment: WrapAlignment.end,
                        spacing: 4.0,
                        runSpacing: 4.0,
                        verticalDirection: VerticalDirection.up,
                        children: <Widget>[
                          BlurredBox(
                            child: FavouriteButton(
                              color: Colors.white,
                              content: content,
                              borderRadius:
                                  context.appShapes.circular.cornerSmall,
                            ),
                          ),
                        ],
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
                effect: AppPulseEffect(
                  from: colorScheme.surfaceContainerHigh,
                  to: colorScheme.surfaceContainerLow,
                ),
                child: ListView.separated(
                  scrollDirection: Axis.horizontal,
                  padding: padding,
                  itemBuilder: (_, _) => const SkeletonContentGridItem(
                    width: kGridViewCardWidth,
                    height: kGridViewCardHeight,
                    elevation: 0,
                  ),
                  separatorBuilder: (_, _) => const SizedBox(width: 8.0),
                  itemCount: skeletonItems,
                ),
              );
            },
          ),
        ),
      ],
    );
  }
}
