import 'package:material_ui/material_ui.dart';
import 'package:moliseis/domain/models/content_base.dart';
import 'package:moliseis/domain/models/event.dart';
import 'package:moliseis/ui/core/ui/blurred_box.dart';
import 'package:moliseis/ui/core/ui/content/content_base_card_grid_item.dart';
import 'package:moliseis/ui/core/ui/content/content_event_card_grid_item.dart';
import 'package:moliseis/ui/core/ui/empty_view.dart';
import 'package:moliseis/ui/core/ui/skeletons/app_pulse_effect.dart';
import 'package:moliseis/ui/core/ui/skeletons/skeleton_content_grid_item.dart';
import 'package:moliseis/ui/core/ui/text_section_divider.dart';
import 'package:moliseis/ui/favourite/widgets/favourite_button.dart';
import 'package:moliseis/utils/constants.dart';
import 'package:moliseis/utils/extensions/extensions.dart';
import 'package:skeletonizer/skeletonizer.dart';

/// Coherent, command-independent presentation of a Nearby retrieval.
typedef NearbyContentPresentation = ({
  bool pending,
  List<ContentBase> items,
  Object? error,
});

/// Displays Nearby content from the owning surface's presentation projection.
class NearbyContentHorizontalList extends StatefulWidget {
  const NearbyContentHorizontalList({
    required this.loadListenable,
    required this.loadKey,
    required this.onLoad,
    required this.readState,
    required this.onPressed,
    this.onRetry,
    super.key,
  });

  final Listenable loadListenable;
  final Object loadKey;
  final VoidCallback onLoad;
  final NearbyContentPresentation Function() readState;
  final VoidCallback? onRetry;
  final void Function(ContentBase content) onPressed;

  @override
  State<NearbyContentHorizontalList> createState() =>
      _NearbyContentHorizontalListState();
}

class _NearbyContentHorizontalListState
    extends State<NearbyContentHorizontalList> {
  bool _loadScheduled = false;
  Object? _pendingLoadKey;

  @override
  void initState() {
    super.initState();
    _scheduleLoad();
  }

  @override
  void didUpdateWidget(covariant NearbyContentHorizontalList oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.loadKey != widget.loadKey ||
        !identical(oldWidget.loadListenable, widget.loadListenable)) {
      _scheduleLoad();
    }
  }

  void _scheduleLoad() {
    _pendingLoadKey = widget.loadKey;
    if (_loadScheduled) return;
    _loadScheduled = true;
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      _loadScheduled = false;
      if (_pendingLoadKey == widget.loadKey) widget.onLoad();
    });
  }

  Widget _buildError() => EmptyView.error(
    text: const Text('Si è verificato un errore durante il caricamento.'),
    action: widget.onRetry == null
        ? null
        : TextButton(onPressed: widget.onRetry, child: const Text('Riprova')),
  );

  @override
  Widget build(BuildContext context) {
    final colorScheme = context.colorScheme;

    const padding = EdgeInsetsDirectional.fromSTEB(16, 0, 16, 4);
    const skeletonItems = 5;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      mainAxisSize: MainAxisSize.min,
      children: <Widget>[
        const TextSectionDivider(
          'Nelle vicinanze',
          padding: EdgeInsetsDirectional.fromSTEB(16, 0, 16, 8),
        ),
        SizedBox(
          height: kGridViewCardHeight,
          child: ListenableBuilder(
            listenable: widget.loadListenable,
            builder: (context, child) {
              final state = widget.readState();
              if (!state.pending) {
                final nearContent = state.items;
                if (state.error != null && nearContent.isEmpty) {
                  return _buildError();
                }
                if (nearContent.isEmpty) {
                  return const EmptyView(
                    text: Text('Nessun luogo trovato nelle vicinanze.'),
                  );
                }

                final list = ListView.separated(
                  scrollDirection: Axis.horizontal,
                  padding: padding,
                  itemBuilder: (_, index) {
                    final content = nearContent[index];

                    if (content is Event) {
                      return ContentEventCardGridItem(
                        event: content,
                        onPressed: widget.onPressed,
                      );
                    }

                    return ContentBaseCardGridItem(
                      content,
                      width: kGridViewCardWidth,
                      onPressed: (content) => widget.onPressed(content),
                      trailing: Wrap(
                        alignment: WrapAlignment.end,
                        spacing: 4,
                        runSpacing: 4,
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
                  separatorBuilder: (_, _) => const SizedBox(width: 8),
                  itemCount: nearContent.length,
                );
                if (state.error == null) return list;
                return Column(
                  children: [
                    Expanded(child: list),
                    Row(
                      children: [
                        const Expanded(
                          child: Text(
                            'Si è verificato un errore durante il caricamento.',
                          ),
                        ),
                        if (widget.onRetry != null)
                          TextButton(
                            onPressed: widget.onRetry,
                            child: const Text('Riprova'),
                          ),
                      ],
                    ),
                  ],
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
                  separatorBuilder: (_, _) => const SizedBox(width: 8),
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
