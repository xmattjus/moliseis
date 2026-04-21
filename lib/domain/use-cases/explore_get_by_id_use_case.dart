import 'package:moliseis/domain/models/place.dart';
import 'package:moliseis/utils/result.dart';

/// Defines the ability to retrieve a single piece of explore content by ID.
abstract class ExploreGetByIdUseCase {
  /// Returns the [Place] for [id].
  ///
  /// Repository failures are propagated as [Result.error].
  Future<Result<Place>> getById(int id);
}
