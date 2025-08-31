import 'dart:convert';
import 'package:http/http.dart' as http;

class PlaybackResolved {
  final Uri url;
  final Map<String, String> headers;
  final bool isHls;
  final String itemId; // tatsächlich abgespieltes Item
  const PlaybackResolved(this.url, this.headers, {required this.itemId, this.isHls = true});
}

class JellyfinPlaybackResolver {
  JellyfinPlaybackResolver({
    required this.baseUrl,
    required this.accessToken,
    required this.itemId,
    required this.userId, // WICHTIG: für Folder-Auflösung
    this.platform, // "ios" | "android" | "macos" | "linux" | "windows"
  });

  final String baseUrl;
  final String accessToken;
  final String itemId;
  final String userId;
  final String? platform;

  String get _base => baseUrl.endsWith('/') ? baseUrl.substring(0, baseUrl.length - 1) : baseUrl;

  Map<String, String> get _authHeaders => {
    'X-Emby-Token': accessToken,
    'X-Emby-Authorization':
      'MediaBrowser Client="Jellydesk", Device="Flutter", DeviceId="flutter-device", Version="0.1.0"',
    'Accept': 'application/json',
  };

  Uri _withKey(Uri u, [Map<String, String>? extra]) {
    final qp = {...u.queryParameters, 'api_key': accessToken, ...?extra};
    return u.replace(queryParameters: qp);
  }

  Future<Map<String, dynamic>> _getJson(Uri url, {String method = 'GET', Object? body}) async {
    final h = {..._authHeaders, if (body != null) 'Content-Type': 'application/json'};
    late http.Response res;
    if (method == 'POST') {
      res = await http.post(url, headers: h, body: body);
    } else {
      res = await http.get(url, headers: h);
    }
    if (res.statusCode >= 200 && res.statusCode < 300) {
      return jsonDecode(res.body) as Map<String, dynamic>;
    }
    throw StateError('${url.path} HTTP ${res.statusCode}: ${_trim(res.body)}');
  }

  Future<_Probe> _probe(Uri url, {Map<String,String>? headers}) async {
    final h = {..._authHeaders, ...?headers};
    try {
      final head = await http.head(url, headers: h);
      return _Probe(head.statusCode, head.body);
    } catch (_) {
      final h2 = {...h, 'Range': 'bytes=0-1'};
      final get = await http.get(url, headers: h2);
      return _Probe(get.statusCode, get.body);
    }
  }

  Future<String> _resolvePlayableItemId(String id) async {
    // 1) Item abrufen
    final item = await _getJson(_withKey(Uri.parse('$_base/Items/$id')));
    final type = item['Type'] as String?;
    final mediaType = item['MediaType'] as String?;
    final isFolder = (item['IsFolder'] as bool?) ?? false;

    // Wenn schon ein Video-Item: durchlassen
    if (!isFolder && mediaType == 'Video') return id;

    // Serien → NextUp bevorzugen
    if (type == 'Series') {
      final nu = await _getJson(_withKey(Uri.parse('$_base/Shows/$id/NextUp'), {
        'userId': userId,
        'Limit': '1',
      }));
      final items = (nu['Items'] as List?)?.cast<Map<String,dynamic>>() ?? const [];
      if (items.isNotEmpty) return items.first['Id'] as String;
    }

    // Allgemein: erstes Video-Child rekursiv
    final children = await _getJson(_withKey(Uri.parse('$_base/Users/$userId/Items'), {
      'ParentId': id,
      'Recursive': 'true',
      'IncludeItemTypes': 'Movie,Episode,Video',
      'Limit': '1',
      'SortBy': 'SortName',
      'Fields': 'MediaType',
    }));
    final list = (children['Items'] as List?)?.cast<Map<String,dynamic>>() ?? const [];
    if (list.isNotEmpty) return list.first['Id'] as String;

    throw StateError('Kein abspielbares Video unter diesem Element gefunden.');
  }

