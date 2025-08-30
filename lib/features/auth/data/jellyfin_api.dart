import 'dart:convert';
import 'package:http/http.dart' as http;

class JfApi {
  final String baseUrl;
  final String clientName;
  final String deviceName;
  final String deviceId;
  final String version;
  String? accessToken;

  JfApi({
    required this.baseUrl,
    required this.clientName,
    required this.deviceName,
    required this.deviceId,
    this.version = '0.1.0',
    this.accessToken,
  });

  Map<String, String> _headers({bool authorized = false}) {
    final auth = 'MediaBrowser Client=\"$clientName\", Device=\"$deviceName\", DeviceId=\"$deviceId\", Version=\"$version\"';
    final headers = {
      'X-Emby-Authorization': auth,
      'Content-Type': 'application/json',
    };
    if (authorized && accessToken != null) {
      headers['X-Emby-Token'] = accessToken!;
    }
    return headers;
  }

  // ---- Auth ----

  Future<(String userId, String token)> authenticateByName(String username, String password) async {
    final url = Uri.parse('$baseUrl/Users/AuthenticateByName');
    final res = await http.post(url, headers: _headers(), body: jsonEncode({
      'Username': username,
      'Pw': password,
    }));
    if (res.statusCode >= 200 && res.statusCode < 300) {
      final data = jsonDecode(res.body);
      final token = data['AccessToken'] as String;
      final userId = data['User']['Id'] as String;
      return (userId, token);
    }
    throw Exception('Login fehlgeschlagen: ${res.statusCode} ${res.body}');
  }

  // Quick Connect
  Future<(String secret, String code)> quickConnectInitiate() async {
    final url = Uri.parse('$baseUrl/QuickConnect/Initiate');
    final res = await http.post(url, headers: _headers());
    if (res.statusCode == 200) {
      final data = jsonDecode(res.body);
      return (data['Secret'] as String, data['Code'] as String);
    }
    throw Exception('QuickConnect Initiate fehlgeschlagen: ${res.statusCode}');
  }

  Future<Map<String, dynamic>> quickConnectState(String secret) async {
    final url = Uri.parse('$baseUrl/QuickConnect/Connect?Secret=$secret');
    final res = await http.get(url, headers: _headers());
    if (res.statusCode == 200) {
      return jsonDecode(res.body) as Map<String, dynamic>;
    }
    throw Exception('QuickConnect State fehlgeschlagen: ${res.statusCode}');
  }

  // ---- Library ----

  Future<List<Map<String, dynamic>>> getViews(String userId) async {
    final url = Uri.parse('$baseUrl/Users/$userId/Views');
    final res = await http.get(url, headers: _headers(authorized: true));
    if (res.statusCode == 200) {
      final data = jsonDecode(res.body) as Map<String, dynamic>;
      return List<Map<String, dynamic>>.from(data['Items'] as List);
    }
    throw Exception('Views laden fehlgeschlagen: ${res.statusCode}');
  }

  Future<List<Map<String, dynamic>>> getItems(String userId, {String? parentId, String? includeTypes}) async {
    final qs = <String, String>{};
    if (parentId != null) qs['ParentId'] = parentId;
    if (includeTypes != null) qs['IncludeItemTypes'] = includeTypes;
    final url = Uri.parse('$baseUrl/Users/$userId/Items').replace(queryParameters: qs);
    final res = await http.get(url, headers: _headers(authorized: true));
    if (res.statusCode == 200) {
      final data = jsonDecode(res.body) as Map<String, dynamic>;
      return List<Map<String, dynamic>>.from(data['Items'] as List);
    }
    throw Exception('Items laden fehlgeschlagen: ${res.statusCode}');
  }

  String itemImageUrl(String itemId, {int width = 400}) {
    final sep = baseUrl.endsWith('/') ? '' : '/';
    return '$baseUrl${sep}Items/$itemId/Images/Primary?fillWidth=$width&quality=90';
  }

  // Simple HLS master URL (may require server-side transcoding capability)
  Uri videoHlsMaster(String itemId) {
    final sep = baseUrl.endsWith('/') ? '' : '/';
    final uri = Uri.parse('$baseUrl${sep}Videos/$itemId/master.m3u8');
    return uri;
  }
}
