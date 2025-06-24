import 'package:go_router/go_router.dart';
import 'package:moliseis/main.dart' show log;
import 'package:moliseis/routing/route_paths.dart';
import 'package:moliseis/ui/categories/widgets/categories_screen.dart';
import 'package:moliseis/ui/core/ui/custom_snack_bar.dart';
import 'package:moliseis/ui/story/view_models/paragraph_view_model.dart';
import 'package:moliseis/ui/story/view_models/story_view_model.dart';
import 'package:moliseis/ui/story/widgets/story_screen.dart';
import 'package:provider/provider.dart';

GoRoute categoriesRoute({required String name, required String childName}) {
  return GoRoute(
    path: RoutePaths.category,
    name: name,
    builder: (_, state) {
      final tabIndex = int.parse(state.pathParameters['index'] ?? '0');
      return CategoriesScreen(tabIndex: tabIndex);
    },
    routes: <RouteBase>[storyRoute(name: childName)],
  );
}

GoRoute storyRoute({required String name}) {
  return GoRoute(
    path: RoutePaths.story,
    name: name,
    builder: (context, state) {
      final id = int.parse(state.pathParameters['id']!);

      final viewModel = StoryViewModel(
        attractionRepository: context.read(),
        galleryRepository: context.read(),
        storyRepository: context.read(),
      );

      final paragraphViewModel = ParagraphViewModel(
        paragraphRepository: context.read(),
      );

      // Loads the story from the backend.
      viewModel.load.execute(id);

      return StoryScreen(
        attractionId: id,
        paragraphViewModel: paragraphViewModel,
        storyViewModel: viewModel,
      );
    },
    redirect: (context, state) {
      final attractionId = state.pathParameters['id'];

      if (attractionId == null || int.tryParse(attractionId) == null) {
        log.severe('Attraction id $attractionId is not a parsable integer.');
        showSnackBar(
          context: context,
          textContent:
              'Si è verificato un errore durante il caricamento, riprova più '
              'tardi.',
        );
        return RoutePaths.home;
      }

      return null;
    },
  );
}
