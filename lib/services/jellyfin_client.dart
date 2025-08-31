import 'dart:io';
import 'package:http/http.dart' as http;
import 'package:uuid/uuid.dart';

class JellyfinClient {
  JellyfinClient({
    required this.baseUrl,      
    required this.accessToken,
    String? deviceId,
    this.clientName = 'Jellydesk',
    this.appVersion = '0.1.0',
  }) : deviceId = deviceId ?? const Uuid().v4();

  final String baseUrl;
  final String accessToken;
  final String deviceId;
  final String clientName;
  final String appVersion;

  final http.Client _http = http.Client();

  Map<String, String> get _authHeaders => {
    // Beides setzen – kompatibel zu verschiedenen Server-Versionen
    'X-Emby-Token': accessToken,
    'X-Emby-Authorization':
        'MediaBrowser Client="$clientName", Device="Flutter", DeviceId="$deviceId", Version="$appVersion"',
    'Accept': 'application/json',
  };

  Uri _uri(String path, [Map<String, String>? q]) {
    final qp = {...?q, 'api_key': accessToken}; // Query-Key für img/hls
    return Uri.parse('$baseUrl$path').replace(queryParameters: qp);
  }

  Future<http.Response> get(String path, {Map<String, String>? query}) {
    return _http.get(_uri(path, query), headers: _authHeaders);
  }

  Future<http.Response> post(String path, {Map<String, String>? query, Object? body}) {
    return _http.post(_uri(path, query), headers: _authHeaders, body: body);
  }
}
