import 'dart:io';
import 'package:device_info_plus/device_info_plus.dart';

final DeviceInfoPlugin deviceInfoPlugin = DeviceInfoPlugin();

Future<Map<String, String>> getDeviceInfo() async {
  if (Platform.isAndroid) {
    final androidInfo = await deviceInfoPlugin.androidInfo;
    return {
      "id": androidInfo.id ?? "unknown",
      "name": androidInfo.model ?? "unknown",
    };
  } else if (Platform.isIOS) {
    final iosInfo = await deviceInfoPlugin.iosInfo;
    return {
      "id": iosInfo.identifierForVendor ?? "unknown",
      "name": iosInfo.name ?? "unknown",
    };
  } else {
    return {"id": "unknown", "name": "unknown"};
  }
}
