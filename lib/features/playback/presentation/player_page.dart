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
                      if (_controlsVisible) _ControlsOverlay(controller: c),
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

/// Overlay mit Play/Pause und Gradient-Timeline (#FF0103 → #FF0089)
class _ControlsOverlay extends StatefulWidget {
  const _ControlsOverlay({required this.controller});
  final VideoPlayerController controller;

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
            stops: [0.4, 0.7, 1.0],
          ),
        ),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            const SizedBox(height: 12),
            Center(
              child: IconButton(
                iconSize: 64,
                color: Colors.white,
                icon: Icon(isPlaying
                    ? Icons.pause_circle_filled
                    : Icons.play_circle_fill),
                onPressed: () {
                  setState(() {
                    isPlaying
                        ? widget.controller.pause()
                        : widget.controller.play();
                  });
                },
              ),
            ),
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 8, 16, 16),
              child: Column(
                children: [
                  Row(
                    children: [
                      Text(_fmt(_position),
                          style: const TextStyle(color: Colors.white70)),
                      const Spacer(),
                      Text(_fmt(_duration),
                          style: const TextStyle(color: Colors.white70)),
                    ],
                  ),
                  SliderTheme(
                    data: SliderTheme.of(context).copyWith(
                      trackHeight: 5,
                      thumbShape:
                          const RoundSliderThumbShape(enabledThumbRadius: 8),
                      overlayShape:
                          const RoundSliderOverlayShape(overlayRadius: 14),
                      trackShape: const _GradientTrackShape(
                        startColor: Color(0xFFFF0103), // rot
                        endColor: Color(0xFFFF0089),   // pink
                        inactiveColor: Colors.white24,
                      ),
                      thumbColor: Colors.white,
                      activeTrackColor:
                          Colors.transparent, // wird vom TrackShape gemalt
                      inactiveTrackColor: Colors.transparent,
                    ),
                    child: Slider(
                      value: _progress.clamp(0.0, 1.0),
                      onChangeStart: (_) => setState(() => _dragging = true),
                      onChanged: (v) {
                        // nur UI beim Drag
                        setState(() {});
                      },
                      onChangeEnd: (v) async {
                        final target = Duration(
                          milliseconds:
                              (v * _duration.inMilliseconds).round(),
                        );
                        await widget.controller.seekTo(target);
                        setState(() => _dragging = false);
                      },
                    ),
                  ),
                  Row(
                    children: [
                      IconButton(
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
                      ),
                      IconButton(
                        icon: const Icon(Icons.replay_10, color: Colors.white),
                        onPressed: () async {
                          final cur = widget.controller.value.position;
                          await widget.controller
                              .seekTo(cur - const Duration(seconds: 10));
                          setState(() {});
                        },
                      ),
                      IconButton(
                        icon:
                            const Icon(Icons.forward_10, color: Colors.white),
                        onPressed: () async {
                          final cur = widget.controller.value.position;
                          await widget.controller
                              .seekTo(cur + const Duration(seconds: 10));
                          setState(() {});
                        },
                      ),
                      const Spacer(),
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

/// Zeichnet den Slider-Track mit Verlauf (links aktiver Teil als Gradient).
class _GradientTrackShape extends SliderTrackShape with BaseSliderTrackShape {
  const _GradientTrackShape({
    required this.startColor,
    required this.endColor,
    this.inactiveColor = const Color(0x33FFFFFF),
  });

  final Color startColor;
  final Color endColor;
  final Color inactiveColor;

  @override
  void paint(
    PaintingContext context,
    Offset offset, {
    required RenderBox parentBox,
    required SliderThemeData sliderTheme,
    required Animation<double> enableAnimation,
    required Offset thumbCenter,
    Offset? secondaryOffset, // wichtig für aktuelle Flutter-Versionen
    bool isEnabled = false,
    bool isDiscrete = false,
    required TextDirection textDirection,
  }) {
    final trackRect = getPreferredRect(
      parentBox: parentBox,
      offset: offset,
      sliderTheme: sliderTheme,
      isEnabled: isEnabled,
      isDiscrete: isDiscrete,
    );

    // aktiver/inaktiver Teil je nach TextDirection
    late Rect activeRect;
    late Rect inactiveRect;
    if (textDirection == TextDirection.ltr) {
      activeRect = Rect.fromLTRB(trackRect.left, trackRect.top, thumbCenter.dx, trackRect.bottom);
      inactiveRect = Rect.fromLTRB(thumbCenter.dx, trackRect.top, trackRect.right, trackRect.bottom);
    } else {
      activeRect = Rect.fromLTRB(thumbCenter.dx, trackRect.top, trackRect.right, trackRect.bottom);
      inactiveRect = Rect.fromLTRB(trackRect.left, trackRect.top, thumbCenter.dx, trackRect.bottom);
    }

    final activePaint = Paint()
      ..shader = LinearGradient(colors: [startColor, endColor]).createShader(activeRect);
    final inactivePaint = Paint()..color = inactiveColor;

    context.canvas.drawRRect(
      RRect.fromRectAndRadius(activeRect, const Radius.circular(4)),
      activePaint,
    );
    context.canvas.drawRRect(
      RRect.fromRectAndRadius(inactiveRect, const Radius.circular(4)),
      inactivePaint,
    );
  }
}
