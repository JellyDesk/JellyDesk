import 'dart:io' show Platform;
import 'dart:convert';
import 'package:http/http.dart' as http;
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:video_player/video_player.dart';
import 'package:flutter/foundation.dart' show kIsWeb, defaultTargetPlatform, TargetPlatform;

import '../../auth/data/jellyfin_api.dart';
import '../data/playback_resolver.dart';

// Optional: Chromecast & AirPlay (im Overlay derzeit nicht angezeigt)
import 'package:cast/cast.dart' as chromecast;
import 'package:flutter_to_airplay/flutter_to_airplay.dart' as airplay;

class PlayerPage extends StatefulWidget {
  final JfApi api;
  final String itemId;
  final String title;

  /// Optional – wenn null, ermitteln wir die UserId via /Users/Me.
  final String? userId;

  const PlayerPage({
    super.key,
    required this.api,
    required this.itemId,
    required this.title,
    this.userId,
  });

  @override
  State<PlayerPage> createState() => _PlayerPageState();
}

class _PlayerPageState extends State<PlayerPage> {
  VideoPlayerController? _controller;
  String? _error;
  bool _controlsVisible = true;

  // Header-Infos (sichtbar)
  String? _uiTitle;
  String? _uiSubtitle;

  // Zum Ermitteln von „Nächste Folge“
  String? _currentUserId;
  String? _currentItemId;
  bool _isEpisode = false;
  String? _seriesId;
  String? _seasonId;
  int? _seasonNumber;
  int? _episodeNumber;

  // Nächste Folge (falls vorhanden)
  String? _nextItemId;
  String? _nextTitle;
  String? _nextSubtitle;

  bool get _isMobile {
    if (kIsWeb) return false;
    return defaultTargetPlatform == TargetPlatform.android ||
        defaultTargetPlatform == TargetPlatform.iOS;
  }

  String get _baseUrl => widget.api.baseUrl.endsWith('/')
      ? widget.api.baseUrl.substring(0, widget.api.baseUrl.length - 1)
      : widget.api.baseUrl;

  String _requireToken() {
    final t = widget.api.accessToken;
    if (t == null || t.isEmpty) {
      throw StateError('Kein Access-Token vorhanden (bitte erneut anmelden).');
    }
    return t;
  }

  Map<String, String> _authHeaders() {
    final token = _requireToken();
    return {
      'X-Emby-Token': token,
      'X-Emby-Authorization':
          'MediaBrowser Client="Jellydesk", Device="Flutter", DeviceId="flutter-device", Version="0.1.0"',
      'Accept': 'application/json',
    };
  }

  Future<String> _ensureUserId() async {
    if (widget.userId != null && widget.userId!.isNotEmpty) return widget.userId!;
    final url = Uri.parse('$_baseUrl/Users/Me')
        .replace(queryParameters: {'api_key': _requireToken()});
    final res = await http.get(url, headers: _authHeaders());
    if (res.statusCode != 200) {
      throw StateError('UserId konnte nicht ermittelt werden (/Users/Me): HTTP ${res.statusCode}');
    }
    final data = jsonDecode(res.body) as Map<String, dynamic>;
    final id = data['Id'] as String?;
    if (id == null || id.isEmpty) {
      throw StateError('UserId fehlt in /Users/Me');
    }
    return id;
  }

