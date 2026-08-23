import 'dart:async' show StreamController, TimeoutException, Timer, unawaited;
import 'dart:convert' show jsonDecode, utf8;
import 'dart:io' show File, HttpClient, HttpException, HttpHeaders;

import 'package:meta/meta.dart';
import 'package:moliseis/data/services/api/cloudinary/cloudinary_asset_mime_type.dart';
import 'package:moliseis/data/services/api/cloudinary/cloudinary_duplicate_detector.dart';
import 'package:moliseis/data/services/api/cloudinary/cloudinary_multipart_writer.dart';
import 'package:moliseis/data/services/api/cloudinary/cloudinary_public_id_generator.dart';
import 'package:moliseis/data/services/api/cloudinary/cloudinary_signer.dart';
import 'package:moliseis/data/services/api/cloudinary/cloudinary_upload_cancellation_token.dart';
import 'package:moliseis/data/services/api/cloudinary/cloudinary_upload_client.dart';
import 'package:moliseis/data/services/api/cloudinary/cloudinary_upload_options.dart';
import 'package:moliseis/data/services/api/cloudinary/exceptions/empty_url_exception.dart';
import 'package:moliseis/data/services/api/cloudinary/exceptions/file_too_large_exception.dart';
import 'package:moliseis/data/services/api/cloudinary/exceptions/invalid_asset_dimensions.dart';
import 'package:moliseis/data/services/api/cloudinary/exceptions/upload_cancelled_exception.dart';
import 'package:moliseis/domain/models/image_upload_task.dart';
import 'package:moliseis/domain/models/submission_asset.dart';
import 'package:moliseis/utils/constants.dart';
import 'package:moliseis/utils/logging/logging.dart';
import 'package:moliseis/utils/result.dart';
import 'package:moliseis/utils/string_validator.dart';
import 'package:path/path.dart' as p;

// TODO(xmattjus): The API secret is currently embedded in the app via Envied
//  and signing happens client-side. Cloudinary's documentation explicitly
//  warns against exposing the API secret in mobile/client-side code. Move
//  signature generation to a backend signing service, or switch to unsigned
//  uploads with an upload preset, before relying on this in production.
/// Concrete Cloudinary upload client backed by a dedicated [HttpClient].
class CloudinaryUploadClientImpl implements CloudinaryUploadClient {
  /// Creates a client that owns a dedicated [HttpClient].
  CloudinaryUploadClientImpl({
    required Logger logger,
    required String cloudName,
    required String apiKey,
    required String apiSecret,
    @visibleForTesting String? baseUrl,
    @visibleForTesting Duration uploadTimeout = const Duration(seconds: 30),
  }) : _logger = logger,
       _cloudName = cloudName,
       _apiKey = apiKey,
       _baseUrl = baseUrl,
       _uploadTimeout = uploadTimeout,
       _httpClient = HttpClient()
         ..connectionTimeout = const Duration(
           seconds: kDefaultNetworkTimeoutSeconds,
         )
         ..idleTimeout = const Duration(seconds: 15)
         ..userAgent = kUserAgent,
       _signer = CloudinarySigner(apiSecret: apiSecret),
       _publicIdGenerator = CloudinaryPublicIdGenerator() {
    _duplicateDetector = CloudinaryDuplicateDetector(
      httpClient: _httpClient,
      cloudName: cloudName,
      apiKey: apiKey,
      apiSecret: apiSecret,
      baseUrl: baseUrl,
    );
  }

  static const _kMaxUploadAttempts = 3;
  static const _kUploadRetryBaseDelay = Duration(milliseconds: 500);
  // Upper bound for the exponential backoff delay between retries, so the
  // delay never grows unbounded even if [_kMaxUploadAttempts] is raised.
  static const _kUploadRetryMaxDelay = Duration(seconds: 10);

  final Logger _logger;
  final String _cloudName;
  final String _apiKey;
  final String? _baseUrl;
  final Duration _uploadTimeout;
  final HttpClient _httpClient;
  final CloudinarySigner _signer;
  final CloudinaryPublicIdGenerator _publicIdGenerator;
  late final CloudinaryDuplicateDetector _duplicateDetector;

