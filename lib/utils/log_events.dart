enum LogEvents {
  _imageLoadingError('Error during image loading'),
  _imageSharingError('Error during image sharing'),
  _repositoryUpdate('Synchronizing repository'),
  _repositoryUpdateError('Error during repository synchronization');

  const LogEvents(this.text);

  final String text;

  static String get imageLoadingError => LogEvents._imageLoadingError.text;
  static String get imageSharingError => LogEvents._imageSharingError.text;
  static String get repositoryUpdate => LogEvents._repositoryUpdate.text;
  static String repositoryUpdateError(Object? error) =>
      '${LogEvents._repositoryUpdateError.text} $error';
}