  Future<void> _loadDisplayInfo(String id) async {
    try {
      final url = Uri.parse('$_baseUrl/Items/$id').replace(queryParameters: {
        'api_key': _requireToken(),
        'Fields': 'SeriesName,SeriesId,SeasonId,ParentIndexNumber,IndexNumber,ProductionYear,SeasonName'
      });
      final res = await http.get(url, headers: _authHeaders());
      if (res.statusCode != 200) {
        setState(() {
          _uiTitle = widget.title;
          _uiSubtitle = null;
          _isEpisode = false;
          _seriesId = null;
          _seasonId = null;
          _seasonNumber = null;
          _episodeNumber = null;
        });
        return;
      }
      final j = jsonDecode(res.body) as Map<String, dynamic>;
      final type = j['Type'] as String?;
      final name = (j['Name'] as String?) ?? widget.title;

      String? line1, line2;
      bool isEp = type == 'Episode';
      String? seriesId = j['SeriesId'] as String?;
      String? seasonId = j['SeasonId'] as String?;
      int? sNum = j['ParentIndexNumber'] is int ? j['ParentIndexNumber'] as int : null;
      int? eNum = j['IndexNumber'] is int ? j['IndexNumber'] as int : null;

      if (isEp) {
        final series = (j['SeriesName'] as String?) ?? name;
        final epName = name;
        final se = (sNum != null && eNum != null)
            ? 'S${sNum.toString().padLeft(2, '0')}E${eNum.toString().padLeft(2, '0')}'
            : (sNum != null ? 'S${sNum.toString().padLeft(2, '0')}' : null);
        line1 = series;
        line2 = [se, epName].whereType<String>().where((x) => x.isNotEmpty).join(' · ');
      } else {
        final year = (j['ProductionYear']?.toString());
        line1 = name;
        line2 = year?.isNotEmpty == true ? year : null;
      }

      setState(() {
        _uiTitle = line1;
        _uiSubtitle = line2;
        _isEpisode = isEp;
        _seriesId = seriesId;
        _seasonId = seasonId;
        _seasonNumber = sNum;
        _episodeNumber = eNum;
      });
    } catch (_) {
      setState(() {
        _uiTitle = widget.title;
        _uiSubtitle = null;
        _isEpisode = false;
        _seriesId = null;
        _seasonId = null;
        _seasonNumber = null;
        _episodeNumber = null;
      });
    }
  }

  Future<void> _computeNextEpisode(String uid) async {
    _nextItemId = null;
    _nextTitle = null;
    _nextSubtitle = null;

    if (!_isEpisode || _seriesId == null) {
      setState(() {});
      return;
    }

    try {
      // 1) Versuche gleiche Season → nächste Episode nach IndexNumber
      if (_seasonId != null && _episodeNumber != null) {
        final url = Uri.parse('$_baseUrl/Shows/${_seriesId!}/Episodes').replace(queryParameters: {
          'api_key': _requireToken(),
          'UserId': uid,
          'SeasonId': _seasonId!,
          'Fields': 'IndexNumber,SeriesName,ParentIndexNumber',
          'SortBy': 'IndexNumber',
          'SortOrder': 'Ascending',
          'Limit': '300',
        });
        final res = await http.get(url, headers: _authHeaders());
        if (res.statusCode == 200) {
          final data = jsonDecode(res.body) as Map<String, dynamic>;
          final items = (data['Items'] as List?)?.cast<Map<String, dynamic>>() ?? const [];
          final next = items.firstWhere(
            (it) => (it['IndexNumber'] is int) && (it['IndexNumber'] as int) > (_episodeNumber ?? 0),
            orElse: () => {},
          );
          if (next.isNotEmpty) {
            final id = next['Id'] as String?;
            if (id != null) {
              final series = (next['SeriesName'] as String?) ?? (_uiTitle ?? '');
              final sNum = next['ParentIndexNumber'] is int ? next['ParentIndexNumber'] as int : _seasonNumber;
              final eNum = next['IndexNumber'] as int?;
              final se = (sNum != null && eNum != null)
                  ? 'S${sNum.toString().padLeft(2, '0')}E${eNum.toString().padLeft(2, '0')}'
                  : null;
              setState(() {
                _nextItemId = id;
                _nextTitle = series;
                _nextSubtitle = se;
              });
              return;
            }
          }
        }
      }

      // 2) Fallback: NextUp
      final nu = Uri.parse('$_baseUrl/Shows/${_seriesId!}/NextUp').replace(queryParameters: {
        'api_key': _requireToken(),
        'UserId': uid,
        'Limit': '1',
      });
      final res2 = await http.get(nu, headers: _authHeaders());
      if (res2.statusCode == 200) {
        final data = jsonDecode(res2.body) as Map<String, dynamic>;
        final items = (data['Items'] as List?)?.cast<Map<String, dynamic>>() ?? const [];
        if (items.isNotEmpty) {
          final it = items.first;
          final id = it['Id'] as String?;
          final name = it['Name'] as String?;
          final series = it['SeriesName'] as String? ?? _uiTitle ?? '';
          final sNum = it['ParentIndexNumber'] as int?;
          final eNum = it['IndexNumber'] as int?;
          final se = (sNum != null && eNum != null)
              ? 'S${sNum.toString().padLeft(2, '0')}E${eNum.toString().padLeft(2, '0')}'
              : null;
          if (id != null) {
            setState(() {
              _nextItemId = id;
              _nextTitle = series;
              _nextSubtitle = [se, name].whereType<String>().where((x) => x.isNotEmpty).join(' · ');
            });
          }
        }
      }
    } catch (_) {
      // ignorieren; „Nächste Folge“ wird dann nicht angezeigt
    }
  }

