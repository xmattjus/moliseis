import 'package:flutter/material.dart';
import 'package:moliseis/domain/models/event/event_content.dart';
import 'package:moliseis/domain/models/place/place_content.dart';
import 'package:moliseis/ui/detail/view_models/detail_view_model.dart';
import 'package:moliseis/ui/detail/widgets/components/event_dates_information.dart';
import 'package:moliseis/ui/detail/widgets/components/information_grid.dart';
import 'package:moliseis/utils/constants.dart';

/// A widget that displays supplementary information for content details.
///
/// This widget shows additional information cards including:
/// - Street address information (loaded asynchronously from coordinates)
/// - Weather forecast data (loaded asynchronously)
/// - Event date details (for EventContent only)
///
/// The widget automatically triggers data loading for street address and
/// weather information when it initializes, using the content's coordinates.
/// It displays loading skeletons while data is being fetched and handles
/// error states by showing empty boxes.
class SupplementaryInformation extends StatefulWidget {
  final DetailViewModel viewModel;

  const SupplementaryInformation({super.key, required this.viewModel});

  @override
  State<SupplementaryInformation> createState() =>
      _SupplementaryInformationState();
}

/// State class for [SupplementaryInformation] that manages asynchronous data loading.
///
/// This class is responsible for triggering the loading of street address
/// and weather forecast data when the widget is first displayed. It uses
/// the ViewModel's command pattern to execute these operations and listens
/// for their completion states to update the UI accordingly.
class _SupplementaryInformationState extends State<SupplementaryInformation> {
  @override
  Widget build(BuildContext context) {
    final content = widget.viewModel.content is EventContent
        ? widget.viewModel.content as EventContent
        : widget.viewModel.content as PlaceContent;

    return SliverPadding(
      padding: const EdgeInsetsDirectional.fromSTEB(16.0, 0, 16.0, 16.0),
      sliver: SliverMainAxisGroup(
        slivers: <Widget>[
          if (content is EventContent)
            SliverToBoxAdapter(
              child: ConstrainedBox(
                constraints: const BoxConstraints(
                  maxHeight: kInformationCardHeight,
                ),
                child: EventDatesInformation(
                  startDate: content.startDate,
                  endDate: content.endDate,
                ),
              ),
            ),
          const InformationGrid.sliver(children: <Widget>[]),
        ],
      ),
    );
  }
}
