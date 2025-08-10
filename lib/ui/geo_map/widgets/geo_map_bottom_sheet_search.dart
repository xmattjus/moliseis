import 'package:flutter/material.dart';
import 'package:moliseis/domain/models/core/content_base.dart';
import 'package:moliseis/ui/core/ui/bottom_sheet_adaptive_title.dart';
import 'package:moliseis/ui/core/ui/custom_back_button.dart';
import 'package:moliseis/ui/search/view_models/search_view_model.dart';
// import 'package:moliseis/ui/search/widgets/search_result_related_sliver_list.dart';
import 'package:moliseis/ui/search/widgets/search_result_sliver_list.dart';

class GeoMapBottomSheetSearch extends StatefulWidget {
  const GeoMapBottomSheetSearch(
    this.query, {
    required this.onResultPressed,
    required this.onBackPressed,
    required this.viewModel,
  });

  final String query;
  final void Function(ContentBase content) onResultPressed;
  final void Function() onBackPressed;
  final SearchViewModel viewModel;

  @override
  State<GeoMapBottomSheetSearch> createState() =>
      GeoMapBottomSheetSearchState();
}

class GeoMapBottomSheetSearchState extends State<GeoMapBottomSheetSearch> {
  @override
  Widget build(BuildContext context) {
    return SliverMainAxisGroup(
      slivers: <Widget>[
        SliverToBoxAdapter(
          child: Row(
            spacing: 16.0,
            children: <Widget>[
              CustomBackButton(
                onPressed: widget.onBackPressed,
                backgroundColor: Colors.transparent,
              ),
              const BottomSheetAdaptiveTitle(
                'Risultati',
                padding: EdgeInsets.zero,
              ),
            ],
          ),
        ),
        SearchResultSliverList(
          onResultPressed: widget.onResultPressed,
          onRetrySearchPressed: () {
            widget.viewModel.loadResults.execute(widget.query);
          },
          viewModel: widget.viewModel,
        ),
        /*
        SearchResultRelatedSliverList(
          onResultPressed: widget.onResultPressed,
          viewModel: widget.viewModel,
        ),
        */
      ],
    );
  }
}
