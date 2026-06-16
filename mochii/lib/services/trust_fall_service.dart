import 'dart:io';

import 'package:http/http.dart' as http;

class TrustFallService {
  TrustFallService({required this.serverUrl, required this.deviceId});

  final String serverUrl;
  final String deviceId;

  Future<bool> uploadTrustFall(File imageFile, {DateTime? timestamp}) async {
    final Uri uri = Uri.parse('$serverUrl/api/puppy/trust-fall');

    final http.MultipartRequest request = http.MultipartRequest('POST', uri)
      ..fields['device_id'] = deviceId
      ..fields['timestamp'] = (timestamp ?? DateTime.now())
          .toUtc()
          .toIso8601String()
      ..files.add(await http.MultipartFile.fromPath('image', imageFile.path));

    final http.StreamedResponse response = await request.send();
    return response.statusCode >= 200 && response.statusCode < 300;
  }
}
