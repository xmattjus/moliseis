import 'package:flutter/widgets.dart';
import 'package:moliseis/domain/models/content_base.dart';
import 'package:moliseis/domain/models/place.dart';
import 'package:moliseis/ui/core/ui/app_bottom_sheet_title.dart';
import 'package:moliseis/ui/core/ui/content/nearby_content_horizontal_list.dart';
import 'package:moliseis/ui/geo_map/view_models/geo_map_view_model.dart';
import 'package:moliseis/utils/result_command.dart';

/// Shows the default geo-map explore view inside the bottom sheet.
class GeoMapModalExplore extends StatelessWidget {
  const GeoMapModalExplore({
    required this.onNearContentPressed,
    required this.viewModel,
    super.key,
  });

  /// Returns the [Place] Id that has been tapped on.
  final void Function(ContentBase content) onNearContentPressed;

  final GeoMapViewModel viewModel;

  @override
  Widget build(BuildContext context) {
    final target = viewModel.nearbyTarget;
    return SliverList.list(
      children: <Widget>[
        const Padding(
          padding: EdgeInsets.symmetric(horizontal: 16),
          child: AppBottomSheetTitle(title: 'Esplora i dintorni', icon: null),
        ),
        const SizedBox(height: 16),
        NearbyContentHorizontalList(
          onPressed: onNearContentPressed,
          loadListenable: viewModel,
          loadKey: (viewModel, target),
          onLoad: () {
            if (target != null) viewModel.requestNearby(target);
          },
          onRetry: () {
            if (target != null) viewModel.requestNearby(target, retry: true);
          },
          readState: () {
            final terminal = viewModel.nearbyTerminal;
            if (target != viewModel.nearbyTarget || terminal == null) {
              return (pending: true, items: const <ContentBase>[], error: null);
            }
            final outcome = terminal.data?.getOrNull();
            return (
              pending: false,
              items: outcome?.items ?? const <ContentBase>[],
              error:
                  outcome?.firstError ??
                  terminal.domainError ??
                  terminal.unexpectedError,
            );
          },
        ),
      ],
    );
  }
}
