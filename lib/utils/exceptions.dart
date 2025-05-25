class AttractionNullException implements Exception {
  const AttractionNullException(this.id);

  final int id;

  @override
  String toString() {
    return 'No Attraction with id: $id has been found in the Attractions box.';
  }
}

class MolisImageNullException implements Exception {
  const MolisImageNullException(this.id);

  final int id;

  @override
  String toString() {
    return 'No MolisImage from attraction id: $id has been found in the '
        'MolisImages box.';
  }
}

class PlaceNullException implements Exception {
  const PlaceNullException(this.id);

  final int id;

  @override
  String toString() {
    return 'No Place from attraction id: $id has been found in the Places box.';
  }
}
