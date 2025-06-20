import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:moliseis/routing/route_names.dart';
import 'package:moliseis/ui/core/ui/attraction_list_view_responsive.dart';
import 'package:moliseis/ui/core/ui/custom_appbar.dart';
import 'package:moliseis/ui/core/ui/custom_back_button.dart';
import 'package:moliseis/ui/core/ui/empty_view.dart';
import 'package:moliseis/ui/core/ui/machine_learning_icon.dart';
import 'package:moliseis/ui/core/ui/text_section_divider.dart';
import 'package:moliseis/ui/search/view_models/search_view_model.dart';
import 'package:moliseis/ui/search/widgets/custom_search_anchor.dart';

class SearchResult extends StatefulWidget {
  const SearchResult({super.key, required this.viewModel, required this.query});

  final SearchViewModel viewModel;
  final String query;

  @override
  State<SearchResult> createState() => _SearchResultState();
}

class _SearchResultState extends State<SearchResult> {
  final SearchController _controller = SearchController();

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    if (widget.query.isNotEmpty) {
      _controller.text = widget.query;
    }

    return Scaffold(
      appBar: const CustomAppBar.hidden(),
      body: SafeArea(
        child: Stack(
          children: [
            CustomScrollView(
              slivers: [
                const SliverPadding(
                  padding: EdgeInsetsDirectional.fromSTEB(
                    16.0,
                    kToolbarHeight + 16.0,
                    16.0,
                    8.0,
                  ),
                  sliver: SliverToBoxAdapter(
                    child: TextSectionDivider('Risultati'),
                  ),
                ),
                ListenableBuilder(
                  listenable: widget.viewModel.loadResults,
                  builder: (context, child) {
                    if (widget.viewModel.loadResults.running) {
                      return const SliverFillRemaining(
                        hasScrollBody: false,
                        child: EmptyView.loading(
                          text: Text('Caricamento in corso...'),
                        ),
                      );
                    }

                    if (widget.viewModel.loadResults.error) {
                      return SliverFillRemaining(
                        hasScrollBody: false,
                        child: EmptyView(
                          text: const Text(
                            'Si è verificato un errore durante il caricamento.',
                          ),
                          action: TextButton(
                            onPressed: () {
                              widget.viewModel.loadResults.execute(
                                widget.query,
                              );
                            },
                            child: const Text('Riprova'),
                          ),
                        ),
                      );
                    }

                    if (widget.viewModel.resultIds.isEmpty) {
                      return const SliverFillRemaining(
                        hasScrollBody: false,
                        child: EmptyView(
                          text: Text('Non è stato trovato alcun risultato.'),
                        ),
                      );
                    }

                    return SliverPadding(
                      padding: const EdgeInsets.only(bottom: 16.0),
                      sliver: AttractionListViewResponsive(
                        Future.sync(() => widget.viewModel.resultIds),
                        onPressed: (attractionId) {
                          _controller.closeView(_controller.text);
                          GoRouter.of(context).goNamed(
                            RouteNames.homeStory,
                            pathParameters: {'id': attractionId.toString()},
                          );
                        },
                      ),
                    );
                  },
                ),
                ListenableBuilder(
                  listenable: widget.viewModel.loadRelatedResults,
                  builder: (context, child) {
                    if (widget.viewModel.loadRelatedResults.running) {
                      return const SliverToBoxAdapter(
                        child: EmptyView(
                          icon: MachineLearningIcon(),
                          text: Text('Sto generando altri risultati...'),
                        ),
                      );
                    }

                    if (widget.viewModel.loadRelatedResults.completed &&
                        widget.viewModel.relatedResultIds.isNotEmpty) {
                      return SliverMainAxisGroup(
                        slivers: [
                          const SliverPadding(
                            padding: EdgeInsetsDirectional.fromSTEB(
                              16.0,
                              0.0,
                              16.0,
                              8.0,
                            ),
                            sliver: SliverToBoxAdapter(
                              child: TextSectionDivider('Altri risultati'),
                            ),
                          ),
                          AttractionListViewResponsive(
                            Future.sync(
                              () => widget.viewModel.relatedResultIds,
                            ),
                            onPressed: (attractionId) {
                              _controller.closeView(_controller.text);
                              GoRouter.of(context).goNamed(
                                RouteNames.homeStory,
                                pathParameters: {'id': attractionId.toString()},
                              );
                            },
                          ),
                          const SliverPadding(
                            padding: EdgeInsets.only(bottom: 16.0),
                          ),
                        ],
                      );
                    }

                    // Returns an empty box in case of error or no results to show.
                    return const SliverToBoxAdapter(child: SizedBox());
                  },
                ),
              ],
            ),
            Align(
              alignment: Alignment.topLeft,
              child: ColoredBox(
                color: Theme.of(context).colorScheme.surface,
                child: Padding(
                  padding: const EdgeInsets.only(top: 4.0, bottom: 4.0),
                  child: CustomSearchAnchor(
                    controller: _controller,
                    leading: const CustomBackButton(
                      padding: EdgeInsetsDirectional.zero,
                      backgroundColor: Colors.transparent,
                    ),
                    onSubmitted: (text) {
                      widget.viewModel.loadResults.execute(text);
                      widget.viewModel.loadRelatedResults.execute(text);
                    },
                    onSuggestionPressed: (attractionId) {
                      _controller.closeView(_controller.text);
                      widget.viewModel.loadResults.execute(_controller.text);
                      widget.viewModel.loadRelatedResults.execute(
                        _controller.text,
                      );
                    },
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
