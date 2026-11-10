import 'dart:convert';
import 'dart:typed_data';

import 'package:http/http.dart' as http;

const apiBase = String.fromEnvironment('API_BASE', defaultValue: 'https://explore-api.explore-ai.workers.dev');

class ApiException implements Exception {
  ApiException(this.status, this.message);
  final int status;
  final String message;

  bool get rateLimited => status == 429;

  @override
  String toString() => 'ApiException($status): $message';
}

/// Client of the Cloudflare Worker. All calls throw [ApiException] on failure
/// so the game can fall back to offline text.
class StoryApi {
  StoryApi({http.Client? client}) : _http = client ?? http.Client();
  final http.Client _http;

  Future<Map<String, dynamic>> region(Map<String, dynamic> cell, String worldTheme) =>
      _post('/v1/region', {'cell': cell, 'worldTheme': worldTheme});

  Future<Map<String, dynamic>> describe(Map<String, dynamic> cell) => _post('/v1/describe', {'cell': cell});

  Future<Map<String, dynamic>> interpret(String text, Map<String, dynamic> context) =>
      _post('/v1/interpret', {'text': text, 'context': context});

  Future<Uint8List> image(String prompt) async {
    final res = await _send('/v1/image', {'prompt': prompt});
    return res.bodyBytes;
  }

  Future<Map<String, dynamic>> _post(String path, Map<String, dynamic> body) async {
    final res = await _send(path, body);
    return Map<String, dynamic>.from(jsonDecode(utf8.decode(res.bodyBytes)));
  }

  Future<http.Response> _send(String path, Map<String, dynamic> body) async {
    final http.Response res;
    try {
      res = await _http
          .post(Uri.parse('$apiBase$path'), headers: {'content-type': 'application/json'}, body: jsonEncode(body))
          .timeout(const Duration(seconds: 45));
    } catch (e) {
      throw ApiException(0, '$e');
    }
    if (res.statusCode != 200) throw ApiException(res.statusCode, utf8.decode(res.bodyBytes));
    return res;
  }
}
