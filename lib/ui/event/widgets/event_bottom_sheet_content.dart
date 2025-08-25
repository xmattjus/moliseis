import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:moliseis/routing/route_names.dart';
import 'package:moliseis/ui/core/ui/bottom_sheet_adaptive_title.dart';
import 'package:moliseis/ui/core/ui/bottom_sheet_drag_handle.dart';
import 'package:moliseis/ui/core/ui/content/content_adaptive_list_grid_view.dart';
import 'package:moliseis/ui/core/ui/empty_view.dart';
import 'package:moliseis/ui/core/ui/skeletons/skeleton_content_grid.dart';
import 'package:moliseis/ui/core/ui/skeletons/skeleton_content_list.dart';
import 'package:moliseis/ui/core/ui/window_size_provider.dart';
import 'package:moliseis/ui/event/view_models/event_view_model.dart';

class EventBottomSheetContent extends StatelessWidget {
  const EventBottomSheetContent({
    super.key,
    required this.localizedMonths,
    required this.selectedDate,
    required this.viewModel,
  });

  final List<String> localizedMonths;
  final DateTime selectedDate;
  final EventViewModel viewModel;

  @override
  Widget build(BuildContext context) {
    return AutoWindowSizeProvider(
      child: DraggableScrollableSheet(
        expand: false,
        builder: (context, scrollController) {
          final command = viewModel.loadByDate;

          return CustomScrollView(
            controller: scrollController,
            slivers: <Widget>[
              SliverList.list(
                children: <Widget>[
                  const BottomSheetDragHandle(),
                  BottomSheetAdaptiveTitle(
                    'Eventi del ${selectedDate.day} ${localizedMonths[selectedDate.month - 1]}',
                  ),
                ],
              ),
              ListenableBuilder(
                listenable: command,
                builder: (context, child) {
                  if (command.completed) {
                    final events = viewModel.byMonth;

                    if (events.isEmpty) {
                      return const EmptyView(
                        text: Text('Nessun evento trovato per questa data.'),
                      );
                    }

                    return ContentAdaptiveListGridView(
                      events,
                      onPressed: (content) {
                        GoRouter.of(context).goNamed(
                          RouteNames.eventsDetails,
                          pathParameters: {'id': content.remoteId.toString()},
                          queryParameters: {'isEvent': 'true'},
                        );
                      },
                    );
                  }

                  return WindowSizeProvider.of(context).isCompact
                      ? const SkeletonContentList.sliver(itemCount: 3)
                      : const SkeletonContentGrid.sliver(itemCount: 3);
                },
              ),
            ],
          );
        },
      ),
    );
  }
}