  Map<String, dynamic> _deviceProfile() {
    final isApple = (platform == 'ios' || platform == 'macos');
    return {
      'Name': 'Jellydesk Flutter',
      'MaxStreamingBitrate': 20000000,
      'DirectPlayProfiles': [
        {
          'Type': 'Video',
          'Container': isApple ? 'mp4,m4v' : 'mp4,m4v,webm',
          'VideoCodec': isApple ? 'h264,hevc' : 'h264,hevc,vp9,av1',
          'AudioCodec': 'aac,mp3,ac3',
        },
        {'Type': 'Video','Container':'ts','VideoCodec':'h264','AudioCodec':'aac,ac3'},
        {'Type': 'Audio','Container':'mp3,aac,m4a,flac,ogg,opus'}
      ],
      'TranscodingProfiles': [
        {'Type':'Video','Container':'ts','Protocol':'hls','VideoCodec':'h264','AudioCodec':'aac','MaxAudioChannels':'2','CopyTimestamps':true,'BreakOnNonKeyFrames':true},
      ],
      'CodecProfiles': [
        {'Type':'Video','Codec':'h264','Conditions':[{'Condition':'LessThanEqual','Property':'VideoLevel','Value':'41'}]}
      ],
      'SubtitleProfiles': [
        {'Format':'vtt','Method':'External'},
        {'Format':'srt','Method':'External'},
      ],
    };
  }

  Future<PlaybackResolved> resolve() async {
    // Zuerst sicherstellen, dass wir wirklich eine Video-Id haben:
    final vid = await _resolvePlayableItemId(itemId);

    // 1) HLS Master
    final hls = _withKey(Uri.parse('$_base/Videos/$vid/master.m3u8'));
    final p1 = await _probe(hls);
    if (p1.ok) return PlaybackResolved(hls, _authHeaders, itemId: vid, isHls: true);

    // 2) Static MP4
    final mp4 = _withKey(Uri.parse('$_base/Videos/$vid/stream.mp4'), {
      'Static': 'true','VideoCodec':'h264','AudioCodec':'aac','MaxWidth':'1920','MaxHeight':'1080','Profile':'high','Level':'41',
    });
    final p2 = await _probe(mp4);
    if (p2.ok) return PlaybackResolved(mp4, _authHeaders, itemId: vid, isHls: false);

    // 3) PlaybackInfo mit DeviceProfile
    final pbInfo = await http.post(
      _withKey(Uri.parse('$_base/Items/$vid/PlaybackInfo')),
      headers: {..._authHeaders, 'Content-Type':'application/json'},
      body: jsonEncode({'AutoOpenLiveStream': false,'MaxStreamingBitrate': 20000000,'DeviceProfile': _deviceProfile()}),
    );
    if (pbInfo.statusCode != 200) {
      throw StateError('PlaybackInfo HTTP ${pbInfo.statusCode}: ${_trim(pbInfo.body)}');
    }
    final j = jsonDecode(pbInfo.body) as Map<String, dynamic>;
    final ms = (j['MediaSources'] as List?)?.cast<Map<String,dynamic>>() ?? const [];
    if (ms.isEmpty) throw StateError('PlaybackInfo: keine MediaSources gefunden.');
    String? path;
    bool isHls = true;
    final first = ms.first;
    if (first['TranscodingUrl'] is String && (first['TranscodingUrl'] as String).isNotEmpty) {
      path = first['TranscodingUrl'] as String; isHls = path.contains('.m3u8');
    } else if (first['DirectStreamUrl'] is String && (first['DirectStreamUrl'] as String).isNotEmpty) {
      path = first['DirectStreamUrl'] as String; isHls = path.contains('.m3u8');
    } else if (first['Path'] is String && (first['Path'] as String).isNotEmpty) {
      path = first['Path'] as String; isHls = path.contains('.m3u8');
    }
    if (path == null) throw StateError('PlaybackInfo: keine brauchbare URL gefunden.');

    Uri u = path.startsWith('http') ? Uri.parse(path) : Uri.parse('$_base$path');
    if (!u.queryParameters.containsKey('api_key')) { u = _withKey(u); }
    final p3 = await _probe(u);
    if (!p3.ok) throw StateError('Aufgelöste URL nicht spielbar (HTTP ${p3.status}): ${_trim(p3.body)}');
    return PlaybackResolved(u, _authHeaders, itemId: vid, isHls: isHls);
  }

  String _trim(String s, [int max = 400]) => s.length <= max ? s : '${s.substring(0, max)}…';
}

class _Probe {
  final int status;
  final String body;
  const _Probe(this.status, this.body);
  bool get ok => status >= 200 && status < 300;
}
