import 'dart:io' show Platform;
import 'package:flutter/material.dart';
import 'package:video_player/video_player.dart';
import 'package:flutter/foundation.dart' show kIsWeb;
import '../../auth/data/jellyfin_api.dart';
// Chromecast
// ignore: depend_on_referenced_packages
import 'package:cast/cast.dart' as chromecast;
// AirPlay
// Only available on iOS; guard UI usage by platform checks
import 'package:flutter_to_airplay/flutter_to_airplay.dart' as airplay;

class PlayerPage extends StatefulWidget {
  final JfApi api;
  final String itemId;
  final String title;
  const PlayerPage({super.key, required this.api, required this.itemId, required this.title});

  @override
  State<PlayerPage> createState() => _PlayerPageState();
}

class _PlayerPageState extends State<PlayerPage> {
  VideoPlayerController? _controller;
  String? _error;

  @override
  void initState() {
    super.initState();
    _init();
  }

  Future<void> _init() async {
    try {
      // For demo purposes, try HLS master URL.
      final hls = widget.api.videoHlsMaster(widget.itemId);
      final ctrl = VideoPlayerController.networkUrl(hls);
      await ctrl.initialize();
      setState(() { _controller = ctrl; });
      await ctrl.play();
    } catch (e) {
      setState(() { _error = 'Videowiedergabe nicht verfügbar: $e'; });
    }
  }

  @override
  void dispose() {
    _controller?.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text(widget.title),
        actions: [
          IconButton(
            icon: const Icon(Icons.cast_rounded),
            onPressed: () async {
              // Basic Chromecast discovery -> connect
              try {
                final devices = await chromecast.CastDiscoveryService().search();
                if (!context.mounted) return;
                await showDialog(context: context, builder: (_) {
                  return SimpleDialog(
                    title: const Text('Chromecast Geräte'),
                    children: devices.isEmpty
                      ? [const Padding(padding: EdgeInsets.all(16), child: Text('Keine Geräte gefunden.'))]
                      : devices.map((d) => SimpleDialogOption(
                          child: Text(d.name),
                          onPressed: () async {
                            Navigator.of(context).pop();
                            final session = await chromecast.CastSessionManager().startSession(d);
                            // TODO: launch receiver app + send media
                            debugPrint('Verbunden: ${session.sessionId}');
                          },
                        )).toList(),
                  );
                });
              } catch (e) {
                ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Cast-Fehler: $e')));
              }
            },
          ),
          if (!kIsWeb && Platform.isIOS)
            const Padding(
              padding: EdgeInsets.only(right: 8),
              child: Center(child: SizedBox(height: 24, child: airplay.AirPlayRoutePickerView())),
            ),
        ],
      ),
      body: Center(
        child: _error != null
          ? Text(_error!)
          : _controller == null
            ? const CircularProgressIndicator()
            : AspectRatio(
                aspectRatio: _controller!.value.aspectRatio == 0 ? 16/9 : _controller!.value.aspectRatio,
                child: VideoPlayer(_controller!),
              ),
      ),
      floatingActionButton: _controller == null ? null : FloatingActionButton(
        onPressed: () {
          final playing = _controller!.value.isPlaying;
          setState(() { playing ? _controller!.pause() : _controller!.play(); });
        },
        child: Icon(_controller!.value.isPlaying ? Icons.pause : Icons.play_arrow),
      ),
    );
  }
}