  /// Uploads [image] to Cloudinary, skipping duplicates by SHA-256 content
  /// hash.
  ///
  /// [CloudinaryPublicIdGenerator] derives a deterministic public id of the
  /// form `content_submissions/<sha256>` from [image]. Before transferring
  /// any bytes, [_lookupDuplicate] queries Cloudinary for that public id:
  /// if an asset already exists under it (i.e. the media was successfully
  /// sent to the backend in a previous attempt), the existing [SubmissionAsset]
  /// is returned and the multipart upload is skipped entirely. This makes the
  /// upload idempotent across retries triggered by partial failures higher up
  /// the call chain.
  ///
  /// Set `options.overwrite` to `true` to force a fresh upload and bypass the
  /// duplicate lookup.
  @override
  ImageUploadTask uploadImageTask(
    File image, {
    CloudinaryUploadOptions options = const CloudinaryUploadOptions(),
  }) {
    final token = CloudinaryUploadCancellationToken(logger: _logger);
    final progressController = StreamController<double>.broadcast();

    final resultFuture =
        _upload(
          image: image,
          options: options,
          token: token,
          progressController: progressController,
        ).whenComplete(() {
          if (!progressController.isClosed) {
            unawaited(progressController.close());
          }
        });

    return _CloudinaryUploadTask(
      resultFuture: resultFuture,
      progressController: progressController,
      token: token,
    );
  }

  @override
  void dispose() {
    _httpClient.close(force: true);
  }

  Future<Result<SubmissionAsset>> _upload({
    required File image,
    required CloudinaryUploadOptions options,
    required CloudinaryUploadCancellationToken token,
    required StreamController<double> progressController,
  }) async {
    // Defense-in-depth: reject files above Cloudinary's size limit before any
    // bytes hit the network. The view-model picker also filters by size, but
    // this guard protects any future call site and avoids a wasteful multipart
    // stream that Cloudinary would reject with HTTP 400 "File size too large"
    // after the upload had already started.
    final length = await image.length();
    if (length > kCloudinaryMaxUploadBytes) {
      return _finalizeUploadResult(
        Result.error(
          FileTooLargeException(
            actualBytes: length,
            maxBytes: kCloudinaryMaxUploadBytes,
          ),
        ),
        token,
      );
    }

    _logger.log(const CloudinaryRequestStarted());
    progressController.add(0);

    try {
      final publicId =
          options.publicId ?? await _publicIdGenerator.generate(image);
      final existingUrl = await _lookupDuplicate(
        publicId,
        overwrite: options.overwrite,
        token: token,
      );

      if (existingUrl != null) {
        _logger.log(CloudinaryDuplicateDetected(publicId: publicId));
        progressController.add(1);
        return Result.success(existingUrl);
      }

      final fields = _buildUploadFields(publicId, options);
      final multipartWriter = CloudinaryMultipartWriter(
        file: image,
        fields: fields,
        fileName: _fileName(image),
      );

      final baseUri = Uri.parse(_baseUrl ?? 'https://api.cloudinary.com');
      final uri = baseUri.replace(
        path: '/v1_1/$_cloudName/image/upload',
      );

      return await _uploadWithRetries(
        uri: uri,
        multipartWriter: multipartWriter,
        publicId: publicId,
        token: token,
        progressController: progressController,
      );
    } on Exception catch (exception, stackTrace) {
      if (_handlePotentialCancellation(exception, token, stackTrace)) {
        return const Result.error(UploadCancelledException());
      }
      return _finalizeUploadResult(
        Result.error(
          token.isCancelled ? const UploadCancelledException() : exception,
        ),
        token,
        stackTrace: stackTrace,
      );
    } finally {
      // Guard against the controller already being closed by the timeout
      // path's whenComplete callback, which fires as soon as resultFuture
      // resolves and may precede this finally block.
      if (!progressController.isClosed) {
        await progressController.close();
      }
    }
  }

  Future<SubmissionAsset?> _lookupDuplicate(
    String publicId, {
    required bool overwrite,
    required CloudinaryUploadCancellationToken token,
  }) async {
    if (overwrite) {
      return null;
    }

    final duplicateResult = await _duplicateDetector.checkExists(
      publicId,
      token: token,
    );
    switch (duplicateResult) {
      case Success<SubmissionAsset?>(:final value):
        return value;
      case Error<SubmissionAsset?>(:final error):
        _logger.log(
          const CloudinaryRequestFailed(detail: 'duplicate_lookup_failed'),
          error: error,
        );
        return null;
    }
  }

