import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:moliseis/routing/route_names.dart';
import 'package:moliseis/ui/core/themes/app_colors_theme_extension.dart';
import 'package:moliseis/ui/core/themes/app_effects_theme_extension.dart';
import 'package:moliseis/ui/core/themes/app_sizes_theme_extension.dart';
import 'package:moliseis/ui/core/themes/shapes.dart';
import 'package:moliseis/ui/core/ui/bottom_sheet_drag_handle.dart';
import 'package:moliseis/ui/core/ui/bottom_sheet_title.dart';
import 'package:moliseis/ui/core/ui/content/content_adaptive_list_grid_view.dart';
import 'package:moliseis/ui/core/ui/empty_view.dart';
import 'package:moliseis/ui/core/ui/skeletons/skeleton_content_grid.dart';
import 'package:moliseis/ui/core/ui/skeletons/skeleton_content_list.dart';
import 'package:moliseis/ui/core/ui/window_size_provider.dart';
import 'package:moliseis/ui/event/view_models/event_view_model.dart';

class EventsModal extends StatelessWidget {
  const EventsModal({
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
    final appSizes = Theme.of(context).extension<AppSizesThemeExtension>()!;

    return AutoWindowSizeProvider(
      child: DraggableScrollableSheet(
        snap: true,
        minChildSize: appSizes.modalMinSnapSize,
        snapSizes: appSizes.modalSnapSizes,
        builder: (context, scrollController) {
          final command = viewModel.loadByDate;

          final appColors = Theme.of(
            context,
          ).extension<AppColorsThemeExtension>()!;
          final appEffects = Theme.of(
            context,
          ).extension<AppEffectsThemeExtension>()!;
          final appSizes = Theme.of(
            context,
          ).extension<AppSizesThemeExtension>()!;

          return ClipRRect(
            borderRadius: const BorderRadius.vertical(
              top: Radius.circular(Shapes.extraLarge),
            ),
            child: Stack(
              children: <Widget>[
                Positioned.fill(
                  child: ClipRRect(
                    child: BackdropFilter(
                      filter: appEffects.modalBlurEffect,
                      child: DecoratedBox(
                        decoration: BoxDecoration(
                          color: appColors.modalBackgroundColor,
                          borderRadius: const BorderRadius.vertical(
                            top: Radius.circular(Shapes.extraLarge),
                          ),
                          border: Border.all(
                            color: appColors.modalBorderColor,
                            width: appSizes.borderSize,
                          ),
                        ),
                      ),
                    ),
                  ),
                ),
                CustomScrollView(
                  controller: scrollController,
                  slivers: <Widget>[
                    SliverList.list(
                      children: <Widget>[
                        const BottomSheetDragHandle(),
                        Padding(
                          padding: const EdgeInsetsGeometry.fromSTEB(
                            16.0,
                            0,
                            16.0,
                            16.0,
                          ),
                          child: BottomSheetTitle(
                            title:
                                'Eventi del ${selectedDate.day} ${localizedMonths[selectedDate.month - 1]}',
                            onClose: () => Navigator.of(context).pop(),
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
                            return const EmptyView(
                              text: Text(
                                'Nessun evento trovato per questa data.',
                              ),
                            );
                          }

                          return ContentAdaptiveListGridView(
                            events,
                            onPressed: (content) {
                              GoRouter.of(context).goNamed(
                                RouteNames.eventsDetails,
                                pathParameters: {
                                  'id': content.remoteId.toString(),
                                },
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
                ),
              ],
            ),
          );
        },
      ),
    );
  }
}
