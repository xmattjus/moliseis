import 'dart:async' show unawaited;

import 'package:go_router/go_router.dart';
import 'package:material_ui/material_ui.dart';
import 'package:moliseis/domain/models/content_category.dart';
import 'package:moliseis/domain/use-cases/category_use_case.dart';
import 'package:moliseis/domain/use-cases/explore_use_case.dart';
import 'package:moliseis/domain/use-cases/post_use_case.dart';
import 'package:moliseis/routing/route_parameters.dart';
import 'package:moliseis/routing/route_paths.dart';
import 'package:moliseis/ui/category/view_models/category_view_model.dart';
import 'package:moliseis/ui/category/widgets/category_screen.dart';
import 'package:moliseis/ui/core/ui/route_error_screen.dart';
import 'package:moliseis/ui/core/ui/scaffold_shell.dart';
import 'package:moliseis/ui/post/view_models/post_view_model.dart';
import 'package:moliseis/ui/post/widgets/post_screen.dart';
import 'package:moliseis/ui/weather/view_models/weather_view_model.dart';
import 'package:moliseis/ui/weather/wmo_weather_description_mapper.dart';
import 'package:moliseis/ui/weather/wmo_weather_icon_mapper.dart';
import 'package:moliseis/utils/extensions/extensions.dart';
import 'package:provider/provider.dart';

GoRoute categoryRoute({
  required String name,
  required String childName,
  required GlobalKey<NavigatorState> parentNavigatorKey,
  required int branchIndex,
}) {
  return GoRoute(
    parentNavigatorKey: parentNavigatorKey,
    path: RoutePaths.category,
    name: name,
    builder: (_, state) {
      final slug = state.pathParameters['categorySlug'] ?? '';
      final category = RouteParameters.categoryFromSlug(slug);
      final allCategories = ContentCategory.values.minusUnknown;

      if (category == null && slug != RouteParameters.allCategorySlug) {
        return BranchDetailPopScope(
          branchIndex: branchIndex,
          child: RouteErrorScreen(
            uri: state.uri,
            error: GoException('Unknown category "$slug"'),
          ),
        );
      }

      return BranchDetailPopScope(
        branchIndex: branchIndex,
        child: ChangeNotifierProvider<CategoryViewModel>(
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
        ),
      );
    },
    routes: <RouteBase>[
      postRoute(
        name: childName,
        parentNavigatorKey: parentNavigatorKey,
        branchIndex: branchIndex,
      ),
    ],
  );
}

GoRoute postRoute({
  required String name,
  required GlobalKey<NavigatorState> parentNavigatorKey,
  required int branchIndex,
}) {
  return GoRoute(
    parentNavigatorKey: parentNavigatorKey,
    path: RoutePaths.post,
    name: name,
    builder: (context, state) {
      // A child page can cover its parent's error page, so validate the
      // inherited Category before resolving any Post content.
      final categorySlug = state.pathParameters['categorySlug'];
      if (categorySlug != null &&
          categorySlug != RouteParameters.allCategorySlug &&
          RouteParameters.categoryFromSlug(categorySlug) == null) {
        return BranchDetailPopScope(
          branchIndex: branchIndex,
          child: RouteErrorScreen(
            uri: state.uri,
            error: GoException('Unknown category "$categorySlug"'),
          ),
        );
      }

      final rawId = state.pathParameters['id'];
      final id = RouteParameters.contentId(rawId);

      if (id == null) {
        return BranchDetailPopScope(
          branchIndex: branchIndex,
          child: RouteErrorScreen(
            uri: state.uri,
            error: GoException('Invalid content id "$rawId"'),
          ),
        );
      }

      final rawType = state.uri.queryParameters['type'];
      final type = RouteParameters.contentType(rawType);

      if (type == null) {
        return BranchDetailPopScope(
          branchIndex: branchIndex,
          child: RouteErrorScreen(
            uri: state.uri,
            error: GoException('Missing or invalid content type "$rawType"'),
          ),
        );
      }

      final isEvent = RouteParameters.isEvent(type);

      return ChangeNotifierProvider<PostViewModel>(
        key: ValueKey((id, type)),
        create: (context) {
          final viewModel = PostViewModel(
            postUseCase: PostUseCase(
              eventRepository: context.read(),
              placeRepository: context.read(),
            ),
          );
          if (isEvent) {
            unawaited(viewModel.loadEvent.execute(id));
          } else {
            unawaited(viewModel.loadPlace.execute(id));
          }
          return viewModel;
        },
        child: ChangeNotifierProvider<WeatherViewModel>(
          create: (context) => WeatherViewModel(
            weatherApiClient: context.read(),
            weatherDescriptionMapper: const WmoWeatherDescriptionMapper(),
            weatherCodeIconMapper: const WmoWeatherIconMapper(),
          ),
          builder: (context, _) => BranchDetailPopScope(
            branchIndex: branchIndex,
            child: PostScreen(
              key: ValueKey((id, type)),
              isEvent: isEvent,
              viewModel: context.read<PostViewModel>(),
              weatherViewModel: context.read<WeatherViewModel>(),
            ),
          ),
        ),
      );
    },
  );
}