  Map<String, String> _buildUploadFields(
    String publicId,
    CloudinaryUploadOptions options,
  ) {
    final timestamp = DateTime.now().millisecondsSinceEpoch ~/ 1000;
    final paramsToSign = <String, String>{
      'public_id': publicId,
      'timestamp': timestamp.toString(),
    };

    final transformation = _buildTransformation(options);
    if (transformation != null) {
      paramsToSign['transformation'] = transformation;
    }

    if (options.tags.isNotEmpty) {
      // Commas are the Cloudinary tag separator; a tag containing a comma
      // would silently create multiple tags and corrupt the signed payload.
      assert(
        options.tags.every((tag) => !tag.contains(',')),
        'Tag names must not contain commas',
      );
      paramsToSign['tags'] = options.tags.join(',');
    }

    if (options.context.isNotEmpty) {
      // Context is encoded as `key=value` pairs joined by `|`.  Both keys and
      // values are URI-encoded so that literal `=`, `|`, and `&` characters do
      // not corrupt the format or produce a signature mismatch.
      paramsToSign['context'] = options.context.entries
          .map(
            (e) =>
                '${Uri.encodeQueryComponent(e.key)}'
                '=${Uri.encodeQueryComponent(e.value)}',
          )
          .join('|');
    }

    if (options.overwrite) {
      paramsToSign['overwrite'] = 'true';
    }

    return <String, String>{
      'api_key': _apiKey,
      ...paramsToSign,
      'signature': _signer.sign(paramsToSign),
    };
  }

  Future<Result<SubmissionAsset>> _uploadWithRetries({
    required Uri uri,
    required CloudinaryMultipartWriter multipartWriter,
    required String publicId,
    required CloudinaryUploadCancellationToken token,
    required StreamController<double> progressController,
  }) async {
    final totalLength = await multipartWriter.computeTotalLength();
    Result<SubmissionAsset>? result;
    StackTrace? lastErrorStackTrace;
    // Single-cell list used as mutable state captured by _executeUploadAttempt:
    // it records the highest progress value emitted across all retry attempts
    // so the [progressController] stream is monotonically non-decreasing even
    // when a retry restarts from zero bytes uploaded (see the guard at the
    // streaming site below).
    final progressFloor = [0.0];

    for (var attempt = 1; attempt <= _kMaxUploadAttempts; attempt++) {
      if (token.isCancelled) {
        result = const Result.error(UploadCancelledException());
        break;
      }

      try {
        result = await _executeUploadAttempt(
          uri: uri,
          multipartWriter: multipartWriter,
          totalLength: totalLength,
          publicId: publicId,
          token: token,
          progressController: progressController,
          progressFloor: progressFloor,
          attempt: attempt,
        );
      } on Exception catch (exception, stackTrace) {
        // Only non-timeout exceptions reach here: timeouts are converted to
        // a `Result.error(TimeoutException)` inside [_executeUploadAttempt]
        // so the in-flight request can be aborted before the retry loop
        // issues a fresh one (otherwise the timed-out attempt would keep
        // streaming in the background and compete with the retry for the
        // same spotty uplink that caused the timeout).
        if (token.isCancelled) {
          result = const Result.error(UploadCancelledException());
          break;
        }
        // Thrown (non-timeout) exceptions are not retryable: bail out on the
        // first failure. The terminal error is logged exactly once by
        // [_finalizeUploadResult]; the stack trace is retained so that the
        // single log preserves the original failure site.
        lastErrorStackTrace = stackTrace;
        result = Result.error(exception);
        break;
      }

      if (result case Success<SubmissionAsset>()) {
        break;
      }

      if (result case Error<SubmissionAsset>(:final error)) {
        // Retry on HTTP 5xx (server errors) or TimeoutException (transient
        // network conditions — spotty mobile uplinks are common).
        final isRetryable =
            (error is _UploadHttpException &&
                error.statusCode >= 500 &&
                error.statusCode < 600) ||
            error is TimeoutException;
        if (!isRetryable || attempt == _kMaxUploadAttempts) {
          break;
        }
        final exception = error is TimeoutException
            ? 'timeout'
            : 'http_${(error as _UploadHttpException).statusCode}';

        _logger.log(
          CloudinaryRequestFailed(
            detail: '${exception}_attempt_$attempt',
          ),
        );
      }

      if (attempt < _kMaxUploadAttempts) {
        final multiplier = 1 << (attempt - 1);
        final delay = _kUploadRetryBaseDelay * multiplier;
        await Future<void>.delayed(
          delay > _kUploadRetryMaxDelay ? _kUploadRetryMaxDelay : delay,
        );
      }
    }

    return _finalizeUploadResult(
      result,
      token,
      stackTrace: lastErrorStackTrace,
    );
  }