  @override
  void initState() {
    super.initState();
    if (_isMobile) {
      SystemChrome.setEnabledSystemUIMode(SystemUiMode.immersiveSticky);
      SystemChrome.setPreferredOrientations(
        [DeviceOrientation.landscapeLeft, DeviceOrientation.landscapeRight],
      );
    }
    _init();
  }

  @override
  void dispose() {
    if (_isMobile) {
      SystemChrome.setEnabledSystemUIMode(SystemUiMode.edgeToEdge);
      SystemChrome.setPreferredOrientations(DeviceOrientation.values);
    }
    _controller?.dispose();
    super.dispose();
  }

  Future<void> _init() async {
    try {
      final uid = await _ensureUserId(); // ← immer non-null
      _currentUserId = uid;

      final resolved = await JellyfinPlaybackResolver(
        baseUrl: _baseUrl,
        accessToken: _requireToken(),
        itemId: widget.itemId,
        userId: uid, // ← String
        platform: !kIsWeb && Platform.isIOS
            ? 'ios'
            : !kIsWeb && Platform.isMacOS
                ? 'macos'
                : !kIsWeb && Platform.isAndroid
                    ? 'android'
                    : 'linux',
      ).resolve();

      _currentItemId = resolved.itemId;

      // Header-Infos laden (Titel/Untertitel)
      await _loadDisplayInfo(resolved.itemId);
      // Nächste Folge vorab ermitteln (falls Episode)
      await _computeNextEpisode(uid);

      debugPrint('▶️ Stream: ${resolved.url} (item ${resolved.itemId})');

      final ctrl = VideoPlayerController.networkUrl(
        resolved.url,
        httpHeaders: resolved.headers,
      );
      await ctrl.initialize();
      await ctrl.setLooping(false);
      // Timeline regelmäßig aktualisieren
      ctrl.addListener(() {
        if (mounted) setState(() {});
      });

      setState(() => _controller = ctrl);
      await ctrl.play();
    } catch (e) {
      setState(() => _error = 'Videowiedergabe fehlgeschlagen:\n$e');
    }
  }

  Future<void> _playItem(String itemId) async {
    try {
      final uid = _currentUserId ?? await _ensureUserId();
      final resolved = await JellyfinPlaybackResolver(
        baseUrl: _baseUrl,
        accessToken: _requireToken(),
        itemId: itemId,
        userId: uid,
        platform: !kIsWeb && Platform.isIOS
            ? 'ios'
            : !kIsWeb && Platform.isMacOS
                ? 'macos'
                : !kIsWeb && Platform.isAndroid
                    ? 'android'
                    : 'linux',
      ).resolve();

      _currentItemId = resolved.itemId;

      await _loadDisplayInfo(resolved.itemId);
      await _computeNextEpisode(uid);

      final old = _controller;
      final ctrl = VideoPlayerController.networkUrl(
        resolved.url,
        httpHeaders: resolved.headers,
      );
      await ctrl.initialize();
      await ctrl.setLooping(false);
      ctrl.addListener(() {
        if (mounted) setState(() {});
      });

      setState(() => _controller = ctrl);
      await old?.dispose();
      await ctrl.play();
    } catch (e) {
      setState(() => _error = 'Nächste Folge konnte nicht gestartet werden:\n$e');
    }
  }

  void _togglePlay() {
    final c = _controller;
    if (c == null) return;
    final playing = c.value.isPlaying;
    setState(() => playing ? c.pause() : c.play());
  }

