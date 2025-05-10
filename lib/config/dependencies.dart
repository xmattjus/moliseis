import 'dart:async' show StreamController;

import 'package:flutter/material.dart' show Widget;
import 'package:moliseis/data/repositories/attraction/attraction_repository.dart';
import 'package:moliseis/data/repositories/attraction/attraction_repository_local.dart';
import 'package:moliseis/data/repositories/gallery/gallery_repository.dart';
import 'package:moliseis/data/repositories/gallery/gallery_repository_local.dart';
import 'package:moliseis/data/repositories/place/place_repository.dart';
import 'package:moliseis/data/repositories/place/place_repository_local.dart';
import 'package:moliseis/data/repositories/search/search_repository.dart';
import 'package:moliseis/data/repositories/search/search_repository_local.dart';
import 'package:moliseis/data/repositories/settings/settings_repository.dart';
import 'package:moliseis/data/repositories/settings/settings_repository_local.dart';
import 'package:moliseis/data/repositories/story/paragraph_repository.dart';
import 'package:moliseis/data/repositories/story/paragraph_repository_local.dart';
import 'package:moliseis/data/repositories/story/story_repository.dart';
import 'package:moliseis/data/repositories/story/story_repository_local.dart';
import 'package:moliseis/domain/models/attraction/attraction_supabase_table.dart';
import 'package:moliseis/domain/models/molis_image/image_supabase_table.dart';
import 'package:moliseis/domain/models/paragraph/paragraph_supabase_table.dart';
import 'package:moliseis/domain/models/place/place_supabase_table.dart';
import 'package:moliseis/domain/models/story/story_supabase_table.dart';
import 'package:moliseis/domain/use-cases/sync/sync_start_use_case.dart';
import 'package:moliseis/main.dart';
import 'package:moliseis/ui/categories/view_models/categories_view_model.dart';
import 'package:moliseis/ui/explore/view_models/attraction_view_model.dart';
import 'package:moliseis/ui/explore/view_models/place_view_model.dart';
import 'package:moliseis/ui/favourite/view_models/favourite_view_model.dart';
import 'package:moliseis/ui/gallery/view_models/gallery_view_model.dart';
import 'package:moliseis/ui/geo_map/view_models/geo_map_view_model.dart';
import 'package:moliseis/ui/search/view_models/search_view_model.dart';
import 'package:moliseis/ui/settings/view_models/settings_view_model.dart';
import 'package:moliseis/ui/settings/view_models/theme_view_model.dart';
import 'package:moliseis/ui/sync/view_models/sync_view_model.dart';
import 'package:moliseis/utils/app_url_launcher.dart';
import 'package:provider/provider.dart';
import 'package:provider/single_child_widget.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

List<SingleChildWidget> get providers {
  return <SingleChildWidget>[
    //#region Repositories (sorted by name ascending)
    Provider(
      create: (_) {
        return AttractionRepositoryLocal(
              supabaseI: Supabase.instance,
              attractionSupabaseTable: AttractionSupabaseTable(),
              objectBoxI: objectBox,
            )
            as AttractionRepository;
      },
      lazy: true,
    ),
    Provider(
      create: (_) {
        return GalleryRepositoryLocal(
              supabaseI: Supabase.instance,
              imageSupabaseTable: ImageSupabaseTable(),
              objectBoxI: objectBox,
            )
            as GalleryRepository;
      },
      lazy: true,
    ),
    Provider(
      create: (_) {
        return ParagraphRepositoryLocal(
              supabaseI: Supabase.instance,
              supabaseTable: ParagraphSupabaseTable(),
              objectBoxI: objectBox,
            )
            as ParagraphRepository;
      },
      lazy: true,
    ),
    Provider(
      create: (_) {
        return PlaceRepositoryLocal(
              supabaseI: Supabase.instance,
              placeSupabaseTable: PlaceSupabaseTable(),
              objectBoxI: objectBox,
            )
            as PlaceRepository;
      },
      lazy: true,
    ),
    Provider(
      create: (_) {
        return SearchRepositoryLocal(objectBoxI: objectBox) as SearchRepository;
      },
      lazy: true,
    ),
    Provider(
      create: (context) {
        return SettingsRepositoryLocal(objectBoxI: objectBox)
            as SettingsRepository;
      },
      lazy: true,
    ),
    Provider(
      create: (_) {
        return StoryRepositoryLocal(
              supabaseI: Supabase.instance,
              supabaseTable: StorySupabaseTable(),
              objectBoxI: objectBox,
            )
            as StoryRepository;
      },
      lazy: true,
    ),
    //#endregion

    //#region UseCases (sorted by name)
    Provider<SyncStartUseCase>(
      create: (context) {
        return SyncStartUseCase(
          attractionRepository: context.read(),
          galleryRepository: context.read(),
          //paragraphRepository: context.read(),
          placeRepository: context.read(),
          settingsRepository: context.read(),
          //storyRepository: context.read(),
        );
      },
      lazy: true,
    ),
    //#endregion

    //#region ViewModels (sorted by use!)
    ChangeNotifierProvider<ThemeViewModel>(
      create: (context) {
        return ThemeViewModel(settingsRepository: context.read());
      },
      lazy: true,
    ),
    ChangeNotifierProvider<SettingsViewModel>(
      create: (context) {
        return SettingsViewModel(settingsRepository: context.read());
      },
      lazy: true,
    ),
    ChangeNotifierProvider<AttractionViewModel>(
      create: (context) {
        return AttractionViewModel(attractionRepository: context.read());
      },
      lazy: true,
    ),
    ChangeNotifierProvider<GalleryViewModel>(
      create: (context) {
        return GalleryViewModel(
          attractionRepository: context.read(),
          galleryRepository: context.read(),
        );
      },
      lazy: true,
    ),
    ChangeNotifierProvider<GeoMapViewModel>(
      create: (context) {
        return GeoMapViewModel(attractionRepository: context.read());
      },
      lazy: true,
    ),
    Provider<PlaceViewModel>(
      create: (context) {
        return PlaceViewModel(placeRepository: context.read());
      },
      lazy: true,
    ),
    ChangeNotifierProvider<SearchViewModel>(
      create: (context) {
        return SearchViewModel(
          attractionRepository: context.read(),
          searchRepository: context.read(),
        );
      },
      lazy: true,
    ),
    ChangeNotifierProvider<CategoriesViewModel>(
      create: (context) {
        return CategoriesViewModel(attractionRepository: context.read());
      },
      lazy: true,
    ),
    ChangeNotifierProvider<SyncViewModel>(
      create: (context) {
        return SyncViewModel(
          syncStartUseCase: context.read(),
          settingsRepository: context.read(),
        );
      },
      lazy: true,
    ),
    ChangeNotifierProvider<FavouriteViewModel>(
      create: (context) {
        return FavouriteViewModel(attractionRepository: context.read());
      },
    ),
    //#endregion

    //#region Other
    Provider<AppUrlLauncher>(create: (_) => AppUrlLauncher(), lazy: true),
    Provider<StreamController<Widget>>(
      create: (_) => StreamController<Widget>.broadcast(),
      lazy: true,
      dispose: (_, value) => value.close(),
    ),
    //#endregion
  ];
}
