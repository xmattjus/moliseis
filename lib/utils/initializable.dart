import 'package:moliseis/utils/result.dart';

/// Defines an asynchronous initialization contract.
///
/// Implementers load any required state before they can be safely consumed.
abstract interface class Initializable {
  /// Initializes the object state and returns its outcome.
  Future<Result<void>> initialize();
}
