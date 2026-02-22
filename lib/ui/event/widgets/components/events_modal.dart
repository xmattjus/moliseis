import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:moliseis/routing/route_names.dart';
import 'package:moliseis/ui/core/ui/app_bottom_sheet_drag_handle.dart';
import 'package:moliseis/ui/core/ui/app_bottom_sheet_title.dart';
import 'package:moliseis/ui/core/ui/content/content_sliver_grid.dart';
import 'package:moliseis/ui/core/ui/empty_view.dart';
import 'package:moliseis/ui/core/ui/skeletons/skeleton_content_sliver_grid.dart';
import 'package:moliseis/ui/event/view_models/event_view_model.dart';
import 'package:moliseis/utils/enums.dart';
import 'package:moliseis/utils/extensions/extensions.dart';
import 'package:paged_vertical_calendar/utils/date_utils.dart';

class EventsModal extends StatelessWidget {
  final List<String> localizedMonths;
  final DateTime selectedDate;
  final EventViewModel viewModel;
  final ScrollController? scrollController;

  const EventsModal({
    super.key,
    required this.localizedMonths,
    required this.selectedDate,
    this.scrollController,
    required this.viewModel,
  });

  @override
  Widget build(BuildContext context) {
    final command = viewModel.loadByDate;

    final localizedSelectedMonth = localizedMonths[selectedDate.month - 1];

    final bottomSheetTitle = selectedDate.isSameDay(DateTime.now())
        ? 'Eventi di oggi ${selectedDate.day} $localizedSelectedMonth'
        : 'Eventi del ${selectedDate.day} $localizedSelectedMonth';

    return CustomScrollView(
      controller: scrollController,
      slivers: <Widget>[
        SliverList.list(
          children: <Widget>[
            if (context.windowSizeClass.isAtMost(WindowSizeClass.medium))
              const AppBottomSheetDragHandle(),
            Padding(
              padding: const EdgeInsets.all(16.0),
              child: AppBottomSheetTitle(
                title: bottomSheetTitle,
                // onClose: () => Navigator.of(context).pop(),
                icon: null,
              ),
            ),
          ],
        ),
        ListenableBuilder(
          listenable: command,
          builder: (context, child) {
            if (command.completed) {
              final events = viewModel.byMonth;

              if (events.isEmpty) {
                return const SliverToBoxAdapter(
                  child: EmptyView(
                    text: Text('Nessun evento trovato per questa data.'),
                  ),
                );
              }

              return ContentSliverGrid(
                events,
                onPressed: (content) {
                  GoRouter.of(context).goNamed(
                    RouteNames.eventsPost,
                    pathParameters: {'id': content.remoteId.toString()},
                    queryParameters: {'isEvent': 'true'},
                  );
                },
              );
            }

            return const SkeletonContentSliverGrid();
          },
        ),
      ],
    );
  }
}
