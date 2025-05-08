import 'package:moliseis/domain/models/attraction/attraction_sort.dart';
import 'package:moliseis/domain/models/molis_image/molis_image.dart';
import 'package:moliseis/utils/result.dart';

abstract class GalleryRepository {
  List<MolisImage> getAllImages(AttractionSort sortBy);

  Future<Result<List<MolisImage>>> getImagesFromAttractionId(int id);

  Future<Result<void>> synchronize();
}
