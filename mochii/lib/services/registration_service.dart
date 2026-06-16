import 'dart:convert';

import 'package:http/http.dart' as http;

class RegistrationService {
  RegistrationService({required this.serverUrl});

  final String serverUrl;

  Future<bool> register({
    required String deviceId,
    required String moniker,
  }) async {
    final Uri uri = Uri.parse('$serverUrl/api/register');

    final http.Response response = await http.post(
      uri,
      headers: <String, String>{'Content-Type': 'application/json'},
      body: jsonEncode(<String, dynamic>{
        'device_id': deviceId,
        'moniker': moniker,
      }),
    );

    return response.statusCode >= 200 && response.statusCode < 300;
  }
}
