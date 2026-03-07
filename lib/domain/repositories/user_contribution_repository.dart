import 'dart:io' show File;

import 'package:moliseis/data/sources/user_contribution.dart';
import 'package:moliseis/utils/result.dart';

abstract class UserContributionRepository {
  Future<Result> upload(UserContribution userContribution);

  Future<Result<String>> uploadImage(File image);
}
