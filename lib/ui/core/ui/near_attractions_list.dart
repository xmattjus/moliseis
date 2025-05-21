import 'package:flutter/material.dart';
import 'package:moliseis/domain/models/attraction/attraction.dart';
import 'package:moliseis/ui/core/ui/cards/card_attraction_grid_item.dart';
import 'package:moliseis/ui/core/ui/custom_circular_progress_indicator.dart';
import 'package:moliseis/ui/core/ui/empty_view.dart';
import 'package:moliseis/ui/core/ui/future_built.dart';
import 'package:moliseis/ui/core/ui/text_section_divider.dart';
import 'package:moliseis/ui/explore/view_models/attraction_view_model.dart';
import 'package:moliseis/utils/constants.dart';
import 'package:provider/provider.dart';

class NearAttractionsList extends StatefulWidget {
  const NearAttractionsList({
    super.key,
    required this.coordinates,
    this.hideFirstItem = false,
    required this.onPressed,
  });

  /// The list of coordinates to search near [Attraction]s from.
  final List<double> coordinates;

  /// Whether to show the first [Attraction] of the list or not.
  final bool hideFirstItem;

  final void Function(int id) onPressed;

  @override
  State<NearAttractionsList> createState() => _NearAttractionsListState();
}

class _NearAttractionsListState extends State<NearAttractionsList> {
  late final AttractionViewModel _attractionViewModel;

  late Future<List<int>> _future;

  Future<void> updateFuture(List<double> coordinates) async {
    _future = _attractionViewModel.getNearAttractionIds(coordinates);
  }

  @override
  void initState() {
    super.initState();

    ///
    _attractionViewModel = context.read();

    updateFuture(widget.coordinates);
  }

  @override
  void didUpdateWidget(covariant NearAttractionsList oldWidget) {
    super.didUpdateWidget(oldWidget);

    if (widget.coordinates[0] != oldWidget.coordinates[0] ||
        widget.coordinates[1] != oldWidget.coordinates[1]) {
      updateFuture(widget.coordinates);
    }
  }

  /*
  /// Creates an [AlertDialog] to explain to the user how the AI generated
  /// content works.
  Widget _buildInfoDialog(BuildContext context) {
    return AlertDialog(
      title: const Text('Contenuti IA (Beta)'),
      content: const Text('Molise Is analizza gli elementi che visualizzi e '
          'salvi, generando raccomandazioni basate su quello che più ti piace.'
          '\n\n'
          'Nessuna informazione lascia il tuo dispositivo.'),
      actions: [
        TextButton(
            onPressed: () {
              Navigator.of(context).pop();
            },
            child: const Text('Ok')),
      ],
      contentTextStyle: Theme.of(context)
          .textTheme
          .bodyMedium
          ?.copyWith(fontStyle: FontStyle.normal),
    );
  }
   */

  @override
  Widget build(BuildContext context) {
    /// Returns an invisible (0 px wide and 0 px tall) empty box
    /// as there isn't anything to show.
    if (widget.coordinates.isEmpty) {
      return const SizedBox();
    }

    const Widget row = Wrap(
      alignment: WrapAlignment.spaceBetween,
      crossAxisAlignment: WrapCrossAlignment.center,
      children: [
        TextSectionDivider('Nelle vicinanze'),
        /*
        TextButton.icon(
          onPressed: () async {
            await showDialog<void>(
                context: context,
                builder: (context) {
                  return _buildInfoDialog(context);
                });
          },
          style: ButtonStyle(
              foregroundColor: const WidgetStatePropertyAll<Color>(
                Colors.deepPurpleAccent,
              ),
              overlayColor: WidgetStateProperty.resolveWith<Color?>((states) {
                if (states.contains(WidgetState.hovered)) {
                  return Colors.deepPurple.withValues(alpha: 0.08);
                }

                if (states.contains(WidgetState.focused) ||
                    states.contains(WidgetState.pressed)) {
                  return Colors.deepPurple.withValues(alpha: 0.10);
                }

                return null;
              }),
              padding: const WidgetStatePropertyAll<EdgeInsetsGeometry>(
                EdgeInsetsDirectional.fromSTEB(8.0, 16.0, 0.0, 16.0),
              ),
              iconColor: const WidgetStatePropertyAll<Color>(
                Colors.deepPurpleAccent,
              ),
              visualDensity: VisualDensity.compact),
          icon: const Icon(Icons.auto_awesome_outlined),
          label: const Text('Generati dalla IA'),
        ),
         */
      ],
    );

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      mainAxisSize: MainAxisSize.min,
      children: <Widget>[
        const Padding(
          padding: EdgeInsetsDirectional.fromSTEB(16.0, 0, 16.0, 8.0),
          child: row,
        ),
        SizedBox(
          height: kGridViewCardHeight,
          child: FutureBuilt<List<int>>(
            _future,
            onLoading: () {
              return const Center(
                child: CustomCircularProgressIndicator.withDelay(),
              );
            },
            onSuccess: (data) {
              return ListView.separated(
                scrollDirection: Axis.horizontal,
                padding: const EdgeInsetsDirectional.fromSTEB(
                  16.0,
                  0,
                  16.0,
                  4.0,
                ),
                itemBuilder: (context, index) {
                  if (widget.hideFirstItem && index == 0) {
                    return const SizedBox();
                  }

                  return SizedBox(
                    width: MediaQuery.sizeOf(context).width * 0.5,
                    child: CardAttractionGridItem(
                      data[index],
                      onPressed: () => widget.onPressed(data[index]),
                    ),
                  );
                },
                separatorBuilder: (context, index) => SizedBox(
                  width: widget.hideFirstItem && index == 0 ? 0 : 8.0,
                ),
                itemCount: data.length,
              );
            },
            onError: (error) {
              return const EmptyView.error(
                text: Text('Si è verificato un errore durante il caricamento.'),
              );
            },
          ),
        ),
      ],
    );
  }
}
