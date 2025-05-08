import 'dart:math' show min;

import 'package:flutter/material.dart';
import 'package:moliseis/data/repositories/attraction/attraction_repository.dart';
import 'package:moliseis/data/repositories/gallery/gallery_repository.dart';
import 'package:moliseis/domain/models/attraction/attraction.dart';
import 'package:moliseis/domain/models/attraction/attraction_sort.dart';
import 'package:moliseis/domain/models/molis_image/molis_image.dart';
import 'package:moliseis/utils/exceptions.dart';

class GalleryViewModel extends ChangeNotifier {
  final AttractionRepository _attractionRepository;
  final GalleryRepository _galleryRepository;
  List<MolisImage>? _allImages;

  GalleryViewModel({
    required AttractionRepository attractionRepository,
    required GalleryRepository galleryRepository,
  }) : _attractionRepository = attractionRepository,
       _galleryRepository = galleryRepository;

  Future<List<Attraction>> getAllAttractions(AttractionSort sortBy) =>
      _attractionRepository.getAll(sortBy);

  List<MolisImage> getAllImages(AttractionSort sortBy) {
    if (_allImages != null) {
      return List.unmodifiable(_allImages!);
    } else {
      return _galleryRepository.getAllImages(sortBy);
    }
  }

  /// Returns a Future containing the hero image of an [Attraction].
  Future<MolisImage> getHeroFromAttractionId(int id) async {
    try {
      final images = getAllImages(
        AttractionSort.byName,
      ).where((element) => element.attraction.targetId == id);

      if (images.isEmpty) {
        throw StateError('');
      }

      final test = images.map((e) => e.id).reduce(min);

      return images.singleWhere((element) => element.id == test);
    } catch (error) {
      return Future.error(MolisImageNullException(id));
    }
  }
}
