import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:moliseis/routing/route_names.dart';
import 'package:moliseis/ui/core/ui/attraction_list_view_responsive.dart';
import 'package:moliseis/ui/core/ui/custom_appbar.dart';
import 'package:moliseis/ui/core/ui/custom_back_button.dart';
import 'package:moliseis/ui/core/ui/empty_view.dart';
import 'package:moliseis/ui/core/ui/pad.dart';
import 'package:moliseis/ui/core/ui/text_section_divider.dart';
import 'package:moliseis/ui/search/view_models/search_view_model.dart';
import 'package:moliseis/ui/search/widgets/custom_search_anchor.dart';

class SearchResult extends StatefulWidget {
  const SearchResult({super.key, required this.viewModel, this.query});

  final SearchViewModel viewModel;
  final String? query;

  @override
  State<SearchResult> createState() => _SearchResultState();
}

class _SearchResultState extends State<SearchResult> {
  final SearchController _controller = SearchController();

  @override
  void initState() {
    super.initState();

    if (widget.query != null) {
      widget.viewModel.loadResults.execute(widget.query!);
    }
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final query = widget.query ?? '';

    if (query.isNotEmpty) {
      _controller.text = query;
    }

    return Scaffold(
      appBar: const CustomAppBar.hidden(),
      body: SafeArea(
        child: Stack(
          children: [
            CustomScrollView(
              slivers: [
                const SliverToBoxAdapter(
                  child: Pad(
                    t: kToolbarHeight + 16.0,
                    b: 8.0,
                    h: 16.0,
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
                              if (widget.query != null) {
                                widget.viewModel.loadResults.execute(
                                  widget.query!,
                                );
                              }
                            },
                            child: const Text('Riprova'),
                          ),
                        ),
                      );
                    }

                    if (widget.viewModel.resultIds.isEmpty || query.isEmpty) {
                      return const SliverFillRemaining(
                        hasScrollBody: false,
                        child: EmptyView(
                          text: Text('Non è stato trovato alcun risultato.'),
                        ),
                      );
                    }
                    return SliverPadding(
                      padding: const EdgeInsetsDirectional.only(bottom: 16.0),
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
              ],
            ),
            Align(
              alignment: Alignment.topLeft,
              child: ColoredBox(
                color: Theme.of(context).colorScheme.surface,
                child: CustomSearchAnchor(
                  controller: _controller,
                  leading: const CustomBackButton(
                    padding: EdgeInsetsDirectional.zero,
                    backgroundColor: Colors.transparent,
                  ),
                  onSubmitted: (text) {
                    widget.viewModel.loadResults.execute(text);
                  },
                  onSuggestionPressed: (attractionId) {
                    _controller.closeView(_controller.text);
                    widget.viewModel.loadResults.execute(_controller.text);
                  },
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