  Future<Result<SubmissionAsset>> _executeUploadAttempt({
    required Uri uri,
    required CloudinaryMultipartWriter multipartWriter,
    required int totalLength,
    required String publicId,
    required CloudinaryUploadCancellationToken token,
    required StreamController<double> progressController,
    required List<double> progressFloor,
    required int attempt,
  }) async {
    final request = await _httpClient.postUrl(uri);
    // Note on connect-phase asymmetry: this postUrl is bounded by the
    // HttpClient.connectionTimeout (10s, see the constructor), while the
    // subsequent streaming/upload phase is bounded by [_uploadTimeout] via
    // the per-attempt timer below. A connect timeout surfaces as a
    // SocketException, which the retry loop classifies as non-retryable, so a
    // transient connect timeout never triggers a retry — only streaming
    // timeouts (TimeoutException) do. This is intentional: a connect timeout
    // typically indicates a reachable-but-unresponsive edge or a misconfigured
    // URL, whereas streaming timeouts track a spotty established uplink worth
    // retrying. Worth keeping in mind if the connectionTimeout is ever tuned.
    token.attach(request);
    request.headers.set(
      HttpHeaders.contentTypeHeader,
      multipartWriter.contentType,
    );
    request.headers.set(
      HttpHeaders.contentLengthHeader,
      totalLength,
    );

    // Per-attempt timeout: abort the underlying request so its socket is
    // closed and the retry does not compete with a zombie upload for the
    // same spotty uplink. Aborting via the token (rather than a generic
    // `Future.timeout(...)` wrapper) ensures the request is actually
    // cancelled, and the token distinguishes this from a caller-driven
    // [CloudinaryUploadCancellationToken.cancel] so the retry loop can
    // issue a fresh request on the next iteration.
    var timedOut = false;
    final timer = Timer(_uploadTimeout, () {
      timedOut = true;
      token.abortCurrentRequest();
    });

    try {
      var uploaded = 0;
      await for (final chunk in multipartWriter.write()) {
        if (token.isCancelled) {
          throw const UploadCancelledException();
        }
        request.add(chunk);
        uploaded += chunk.length;
        if (totalLength > 0) {
          final progress = (uploaded / totalLength).clamp(0.0, 1.0);
          if (progress >= progressFloor[0]) {
            progressFloor[0] = progress;
            progressController.add(progress);
          }
        }
      }

      final response = await request.close();
      if (response.statusCode < 200 || response.statusCode >= 300) {
        // Capture the error body for diagnostics before draining.
        final errorBodyBytes = <int>[];
        await response.forEach(errorBodyBytes.addAll);
        final errorBody = utf8.decode(errorBodyBytes, allowMalformed: true);
        return Result.error(
          _UploadHttpException(response.statusCode, errorBody),
        );
      }

      final responseBytes = <int>[];
      await response.forEach(responseBytes.addAll);
      final responseJson =
          jsonDecode(utf8.decode(responseBytes)) as Map<String, dynamic>;
      final secureUrl = responseJson['secure_url'] as String?;

      final width = responseJson['width'] as int?;
      final height = responseJson['height'] as int?;

      if (secureUrl == null || !StringValidator.isValidUrl(secureUrl)) {
        return const Result.error(EmptyUrlException());
      }

      if (width == null || width <= 0 || height == null || height <= 0) {
        return const Result.error(InvalidAssetDimensions());
      }

      final submissionAsset = SubmissionAsset(
        secureUrl: secureUrl,
        width: width,
        height: height,
        mimeType: cloudinaryImageMimeType(responseJson['format']),
      );

      _logger.log(CloudinaryUploadCompleted(publicId: publicId));
      progressController.add(1);
      return Result.success(submissionAsset);
    } on Exception catch (exception) {
      if (timedOut) {
        // The timer fired and aborted the request: the thrown exception
        // (typically `HttpException` from `request.add`/`close`) is a
        // symptom of the timeout, not the root cause. Surface a
        // `TimeoutException` so the retry classification treats this as
        // a transient failure.
        return Result.error(
          TimeoutException(
            'Cloudinary upload attempt $attempt timed out after '
            '${_uploadTimeout.inSeconds}s',
            _uploadTimeout,
          ),
        );
      }
      // Non-timeout exceptions (user cancellation surfaces as
      // `UploadCancelledException` from the streaming loop, and a user
      // `cancel()` while waiting on `request.close()` surfaces as an
      // `HttpException`). Propagate so the outer pipeline's
      // cancellation handler and retry classification can route them —
      // the inner `Result.error` return is reserved for HTTP/JSON
      // failures that are already classified.
      if (token.isCancelled && exception is HttpException) {
        throw const UploadCancelledException();
      }
      rethrow;
    } finally {
      timer.cancel();
    }
  }

