import 'dart:async' show TimeoutException;
import 'dart:io' show File;

import 'package:cloudinary_api/src/request/model/uploader_params.dart'
    show UploadParams;
import 'package:cloudinary_api/uploader/cloudinary_uploader.dart';
import 'package:cloudinary_url_gen/cloudinary.dart';
import 'package:cloudinary_url_gen/transformation/delivery/delivery.dart';
import 'package:cloudinary_url_gen/transformation/delivery/delivery_actions.dart';
import 'package:cloudinary_url_gen/transformation/transformation.dart';
import 'package:moliseis/utils/constants.dart';
import 'package:moliseis/utils/logging/logging.dart';
import 'package:moliseis/utils/result.dart';
import 'package:moliseis/utils/string_validator.dart';

class CloudinaryClient {
  CloudinaryClient({
    required Logger logger,
    required String cloudName,
    required String apiKey,
    required String apiSecret,
  }) : _logger = logger,
       _url = 'cloudinary://$apiKey:$apiSecret@$cloudName' {
    _cloudinary = Cloudinary.fromStringUrl(_url);
  }

  final Logger _logger;

  late final Cloudinary _cloudinary;
  final String _url;

  Future<Result<String>> uploadImage(File image) async {
    _logger.log(const CloudinaryRequestStarted());

    try {
      final result = await _cloudinary
          .uploader()
          .upload(
            image,
            params: UploadParams(
              transformation: Transformation().delivery(
                Delivery.quality(Quality.autoEco()),
              ),
              extraHeaders: {'User-Agent': kUserAgent},
            ),
          )
          ?.timeout(const Duration(seconds: kDefaultNetworkTimeoutSeconds));

      if (result == null) {
        _logger.log(const CloudinaryRequestFailed(detail: 'null_response'));
        return Result.error(Exception('Cloudinary returned no response'));
      }
      if (result.data == null) {
        _logger.log(const CloudinaryRequestFailed(detail: 'empty_response'));
        return Result.error(Exception('Cloudinary returned an empty response'));
      }
      final url = result.data!.secureUrl;
      if (!StringValidator.isValidUrl(url)) {
        _logger.log(const CloudinaryRequestFailed(detail: 'empty_url'));
        return Result.error(Exception('Cloudinary returned an empty URL'));
      }
      return Result.success(url!);
    } on TimeoutException catch (error) {
      _logger.log(const CloudinaryRequestFailed(detail: 'timeout'));
      return Result.error(error);
    } on Exception catch (exception, stackTrace) {
      _logger.log(
        const CloudinaryRequestFailed(detail: 'upload_exception'),
        error: exception,
        stackTrace: stackTrace,
      );
      return Result.error(exception);
    }
  }
}
