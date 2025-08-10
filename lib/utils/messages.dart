/// A utility enum that provides standardized messages for common application events.
///
/// This enum centralizes message templates used throughout the application,
/// particularly during repository synchronization operations. It provides
/// both static message templates and dynamic methods for generating messages
/// with specific object names and IDs.
///
/// Example usage:
/// ```dart
/// // Static messages
/// print(Messages.repositoryUpdate);
///
/// // Dynamic messages
/// print(Messages.objectInsert('User', 123));
/// print(Messages.objectUpdate('Product', 456));
/// ```
enum Messages {
  /// Template message for object insertion operations.
  /// Contains placeholders for object name and remote ID.
  _objectInsert('Inserting <object> with remote ID: <id>.'),

  /// Template message for object update operations.
  /// Contains placeholders for object name and remote ID.
  _objectUpdate('Updating <object> with remote ID: <id>.'),

  /// Message displayed during repository synchronization.
  _repositoryUpdate('Synchronizing the repository.'),

  /// Error message displayed when repository synchronization fails.
  _repositoryUpdateException(
    'An exception occurred while synchronizing the repository.',
  );

  /// Creates a Messages enum value with the specified text template.
  ///
  /// [text] The message template string, may contain placeholders.
  const Messages(this.text);

  /// The message template string for this enum value.
  final String text;

  /// Generates a formatted message for object insertion operations.
  ///
  /// Replaces placeholders in the insertion template with the provided
  /// object name and ID.
  ///
  /// [objectName] The name of the object being inserted.
  /// [id] The remote ID of the object being inserted.
  ///
  /// Returns a formatted string with placeholders replaced.
  ///
  /// Example:
  /// ```dart
  /// String message = Messages.objectInsert('User', 123);
  /// // Returns: "Inserting User with remote id 123."
  /// ```
  static String objectInsert(String objectName, int id) => Messages
      ._objectInsert
      .text
      .replaceAll('<object>', objectName)
      .replaceAll('<id>', '$id');

  /// Generates a formatted message for object update operations.
  ///
  /// Replaces placeholders in the update template with the provided
  /// object name and ID.
  ///
  /// [objectName] The name of the object being updated.
  /// [id] The remote ID of the object being updated.
  ///
  /// Returns a formatted string with placeholders replaced.
  ///
  /// Example:
  /// ```dart
  /// String message = Messages.objectUpdate('Product', 456);
  /// // Returns: "Updating Product with remote id 456."
  /// ```
  static String objectUpdate(String objectName, int id) => Messages
      ._objectUpdate
      .text
      .replaceAll('<object>', objectName)
      .replaceAll('<id>', '$id');

  /// Gets the repository synchronization message.
  ///
  /// Returns the standard message displayed during repository sync operations.
  static String get repositoryUpdate => Messages._repositoryUpdate.text;

  /// Gets the repository synchronization error message.
  ///
  /// Returns the standard error message displayed when repository
  /// synchronization operations fail.
  static String get repositoryUpdateException =>
      Messages._repositoryUpdateException.text;
}
