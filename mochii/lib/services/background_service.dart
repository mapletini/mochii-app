import 'dart:convert';
import 'dart:io';

import 'package:http/http.dart' as http;
import 'package:workmanager/workmanager.dart';

import '../data/audit_log_repository.dart';
import 'app_preferences.dart';
import 'trust_fall_service.dart';

const String timezoneSyncTaskName = 'daily-timezone-sync';
const String trustFallRetryTaskName = 'trust-fall-retry-sync';

class BackgroundService {
  static const String _defaultServerUrl = 'https://YOUR_SERVER_URL';

  static Future<void> initialize() async {
    await Workmanager().initialize(callbackDispatcher);

    await Workmanager().registerPeriodicTask(
      timezoneSyncTaskName,
      timezoneSyncTaskName,
      frequency: const Duration(hours: 24),
      existingWorkPolicy: ExistingPeriodicWorkPolicy.keep,
      constraints: Constraints(networkType: NetworkType.connected),
    );

    await Workmanager().registerPeriodicTask(
      trustFallRetryTaskName,
      trustFallRetryTaskName,
      frequency: const Duration(hours: 1),
      existingWorkPolicy: ExistingPeriodicWorkPolicy.keep,
      constraints: Constraints(networkType: NetworkType.connected),
    );
  }

  static Future<bool> syncTimezone({String? serverUrl}) async {
    final Uri uri = Uri.parse(
      '${serverUrl ?? _defaultServerUrl}/api/puppy/sync-timezone',
    );

    final DateTime now = DateTime.now();
    final Map<String, dynamic> payload = <String, dynamic>{
      'timezone': now.timeZoneName,
      'utcOffsetMinutes': now.timeZoneOffset.inMinutes,
      'timestamp': now.toUtc().toIso8601String(),
    };

    final http.Response response = await http.post(
      uri,
      headers: <String, String>{'Content-Type': 'application/json'},
      body: jsonEncode(payload),
    );

    return response.statusCode >= 200 && response.statusCode < 300;
  }

  static Future<bool> retryPendingTrustFalls({String? serverUrl}) async {
    final AppPreferences preferences = AppPreferences();
    final String? deviceId = await preferences.getDeviceId();
    if (deviceId == null || deviceId.isEmpty) {
      return false;
    }

    final AuditLogRepository repository = AuditLogRepository();
    final List<AuditLog> pendingLogs = await repository.getPendingLogs(
      actionType: 'trust_fall',
    );

    if (pendingLogs.isEmpty) {
      return true;
    }

    final TrustFallService trustFallService = TrustFallService(
      serverUrl: serverUrl ?? _defaultServerUrl,
      deviceId: deviceId,
    );

    bool atLeastOneUploaded = false;
    for (final AuditLog log in pendingLogs) {
      final int? auditId = log.id;
      final String? imagePath = log.imagePath;
      if (auditId == null || imagePath == null || imagePath.isEmpty) {
        continue;
      }

      final File imageFile = File(imagePath);
      if (!imageFile.existsSync()) {
        await repository.markUploadAttemptFailed(
          auditId,
          error: 'Missing file at $imagePath',
        );
        continue;
      }

      final bool uploaded = await trustFallService.uploadTrustFall(
        imageFile,
        timestamp: log.timestamp,
      );

      if (uploaded) {
        atLeastOneUploaded = true;
        await repository.markUploaded(auditId);
      } else {
        await repository.markUploadAttemptFailed(
          auditId,
          error: 'Background retry failed',
        );
      }
    }

    return atLeastOneUploaded;
  }
}

@pragma('vm:entry-point')
void callbackDispatcher() {
  Workmanager().executeTask((
    String task,
    Map<String, dynamic>? inputData,
  ) async {
    if (task == timezoneSyncTaskName) {
      final bool synced = await BackgroundService.syncTimezone();
      return Future<bool>.value(synced);
    }

    if (task == trustFallRetryTaskName) {
      final bool retried = await BackgroundService.retryPendingTrustFalls();
      return Future<bool>.value(retried);
    }

    return Future<bool>.value(false);
  });
}
