import 'package:moliseis/data/data-sources/media_entity.dart';
import 'package:moliseis/domain/models/media.dart';

/// Conversion extensions from [MediaEntity] to the [Media] domain model.
extension MediaEntityExtensions on MediaEntity {
  /// Maps a [MediaEntity] to a [Media] domain model.
  Media toModel() {
    var areaName = '';
    var cityName = '';

    if (place.hasValue && !event.hasValue) {
      areaName = place.target?.name ?? '';
      cityName = place.target?.city.target?.name ?? '';
    } else if (!place.hasValue && event.hasValue) {
      areaName = event.target?.name ?? '';
      cityName = event.target?.city.target?.name ?? '';
    }

    return Media(
      remoteId: remoteId,
      title: title,
      author: author,
      license: license,
      licenseUrl: licenseUrl,
      url: url,
      width: width,
      height: height,
      createdAt: createdAt,
      modifiedAt: modifiedAt,
      areaName: areaName,
      cityName: cityName,
    );
  }
}
