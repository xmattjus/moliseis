import 'package:flutter/material.dart';
import 'package:moliseis/data/repositories/attraction/attraction_repository.dart';
import 'package:moliseis/data/repositories/gallery/gallery_repository.dart';
import 'package:moliseis/data/repositories/story/story_repository.dart';
import 'package:moliseis/domain/models/attraction/attraction.dart';
import 'package:moliseis/domain/models/molis_image/molis_image.dart';
import 'package:moliseis/domain/models/story/story.dart';
import 'package:moliseis/utils/command.dart';
import 'package:moliseis/utils/result.dart';

class StoryViewModel extends ChangeNotifier {
  StoryViewModel({
    required AttractionRepository attractionRepository,
    required GalleryRepository galleryRepository,
    required StoryRepository storyRepository,
  }) : _attractionRepository = attractionRepository,
       _storyRepository = storyRepository,
       _galleryRepository = galleryRepository {
    load = Command1(_load);
  }

  final AttractionRepository _attractionRepository;
  final GalleryRepository _galleryRepository;
  final StoryRepository _storyRepository;

  Attraction? _attraction;
  List<MolisImage> _images = [];
  Story? _story;

  Attraction? get attraction => _attraction;
  List<MolisImage> get images => _images;
  Story? get story => _story;

  /// Loads data needed to display a Story.
  late Command1<void, int> load;

  Future<Result> _load(int id) async {
    final job0 = await _attractionRepository.getById(id);

    switch (job0) {
      case Success<Attraction>():
        _attraction = job0.value;
      case Error<Attraction>():
      // TODO: Handle this case.
    }

    final job1 = await _storyRepository.getStoriesFromAttractionId(id);

    switch (job1) {
      case Success<List<Story>>():
        _story = job1.value.first;
      case Error<List<Story>>():
      // TODO: Handle this case.
    }

    final job2 = await _galleryRepository.getImagesFromAttractionId(id);

    switch (job2) {
      case Success<List<MolisImage>>():
        _images = job2.value;
      case Error<List<MolisImage>>():
        // TODO: Handle this case.
        throw UnimplementedError();
    }

    notifyListeners();

    return job1;
  }
}
