import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

class AppBuildInformation {
  const AppBuildInformation({
    required this.packageName,
    required this.versionName,
    required this.versionCode,
    required this.debuggable,
  });
  final String packageName;
  final String versionName;
  final int versionCode;
  final bool debuggable;

  factory AppBuildInformation.fromMap(Map<Object?, Object?> value) {
    final name = value['versionName'];
    final code = value['versionCode'];
    if (value['version'] != 1 ||
        value['packageName'] != 'com.eartime.eartime_app' ||
        name is! String ||
        name.isEmpty ||
        name.length > 128 ||
        name.codeUnits.any((unit) => unit < 32 || unit == 127) ||
        code is! int ||
        code < 1 ||
        value['debuggable'] is! bool) {
      throw const FormatException('Installed package information unavailable');
    }
    return AppBuildInformation(
      packageName: value['packageName'] as String,
      versionName: name,
      versionCode: code,
      debuggable: value['debuggable'] as bool,
    );
  }
}

class AppBuildInformationClient {
  const AppBuildInformationClient();
  Future<AppBuildInformation> read() async {
    final value = await const MethodChannel(
      'com.eartime.app/tracking',
    ).invokeMapMethod<Object?, Object?>('readAppBuildInformation');
    if (value == null) {
      throw const FormatException('Package information missing');
    }
    return AppBuildInformation.fromMap(value);
  }
}

final appBuildInformationProvider =
    FutureProvider.autoDispose<AppBuildInformation>(
      (ref) => const AppBuildInformationClient().read(),
    );
