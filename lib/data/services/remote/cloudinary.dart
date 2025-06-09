import 'dart:io' show File;

import 'package:cloudinary_api/src/request/model/uploader_params.dart'
    show UploadParams;
import 'package:cloudinary_api/uploader/cloudinary_uploader.dart';
import 'package:cloudinary_url_gen/cloudinary.dart';
import 'package:cloudinary_url_gen/transformation/delivery/delivery.dart';
import 'package:cloudinary_url_gen/transformation/delivery/delivery_actions.dart';
import 'package:cloudinary_url_gen/transformation/transformation.dart';
import 'package:logging/logging.dart';
import 'package:moliseis/utils/exceptions.dart';
import 'package:moliseis/utils/log_events.dart';
import 'package:moliseis/utils/result.dart';
import 'package:moliseis/utils/string_validator.dart';

class CloudinaryClient {
  CloudinaryClient({
    required String cloudName,
    required String apiKey,
    required String apiSecret,
  }) : _url = 'cloudinary://$apiKey:$apiSecret@$cloudName' {
    _cloudinary = Cloudinary.fromStringUrl(_url);
  }

  final _log = Logger('CloudinaryClient');

  late final Cloudinary _cloudinary;
  final String _url;

  Future<Result<String>> uploadImage(File image) async {
    try {
      final result = await _cloudinary.uploader().upload(
        image,
        params: UploadParams(
          transformation: Transformation().delivery(
            Delivery.quality(Quality.autoEco()),
          ),
        ),
      );

      if (result != null) {
        if (result.data != null) {
          final url = result.data!.secureUrl;

          if (StringValidator.isValidUrl(url)) {
            return Result.success(url!);
          } else {
            return const Result.error(CloudinaryEmptyUrlException());
          }
        } else {
          return const Result.error(CloudinaryEmptyResponseException());
        }
      } else {
        return const Result.error(CloudinaryNullResponseException());
      }
    } on Exception catch (error, stackTrace) {
      _log.severe(LogEvents.imageUploadError, error, stackTrace);

      return Result.error(error);
    }
  }
}
