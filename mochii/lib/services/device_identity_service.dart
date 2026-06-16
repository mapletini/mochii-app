import 'package:device_info_plus/device_info_plus.dart';
import 'package:flutter/foundation.dart';
import 'package:uuid/uuid.dart';

class DeviceIdentityService {
  final DeviceInfoPlugin _deviceInfoPlugin = DeviceInfoPlugin();
  static const Uuid _uuid = Uuid();

  Future<String> getUniqueDeviceId() async {
    try {
      if (defaultTargetPlatform == TargetPlatform.android) {
        final AndroidDeviceInfo androidInfo =
            await _deviceInfoPlugin.androidInfo;
        final String androidId = androidInfo.id;
        if (androidId.isNotEmpty) {
          return androidId;
        }
      }

      if (defaultTargetPlatform == TargetPlatform.iOS) {
        final IosDeviceInfo iosInfo = await _deviceInfoPlugin.iosInfo;
        final String? vendorId = iosInfo.identifierForVendor;
        if (vendorId != null && vendorId.isNotEmpty) {
          return vendorId;
        }
      }
    } catch (_) {
      // Fall through to generated UUID when platform ID lookup fails.
    }

    return _uuid.v4();
  }
}
