import 'dart:async';
import 'dart:io' show File;

import 'package:cloudinary_api/src/request/model/uploader_params.dart'
    show UploadParams;
import 'package:cloudinary_api/uploader/cloudinary_uploader.dart';
import 'package:cloudinary_url_gen/cloudinary.dart';
import 'package:cloudinary_url_gen/transformation/delivery/delivery.dart';
import 'package:cloudinary_url_gen/transformation/delivery/delivery_actions.dart';
import 'package:cloudinary_url_gen/transformation/transformation.dart';
import 'package:moliseis/utils/constants.dart';
import 'package:moliseis/utils/exceptions.dart';
import 'package:moliseis/utils/result.dart';
import 'package:moliseis/utils/string_validator.dart';
import 'package:talker_flutter/talker_flutter.dart';

class CloudinaryClient {
  CloudinaryClient({
    required Talker logger,
    required String cloudName,
    required String apiKey,
    required String apiSecret,
  }) : _log = logger,
       _url = 'cloudinary://$apiKey:$apiSecret@$cloudName' {
    _cloudinary = Cloudinary.fromStringUrl(_url);
  }

  final Talker _log;

  late final Cloudinary _cloudinary;
  final String _url;

  Future<Result<String>> uploadImage(File image) async {
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

      if (result != null) {
        if (result.data != null) {
          final url = result.data!.secureUrl;

          if (StringValidator.isValidUrl(url)) {
            return Result.success(url!);
          } else {
            throw const CloudinaryEmptyUrlException();
          }
        } else {
          throw const CloudinaryEmptyResponseException();
        }
      } else {
        throw const CloudinaryNullResponseException();
      }
    } on TimeoutException catch (error) {
      _log.error(const NetworkTimeoutException());
      return Result.error(error);
    } on Exception catch (error, stackTrace) {
      _log.error(
        'An exception occurred while uploading the image.',
        error,
        stackTrace,
      );
      return Result.error(error);
    }
  }
}
