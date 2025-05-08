class AttractionNullException implements Exception {
  final int id;

  AttractionNullException(this.id);

  @override
  String toString() {
    return 'No Attraction with id: $id has been found in the Attractions box.';
  }
}

class MolisImageNullException implements Exception {
  final int id;

  MolisImageNullException(this.id);

  @override
  String toString() {
    return 'No MolisImage from attraction id: $id has been found in the '
        'MolisImages box.';
  }
}

class PlaceNullException implements Exception {
  final int id;

  PlaceNullException(this.id);

  @override
  String toString() {
    return 'No Place from attraction id: $id has been found in the Places box.';
  }
}
