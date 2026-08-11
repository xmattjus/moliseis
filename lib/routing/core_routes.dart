import 'dart:async' show unawaited;

import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:moliseis/domain/models/content_category.dart';
import 'package:moliseis/domain/use-cases/category_use_case.dart';
import 'package:moliseis/domain/use-cases/explore_use_case.dart';
import 'package:moliseis/domain/use-cases/post_use_case.dart';
import 'package:moliseis/routing/route_parameters.dart';
import 'package:moliseis/routing/route_paths.dart';
import 'package:moliseis/ui/category/view_models/category_view_model.dart';
import 'package:moliseis/ui/category/widgets/category_screen.dart';
import 'package:moliseis/ui/core/ui/route_error_screen.dart';
import 'package:moliseis/ui/post/view_models/post_view_model.dart';
import 'package:moliseis/ui/post/widgets/post_screen.dart';
import 'package:moliseis/ui/weather/view_models/weather_view_model.dart';
import 'package:moliseis/ui/weather/wmo_weather_description_mapper.dart';
import 'package:moliseis/ui/weather/wmo_weather_icon_mapper.dart';
import 'package:moliseis/utils/extensions/extensions.dart';
import 'package:provider/provider.dart';

const _categorySegment = 'category';
const _searchResultsSegment = 'search_results';

/// Returns a canonical category location when [state] matched a legacy
/// numeric category index, or null when no canonicalization is needed.
///
/// The redirect is side-effect-free and preserves child suffixes and query
/// parameters. Compatibility marker: numeric category indexes are supported
/// only for restored pre-2.3.0 locations and can be removed in the next major
/// release.
String? _redirectLegacyCategoryIndex(
  BuildContext context,
  GoRouterState state,
) {
  final raw = state.pathParameters['categorySlug'];
  if (raw == null) return null;

  final index = int.tryParse(raw);
  if (index == null) return null;

  final slug = RouteParameters.categorySlugFromLegacyIndex(index);
  if (slug == null) return null;

  final segments = state.uri.pathSegments;
  final categoryIndex = segments.indexOf(_categorySegment);
  if (categoryIndex == -1 || categoryIndex + 1 >= segments.length) return null;

  final canonicalSegments = <String>[...segments];
  canonicalSegments[categoryIndex + 1] = slug;

  return state.uri.replace(pathSegments: canonicalSegments).toString();
}

/// Returns a canonical post location when [state] still carries a legacy
/// `isEvent` value or no content type, or null when the location is already
/// canonical or cannot be canonicalized.
///
/// The redirect is side-effect-free and preserves every other query
/// parameter, including the search `q`. A missing type keeps the legacy
/// default of `place`. Malformed `isEvent` and `type` values are left
/// untouched so the builder renders the router error UI. Compatibility
/// marker: `isEvent` is supported only for restored pre-2.3.0 locations and
/// can be removed in the next major release.
String? _redirectLegacyPostType(BuildContext context, GoRouterState state) {
  final query = state.uri.queryParameters;
  final type = query['type'];

  if (type == RouteParameters.eventType || type == RouteParameters.placeType) {
    if (!query.containsKey('isEvent')) return null;

    final canonicalQuery = <String, String>{...query}..remove('isEvent');
    return state.uri.replace(queryParameters: canonicalQuery).toString();
  }

  // A present but non-canonical type is malformed: there is no canonical form
  // to redirect to, so the builder renders the router error UI.
  if (query.containsKey('type')) {
    return null;
  }

  final canonicalType = switch (query['isEvent']) {
    'true' => RouteParameters.eventType,
    'false' => RouteParameters.placeType,
    null => RouteParameters.placeType,
    _ => null,
  };
  if (canonicalType == null) return null;

  final canonicalQuery = <String, String>{...query, 'type': canonicalType}
    ..remove('isEvent');

  return state.uri.replace(queryParameters: canonicalQuery).toString();
}

