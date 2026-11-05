import 'dart:async';
import 'dart:io' show SocketException;

import 'package:http/http.dart' show ClientException;
import 'package:moliseis/utils/logging/log_event.dart';

/// Classifies by type, never by potentially private error messages.
SyncFailureCategory syncFailureCategory(Object error) => switch (error) {
  TimeoutException() ||
  ClientException() ||
  SocketException() => SyncFailureCategory.connectivity,
  FormatException() => SyncFailureCategory.contract,
  _ => SyncFailureCategory.unexpected,
};
