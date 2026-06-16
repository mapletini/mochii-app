import 'package:shared_preferences/shared_preferences.dart';

class AppPreferences {
  static const String deviceIdKey = 'device_id';
  static const String monikerKey = 'moniker';
  static const String appFaceKey = 'app_face';

  Future<String?> getDeviceId() async {
    final SharedPreferences prefs = await SharedPreferences.getInstance();
    return prefs.getString(deviceIdKey);
  }

  Future<String?> getMoniker() async {
    final SharedPreferences prefs = await SharedPreferences.getInstance();
    return prefs.getString(monikerKey);
  }

  Future<void> saveRegistration({
    required String deviceId,
    required String moniker,
  }) async {
    final SharedPreferences prefs = await SharedPreferences.getInstance();
    await prefs.setString(deviceIdKey, deviceId);
    await prefs.setString(monikerKey, moniker);
  }

  Future<String?> getAppFace() async {
    final SharedPreferences prefs = await SharedPreferences.getInstance();
    return prefs.getString(appFaceKey);
  }

  Future<void> saveAppFace(String appFace) async {
    final SharedPreferences prefs = await SharedPreferences.getInstance();
    await prefs.setString(appFaceKey, appFace);
  }

  Future<void> clearAppFace() async {
    final SharedPreferences prefs = await SharedPreferences.getInstance();
    await prefs.remove(appFaceKey);
  }
}
