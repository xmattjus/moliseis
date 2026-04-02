// Copyright 2024 The Flutter team. All rights reserved.
// Use of this source code is governed by a BSD-style license that can be
// found in the LICENSE file.

/// Represents either a successful value or an exception.
sealed class Result<T> {
  const Result();

  /// Creates a successful result with [value].
  const factory Result.success(T value) = Success._;

  /// Creates a failed result with [error].
  const factory Result.error(Exception error) = Error._;

  /// Applies [onSuccess] or [onError] to the current result.
  R fold<R>(
    R Function(T value) onSuccess,
    R Function(Exception error) onError,
  ) {
    switch (this) {
      case Success<T>(value: final value):
        return onSuccess(value);
      case Error<T>(error: final error):
        return onError(error);
    }
  }

  /// Maps a successful value to another type.
  ///
  /// If [mapper] throws, the exception is propagated.
  Result<R> map<R>(R Function(T value) mapper) {
    return fold((value) => Result.success(mapper(value)), Result.error);
  }

  /// Chains another result-producing operation after a success.
  ///
  /// If [mapper] throws, the exception is propagated.
  Result<R> flatMap<R>(Result<R> Function(T value) mapper) {
    return fold(mapper, Result.error);
  }

  /// Returns the value if successful, otherwise null.
  T? getOrNull() {
    return fold((value) => value, (_) => null);
  }

  /// Returns the value if successful, otherwise calls [defaultValue].
  T getOrElse(T Function() defaultValue) {
    return fold((value) => value, (_) => defaultValue());
  }

  /// True if this Result is a successful value.
  bool get isSuccess => this is Success<T>;

  /// True if this Result is an error.
  bool get isError => this is Error<T>;
}

/// Successful result value.
final class Success<T> extends Result<T> {
  const Success._(this.value);

  /// The wrapped value.
  final T value;

  @override
  String toString() => 'Result<$T>.success($value)';
}

/// Failed result value.
final class Error<T> extends Result<T> {
  const Error._(this.error);

  /// The wrapped exception.
  final Exception error;

  @override
  String toString() => 'Result<$T>.error($error)';
}
