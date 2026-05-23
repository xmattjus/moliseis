// Copyright 2024 The Flutter team. All rights reserved.
// Use of this source code is governed by a BSD-style license that can be
// found in the LICENSE file.

import 'dart:async' show FutureOr;

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
      case Success<T>(:final value):
        return onSuccess(value);
      case Error<T>(:final error):
        return onError(error);
    }
  }

  /// Maps a successful value to another type.
  ///
  /// Use this for synchronous transformations. For async mappers,
  /// use [asyncMap] instead.
  ///
  /// If [mapper] throws, the exception is propagated.
  Result<R> map<R>(R Function(T value) mapper) {
    return fold((value) => Result.success(mapper(value)), Result.error);
  }

  /// Chains another result-producing operation after a success.
  ///
  /// Use this for synchronous composition of two or more results. For async
  /// operations, use [asyncFlatMap] or [zip2] / [zip3] / [zip4] instead.
  ///
  /// If [mapper] throws, the exception is propagated.
  Result<R> flatMap<R>(Result<R> Function(T value) mapper) {
    return fold(mapper, Result.error);
  }

  /// Transforms the error of a failed result, leaving success unchanged.
  ///
  /// If [mapper] throws, the exception is propagated.
  Result<T> mapError(Exception Function(Exception error) mapper) {
    return switch (this) {
      Success<T>() => this,
      Error<T>(:final error) => Result.error(mapper(error)),
    };
  }

  /// Recovers from an error by chaining a result-producing operation.
  ///
  /// If [mapper] throws, the exception is propagated.
  Result<T> flatMapError(Result<T> Function(Exception error) mapper) {
    return switch (this) {
      Success<T>() => this,
      Error<T>(:final error) => mapper(error),
    };
  }

  /// Returns the value if successful, otherwise null.
  T? getOrNull() {
    return fold((value) => value, (_) => null);
  }

  /// Returns the value if successful, otherwise calls [defaultValue].
  T getOrElse(T Function() defaultValue) {
    return fold((value) => value, (_) => defaultValue());
  }

  /// Applies [onSuccess] or [onError], allowing async computations.
  Future<R> asyncFold<R>(
    FutureOr<R> Function(T value) onSuccess,
    FutureOr<R> Function(Exception error) onError,
  ) async {
    switch (this) {
      case Success<T>(:final value):
        return onSuccess(value);
      case Error<T>(:final error):
        return onError(error);
    }
  }

  /// Maps a successful value to another type, allowing async computation.
  ///
  /// If [mapper] throws, the exception is propagated.
  Future<Result<R>> asyncMap<R>(FutureOr<R> Function(T value) mapper) async {
    return switch (this) {
      Success<T>(:final value) => Result.success(await mapper(value)),
      Error<T>(:final error) => Result.error(error),
    };
  }

  /// Chains an async result-producing operation after a success.
  ///
  /// If [mapper] throws, the exception is propagated.
  Future<Result<R>> asyncFlatMap<R>(
    FutureOr<Result<R>> Function(T value) mapper,
  ) async {
    return switch (this) {
      Success<T>(:final value) => mapper(value),
      Error<T>(:final error) => Result.error(error),
    };
  }

  /// Transforms the error of a failed result asynchronously,
  /// leaving success unchanged.
  ///
  /// If [mapper] throws, the exception is propagated.
  Future<Result<T>> asyncMapError(
    FutureOr<Exception> Function(Exception error) mapper,
  ) async {
    return switch (this) {
      Success<T>() => this,
      Error<T>(:final error) => Result.error(await mapper(error)),
    };
  }

  /// Recovers from an error by chaining an async result-producing operation.
  ///
  /// If [mapper] throws, the exception is propagated.
  Future<Result<T>> asyncFlatMapError(
    FutureOr<Result<T>> Function(Exception error) mapper,
  ) async {
    return switch (this) {
      Success<T>() => this,
      Error<T>(:final error) => mapper(error),
    };
  }

  /// Returns the value if successful, otherwise calls [defaultValue]
  /// asynchronously.
  Future<T> asyncGetOrElse(FutureOr<T> Function() defaultValue) async {
    return switch (this) {
      Success<T>(:final value) => value,
      Error<T>() => defaultValue(),
    };
  }

  /// True if this Result is a successful value.
  bool get isSuccess => this is Success<T>;

  /// True if this Result is an error.
  bool get isError => this is Error<T>;

  /// Runs [a] then [b] sequentially, short-circuiting on the first error.
  ///
  /// Use this to combine two independent async operations while propagating
  /// errors without manual `await` / `switch` boilerplate. For synchronous
  /// composition, use [flatMap] and [map] instead.
  ///
  /// On success, calls [onSuccess] with both unwrapped values and returns its
  /// result. [onSuccess] may itself return a [Result.error].
  static Future<Result<R>> zip2<A, B, R>(
    Future<Result<A>> Function() a,
    Future<Result<B>> Function() b,
    FutureOr<Result<R>> Function(A a, B b) onSuccess,
  ) async {
    final resultA = await a();
    final A valueA;
    switch (resultA) {
      case Error<A>(:final error):
        return Result.error(error);
      case Success<A>(:final value):
        valueA = value;
    }
    final resultB = await b();
    final B valueB;
    switch (resultB) {
      case Error<B>(:final error):
        return Result.error(error);
      case Success<B>(:final value):
        valueB = value;
    }
    return await onSuccess(valueA, valueB);
  }

  /// Runs [a], [b], [c] sequentially, short-circuiting on the first error.
  ///
  /// Use this to combine three independent async operations while propagating
  /// errors without manual `await` / `switch` boilerplate. For synchronous
  /// composition, use [flatMap] and [map] instead.
  ///
  /// On success, calls [onSuccess] with all three unwrapped values and returns
  /// its result. [onSuccess] may itself return a [Result.error].
  static Future<Result<R>> zip3<A, B, C, R>(
    Future<Result<A>> Function() a,
    Future<Result<B>> Function() b,
    Future<Result<C>> Function() c,
    FutureOr<Result<R>> Function(A a, B b, C c) onSuccess,
  ) async {
    final resultA = await a();
    final A valueA;
    switch (resultA) {
      case Error<A>(:final error):
        return Result.error(error);
      case Success<A>(:final value):
        valueA = value;
    }
    final resultB = await b();
    final B valueB;
    switch (resultB) {
      case Error<B>(:final error):
        return Result.error(error);
      case Success<B>(:final value):
        valueB = value;
    }
    final resultC = await c();
    final C valueC;
    switch (resultC) {
      case Error<C>(:final error):
        return Result.error(error);
      case Success<C>(:final value):
        valueC = value;
    }
    return await onSuccess(valueA, valueB, valueC);
  }

  /// Runs [a], [b], [c], [d] sequentially, short-circuiting on the first error.
  ///
  /// Use this to combine four independent async operations while propagating
  /// errors without manual `await` / `switch` boilerplate. For synchronous
  /// composition, use [flatMap] and [map] instead.
  ///
  /// On success, calls [onSuccess] with all four unwrapped values and returns
  /// its result. [onSuccess] may itself return a [Result.error].
  static Future<Result<R>> zip4<A, B, C, D, R>(
    Future<Result<A>> Function() a,
    Future<Result<B>> Function() b,
    Future<Result<C>> Function() c,
    Future<Result<D>> Function() d,
    FutureOr<Result<R>> Function(A a, B b, C c, D d) onSuccess,
  ) async {
    final resultA = await a();
    final A valueA;
    switch (resultA) {
      case Error<A>(:final error):
        return Result.error(error);
      case Success<A>(:final value):
        valueA = value;
    }
    final resultB = await b();
    final B valueB;
    switch (resultB) {
      case Error<B>(:final error):
        return Result.error(error);
      case Success<B>(:final value):
        valueB = value;
    }
    final resultC = await c();
    final C valueC;
    switch (resultC) {
      case Error<C>(:final error):
        return Result.error(error);
      case Success<C>(:final value):
        valueC = value;
    }
    final resultD = await d();
    final D valueD;
    switch (resultD) {
      case Error<D>(:final error):
        return Result.error(error);
      case Success<D>(:final value):
        valueD = value;
    }
    return await onSuccess(valueA, valueB, valueC, valueD);
  }
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