  void _toggleControls() => setState(() => _controlsVisible = !_controlsVisible);

  @override
  Widget build(BuildContext context) {
    final c = _controller;

    final player = Center(
      child: _error != null
          ? SingleChildScrollView(
              padding: const EdgeInsets.all(16),
              child: Text(_error!, textAlign: TextAlign.center),
            )
          : c == null
              ? const CircularProgressIndicator()
              : GestureDetector(
                  onTap: _toggleControls,
                  onDoubleTap: _togglePlay,
                  behavior: HitTestBehavior.opaque,
                  child: Stack(
                    fit: StackFit.expand,
                    children: [
                      AspectRatio(
                        aspectRatio:
                            c.value.aspectRatio == 0 ? 16 / 9 : c.value.aspectRatio,
                        child: VideoPlayer(c),
                      ),
                      if (_controlsVisible)
                        _ControlsOverlay(
                          controller: c,
                          title: _uiTitle ?? widget.title,
                          subtitle: _uiSubtitle,
                          onBack: () => Navigator.of(context).maybePop(),
                          showNext: _nextItemId != null,
                          nextLabel: (_nextTitle != null)
                              ? [_nextTitle, _nextSubtitle].whereType<String>().join(' · ')
                              : 'Nächste Folge',
                          onNext: _nextItemId == null ? null : () => _playItem(_nextItemId!),
                        ),
                    ],
                  ),
                ),
    );

    return Scaffold(
      backgroundColor: Colors.black,
      body: SafeArea(
        top: !_isMobile,
        bottom: !_isMobile,
        child: player,
      ),
    );
  }
}

/// Overlay mit Back, großen Titelzeilen, semi-transparentem Center-Button
/// und Gradient-Timeline (#FF0103 → #FF0089)
class _ControlsOverlay extends StatefulWidget {
  const _ControlsOverlay({
    required this.controller,
    required this.title,
    this.subtitle,
    required this.onBack,
    required this.showNext,
    this.nextLabel,
    this.onNext,
  });

  final VideoPlayerController controller;
  final String title;
  final String? subtitle;
  final VoidCallback onBack;

  final bool showNext;
  final String? nextLabel;
  final VoidCallback? onNext;

  @override
  State<_ControlsOverlay> createState() => _ControlsOverlayState();
}

class _ControlsOverlayState extends State<_ControlsOverlay> {
  bool _dragging = false;

  Duration get _position => widget.controller.value.position;
  Duration get _duration => widget.controller.value.duration == Duration.zero
      ? const Duration(seconds: 1)
      : widget.controller.value.duration;

  double get _progress =>
      _duration.inMilliseconds == 0
          ? 0
          : _position.inMilliseconds / _duration.inMilliseconds;

  String _fmt(Duration d) {
    String two(int n) => n.toString().padLeft(2, '0');
    final h = d.inHours;
    final m = d.inMinutes % 60;
    final s = d.inSeconds % 60;
    return h > 0 ? '$h:${two(m)}:${two(s)}' : '${two(m)}:${two(s)}';
  }

