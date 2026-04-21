import 'package:meta/meta.dart';

/// A city in the Molise region.
@immutable
class City {
  const City({
    required this.remoteId,
    required this.name,
    required this.createdAt,
    required this.modifiedAt,
  });

  final int remoteId;
  final String name;
  final DateTime createdAt;
  final DateTime modifiedAt;
}
