class CityNullException implements Exception {
  const CityNullException(this.id);

  final int id;

  @override
  String toString() {
    return 'No City from Place remote ID: $id has been found in the City box.';
  }
}

class CloudinaryEmptyResponseException implements Exception {
  const CloudinaryEmptyResponseException();

  @override
  String toString() {
    return 'Cloudinary returned an empty response.';
  }
}

class CloudinaryEmptyUrlException implements Exception {
  const CloudinaryEmptyUrlException();

  @override
  String toString() {
    return 'Cloudinary returned an empty url.';
  }
}

class CloudinaryNullResponseException implements Exception {
  const CloudinaryNullResponseException();

  @override
  String toString() {
    return 'Cloudinary returned no response (null).';
  }
}

class MediaNullException implements Exception {
  const MediaNullException(this.id);

  final int id;

  @override
  String toString() {
    return 'No Media from Place remote ID: $id has been found in the Media box.';
  }
}

class PlaceNullException implements Exception {
  const PlaceNullException(this.id);

  final int id;

  @override
  String toString() {
    return 'No Place with remote ID: $id has been found in the Places box.';
  }
}