  @override
  Widget build(BuildContext context) {
    final isPlaying = widget.controller.value.isPlaying;

    return IgnorePointer(
      ignoring: false,
      child: Container(
        decoration: const BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
            colors: [Colors.transparent, Colors.black38, Colors.black87],
            stops: [0.20, 0.60, 1.0],
          ),
        ),
        child: Column(
          children: [
            // TOP BAR (Back + große Titelzeilen)
            SafeArea(
              bottom: false,
              child: Padding(
                padding: const EdgeInsets.fromLTRB(10, 10, 14, 8),
                child: Row(
                  children: [
                    IconButton(
                      iconSize: 32,
                      icon: const Icon(Icons.arrow_back, color: Colors.white),
                      onPressed: widget.onBack,
                      tooltip: 'Zurück',
                    ),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(widget.title,
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              style: const TextStyle(
                                  color: Colors.white,
                                  fontSize: 22,
                                  fontWeight: FontWeight.w800,
                                  letterSpacing: 0.2)),
                          if (widget.subtitle != null &&
                              widget.subtitle!.isNotEmpty)
                            Text(widget.subtitle!,
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                                style: const TextStyle(
                                    color: Colors.white70,
                                    fontSize: 15,
                                    fontWeight: FontWeight.w500)),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
            ),

            // Center Play/Pause — größer & halbtransparent
            Expanded(
              child: Center(
                child: InkWell(
                  onTap: () {
                    setState(() {
                      isPlaying
                          ? widget.controller.pause()
                          : widget.controller.play();
                    });
                  },
                  borderRadius: BorderRadius.circular(60),
                  child: Container(
                    width: 96,
                    height: 96,
                    decoration: BoxDecoration(
                      color: Colors.white.withOpacity(0.14), // halbtransparent
                      shape: BoxShape.circle,
                      border: Border.all(color: Colors.white.withOpacity(0.18), width: 2),
                      boxShadow: [
                        BoxShadow(
                          color: Colors.black.withOpacity(0.35),
                          blurRadius: 12,
                          spreadRadius: 2,
                        ),
                      ],
                    ),
                    child: Icon(
                      isPlaying ? Icons.pause : Icons.play_arrow,
                      size: 64,
                      color: Colors.white.withOpacity(0.92),
                    ),
                  ),
                ),
              ),
            ),

            // Bottom controls + Timeline + Next
            Padding(
              padding: const EdgeInsets.fromLTRB(18, 8, 18, 18),
              child: Column(
                children: [
                  Row(
                    children: [
                      Text(_fmt(_position),
                          style: const TextStyle(color: Colors.white70, fontSize: 14)),
                      const Spacer(),
                      Text(_fmt(_duration),
                          style: const TextStyle(color: Colors.white70, fontSize: 14)),
                    ],
                  ),
                  _SeekBar(
                    position: _position,
                    duration: _duration,
                    onSeekEnd: (target) async {
                      await widget.controller.seekTo(target);
                      setState(() => _dragging = false);
                    },
                    onSeekStart: () => setState(() => _dragging = true),
                  ),
                  const SizedBox(height: 8),
                  Row(
                    children: [
                      IconButton(
                        iconSize: 28,
                        icon: Icon(
                          widget.controller.value.isPlaying
                              ? Icons.pause
                              : Icons.play_arrow,
                          color: Colors.white,
                        ),
                        onPressed: () {
                          setState(() {
                            widget.controller.value.isPlaying
                                ? widget.controller.pause()
                                : widget.controller.play();
                          });
                        },
                        tooltip: widget.controller.value.isPlaying ? 'Pause' : 'Abspielen',
                      ),
                      IconButton(
                        iconSize: 26,
                        icon: const Icon(Icons.replay_10, color: Colors.white),
                        onPressed: () async {
                          final cur = widget.controller.value.position;
                          await widget.controller
                              .seekTo(cur - const Duration(seconds: 10));
                          setState(() {});
                        },
                        tooltip: '-10 Sekunden',
                      ),
                      IconButton(
                        iconSize: 26,
                        icon: const Icon(Icons.forward_10, color: Colors.white),
                        onPressed: () async {
                          final cur = widget.controller.value.position;
                          await widget.controller
                              .seekTo(cur + const Duration(seconds: 10));
                          setState(() {});
                        },
                        tooltip: '+10 Sekunden',
                      ),
                      const Spacer(),
                      if (widget.showNext && widget.onNext != null)
                        TextButton.icon(
                          style: TextButton.styleFrom(
                            foregroundColor: Colors.white,
                            backgroundColor: Colors.white.withOpacity(0.12),
                            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(10),
                            ),
                          ),
                          onPressed: widget.onNext,
                          icon: const Icon(Icons.skip_next_rounded, size: 22),
                          label: Text(
                            widget.nextLabel ?? 'Nächste Folge',
                            overflow: TextOverflow.ellipsis,
                          ),
                        ),
                    ],
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

/* ----------------------------- Seekbar ------------------------------ */

class _SeekBar extends StatefulWidget {
  const _SeekBar({
    required this.position,
    required this.duration,
    required this.onSeekEnd,
    this.onSeekStart,
  });

  final Duration position;
  final Duration duration;
  final ValueChanged<Duration> onSeekEnd;
  final VoidCallback? onSeekStart;

  @override
  State<_SeekBar> createState() => _SeekBarState();
}

class _SeekBarState extends State<_SeekBar> {
  // während des Drag die prozentuale Position 0..1 puffern
  double? _dragPercent;

  double get _progress {
    final totalMs = widget.duration.inMilliseconds;
    if (totalMs <= 0) return 0.0;
    final clamped = widget.position.inMilliseconds.clamp(0, totalMs);
    return clamped / totalMs;
  }

  void _startDrag(Offset localPos, double width) {
    widget.onSeekStart?.call();
    setState(() {
      _dragPercent = (localPos.dx / width).clamp(0.0, 1.0);
    });
  }

  void _updateDrag(Offset localPos, double width) {
    setState(() {
      _dragPercent = (localPos.dx / width).clamp(0.0, 1.0);
    });
  }

  void _endDrag() {
    final p = _dragPercent ?? _progress;
    final targetMs = (p * widget.duration.inMilliseconds).round();
    widget.onSeekEnd(Duration(milliseconds: targetMs));
    setState(() => _dragPercent = null);
  }

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (_, c) {
        final width = c.maxWidth;
        final percent = (_dragPercent ?? _progress).clamp(0.0, 1.0);

        return GestureDetector(
          behavior: HitTestBehavior.opaque,
          onTapDown: (d) => _startDrag(d.localPosition, width),
          onTapUp: (_) => _endDrag(),
          onHorizontalDragStart: (d) => _startDrag(d.localPosition, width),
          onHorizontalDragUpdate: (d) => _updateDrag(d.localPosition, width),
          onHorizontalDragEnd: (_) => _endDrag(),
          child: CustomPaint(
            size: const Size(double.infinity, 30),
            painter: _SeekBarPainter(
              percent: percent,
              barHeight: 8,         // etwas dicker
              radius: 5,
              startColor: const Color(0xFFFF0103),
              endColor: const Color(0xFFFF0089),
              inactiveColor: Colors.white24,
              thumbRadius: 8.5,
            ),
          ),
        );
      },
    );
  }
}

class _SeekBarPainter extends CustomPainter {
  _SeekBarPainter({
    required this.percent,
    required this.barHeight,
    required this.radius,
    required this.startColor,
    required this.endColor,
    required this.inactiveColor,
    required this.thumbRadius,
  });

  final double percent;        // 0..1
  final double barHeight;      // z.B. 8
  final double radius;         // Corner-Radius der Bar
  final double thumbRadius;    // Thumb-Kreis

  final Color startColor;      // Verlauf links
  final Color endColor;        // Verlauf rechts
  final Color inactiveColor;   // Rest der Leiste

  @override
  void paint(Canvas canvas, Size size) {
    final centerY = size.height / 2;
    final barTop = centerY - barHeight / 2;
    final barRect = Rect.fromLTWH(0, barTop, size.width, barHeight);
    final rrect = RRect.fromRectAndRadius(barRect, Radius.circular(radius));

    // Inaktive Leiste
    final inactivePaint = Paint()..color = inactiveColor;
    canvas.drawRRect(rrect, inactivePaint);

    // Aktiver Teil (Gradient)
    final activeWidth = (size.width * percent).clamp(0.0, size.width);
    if (activeWidth > 0) {
      final activeRect = Rect.fromLTWH(0, barTop, activeWidth, barHeight);
      final activePaint = Paint()
        ..shader = const LinearGradient(
          colors: [Color(0xFFFF0103), Color(0xFFFF0089)],
        ).createShader(activeRect);
      final activeRRect = RRect.fromRectAndRadius(activeRect, Radius.circular(radius));
      canvas.drawRRect(activeRRect, activePaint);
    }

    // Thumb
    final thumbCenter = Offset(activeWidth, centerY);
    final thumbPaint = Paint()..color = Colors.white;
    canvas.drawCircle(thumbCenter, thumbRadius, thumbPaint);
  }

  @override
  bool shouldRepaint(covariant _SeekBarPainter old) {
    return percent != old.percent ||
           startColor != old.startColor ||
           endColor != old.endColor ||
           inactiveColor != old.inactiveColor ||
           barHeight != old.barHeight ||
           thumbRadius != old.thumbRadius;
  }
}