/// Compatibility redirect that canonicalizes restored
/// `search_results/:query` locations, including their nested post paths, into
/// `search_results?q=<query>`.
///
/// The redirect is side-effect-free, preserves child suffixes, and keeps all
/// other query parameters. Compatibility marker: legacy search paths are
/// supported only for restored pre-2.3.0 locations and can be removed in the
/// next major release.
String? redirectLegacySearchResults(BuildContext context, GoRouterState state) {
  final segments = state.uri.pathSegments;
  final searchIndex = segments.indexOf(_searchResultsSegment);
  if (searchIndex == -1 || searchIndex + 1 >= segments.length) return null;

  final query = segments[searchIndex + 1];
  final canonicalSegments = <String>[
    ...segments.take(searchIndex + 1),
    ...segments.skip(searchIndex + 2),
  ];

  return state.uri
      .replace(
        pathSegments: canonicalSegments,
        queryParameters: <String, String>{
          ...state.uri.queryParameters,
          'q': query,
        },
      )
      .toString();
}

GoRoute categoryRoute({
  required String name,
  required String childName,
  required GlobalKey<NavigatorState> parentNavigatorKey,
}) {
  return GoRoute(
    parentNavigatorKey: parentNavigatorKey,
    path: RoutePaths.category,
    name: name,
    redirect: _redirectLegacyCategoryIndex,
    builder: (_, state) {
      final slug = state.pathParameters['categorySlug'] ?? '';
      final category = RouteParameters.categoryFromSlug(slug);
      final allCategories = ContentCategory.values.minusUnknown;

      if (category == null && slug != RouteParameters.allCategorySlug) {
        return RouteErrorScreen(
          uri: state.uri,
          error: GoException('Unknown category "$slug"'),
        );
      }

      return ChangeNotifierProvider<CategoryViewModel>(
        key: ValueKey(slug),
        create: (context) {
          final viewModel = CategoryViewModel(
            categoryUseCase: CategoryUseCase(
              eventRepository: context.read(),
              placeRepository: context.read(),
            ),
            exploreGetByIdUseCase: ExploreUseCase(
              eventRepository: context.read(),
              placeRepository: context.read(),
            ),
            settingsRepository: context.read(),
          );

          unawaited(
            viewModel.setSelectedCategories.execute(
              category == null ? {...allCategories} : {category},
            ),
          );

          return viewModel;
        },
        builder: (context, _) => CategoryScreen(viewModel: context.read()),
      );
    },
    routes: <RouteBase>[
      postRoute(
        name: childName,
        parentNavigatorKey: parentNavigatorKey,
      ),
    ],
  );
}

GoRoute postRoute({
  required String name,
  required GlobalKey<NavigatorState> parentNavigatorKey,
}) {
  return GoRoute(
    parentNavigatorKey: parentNavigatorKey,
    path: RoutePaths.post,
    name: name,
    redirect: _redirectLegacyPostType,
    builder: (context, state) {
      final rawId = state.pathParameters['id'];
      final id = RouteParameters.contentId(rawId);

      if (id == null) {
        return RouteErrorScreen(
          uri: state.uri,
          error: GoException('Invalid content id "$rawId"'),
        );
      }

      final rawType = state.uri.queryParameters['type'];
      final type = RouteParameters.contentType(rawType);

      if (type == null) {
        return RouteErrorScreen(
          uri: state.uri,
          error: GoException('Missing or invalid content type "$rawType"'),
        );
      }

      final postUseCase = PostUseCase(
        eventRepository: context.read(),
        placeRepository: context.read(),
      );

      final viewModel = PostViewModel(postUseCase: postUseCase);

      final weatherViewModel = WeatherViewModel(
        weatherApiClient: context.read(),
        weatherDescriptionMapper: const WmoWeatherDescriptionMapper(),
        weatherCodeIconMapper: const WmoWeatherIconMapper(),
      );

      final isEvent = RouteParameters.isEvent(type);

      if (isEvent) {
        unawaited(viewModel.loadEvent.execute(id));
      } else {
        unawaited(viewModel.loadPlace.execute(id));
      }

      return PostScreen(
        key: ValueKey((id, type)),
        isEvent: isEvent,
        viewModel: viewModel,
        weatherViewModel: weatherViewModel,
      );
    },
  );
}