  Result<SubmissionAsset> _finalizeUploadResult(
    Result<SubmissionAsset>? result,
    CloudinaryUploadCancellationToken token, {
    StackTrace? stackTrace,
  }) {
    final resolved =
        result ??
        Result.error(Exception('Cloudinary upload failed after retrying'));

    if (resolved case Error<SubmissionAsset>(:final error)) {
      if (!token.isCancelled) {
        if (error is _UploadHttpException) {
          _logger.log(
            CloudinaryRequestFailed(detail: 'http_${error.statusCode}'),
            error: error,
            stackTrace: stackTrace,
          );
        } else if (error is EmptyUrlException) {
          _logger.log(
            const CloudinaryRequestFailed(detail: 'empty_url'),
            error: error,
            stackTrace: stackTrace,
          );
        } else if (error is InvalidAssetDimensions) {
          _logger.log(
            const CloudinaryRequestFailed(detail: 'invalid_dimensions'),
            error: error,
            stackTrace: stackTrace,
          );
        } else if (error is FileTooLargeException) {
          _logger.log(
            const CloudinaryRequestFailed(detail: 'file_too_large'),
            error: error,
            stackTrace: stackTrace,
          );
        } else {
          // Catch-all for terminal errors that don't have a dedicated branch
          // above (e.g. a final [TimeoutException] after all retry attempts
          // are exhausted, or an unexpected [SocketException]/`HttpException`
          // from the connect phase). A terminal timeout is logged here as the
          // generic `upload_exception` rather than a dedicated `timeout`
          // detail because the per-attempt breadcrumbs already emitted
          // `timeout_attempt_<N>` for each failed attempt in
          // [_uploadWithRetries], so the timeout detail is preserved in the
          // log trail — nothing is lost.
          _logger.log(
            const CloudinaryRequestFailed(detail: 'upload_exception'),
            error: error,
            stackTrace: stackTrace,
          );
        }
      }
    }

    return resolved;
  }

  String? _buildTransformation(CloudinaryUploadOptions options) {
    if (options.maxWidth == null && options.maxHeight == null) {
      return null;
    }

    final parts = <String>[];
    if (options.maxWidth != null) {
      parts.add('w_${options.maxWidth}');
    }
    if (options.maxHeight != null) {
      parts.add('h_${options.maxHeight}');
    }
    parts.add('c_limit');
    return parts.join(',');
  }

  bool _handlePotentialCancellation(
    Exception exception,
    CloudinaryUploadCancellationToken token,
    StackTrace stackTrace,
  ) {
    if (!token.isCancelled) return false;

    _logger
      ..log(const CloudinaryUploadCancelled())
      ..log(
        const CloudinaryRequestFailed(detail: 'cancelled'),
        error: exception,
        stackTrace: stackTrace,
      );
    return true;
  }

  String _fileName(File file) => p.basename(file.path);
}

class _CloudinaryUploadTask implements ImageUploadTask {
  _CloudinaryUploadTask({
    required Future<Result<SubmissionAsset>> resultFuture,
    required StreamController<double> progressController,
    required CloudinaryUploadCancellationToken token,
  }) : _resultFuture = resultFuture,
       _progressController = progressController,
       _token = token;

  final Future<Result<SubmissionAsset>> _resultFuture;
  final StreamController<double> _progressController;
  final CloudinaryUploadCancellationToken _token;

  @override
  Future<Result<SubmissionAsset>> get result => _resultFuture;

  @override
  Stream<double> get progress => _progressController.stream;

  @override
  void cancel() {
    _token.cancel();
  }
}

// TODO(xmattjus): Cloudinary error bodies can be arbitrarily long and may
//  contain multi-line JSON or user-supplied content. Truncate [body] in
//  [_UploadHttpException.toString] (or extract the `error.message` field)
//  before logging once we start sampling real-world payloads, so that log
//  lines stay single-line and bounded in size.
class _UploadHttpException implements Exception {
  const _UploadHttpException(this.statusCode, this.body);

  final int statusCode;

  /// Raw response body from Cloudinary, captured for diagnostics.
  final String body;

  @override
  String toString() => 'UploadHttpException($statusCode): $body';
}
