import 'package:flutter/material.dart';
import 'package:moliseis/domain/models/content_base.dart';
import 'package:moliseis/ui/search/view_models/search_view_model.dart';
import 'package:moliseis/ui/search/widgets/components/app_search_anchor.dart';

class AnimatedGeoMapSearchBar extends StatelessWidget {
  final SearchController searchController;
  final ValueNotifier<bool> animation;
  final void Function(String)? onSubmitted;
  final void Function()? onBackPressed;
  final void Function(ContentBase) onSuggestionPressed;
  final List<Widget>? trailing;
  final SearchViewModel viewModel;

  const AnimatedGeoMapSearchBar({
    super.key,
    required this.searchController,
    required this.animation,
    this.onSubmitted,
    this.onBackPressed,
    required this.onSuggestionPressed,
    this.trailing,
    required this.viewModel,
  });

  @override
  Widget build(BuildContext context) {
    return SafeArea(
      child: Align(
        alignment: Alignment.topLeft,
        child: AnimatedBuilder(
          animation: animation,
          builder: (_, child) {
            return AnimatedSlide(
              offset: Offset(0, animation.value ? 0 : -2.0),
              curve: animation.value
                  ? Curves.easeInOutCubicEmphasized
                  : Easing.emphasizedDecelerate,
              duration: animation.value ? Durations.medium4 : Durations.medium1,
              child: child,
            );
          },
          child: Padding(
            padding: const EdgeInsets.symmetric(vertical: 4.0),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: <Widget>[
                AppSearchAnchor(
                  controller: searchController,
                  onSubmitted: onSubmitted,
                  onBackPressed: onBackPressed,
                  elevation: 1.0,
                  onSuggestionPressed: onSuggestionPressed,
                  viewModel: viewModel,
                ),
                ...?trailing,
              ],
            ),
          ),
        ),
      ),
    );
  }
}
