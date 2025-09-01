import 'dart:async';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';

class AnimatedSplashPage extends StatefulWidget {
  const AnimatedSplashPage({
    super.key,
    this.onFinished,
    this.minDuration = const Duration(milliseconds: 900),
  });

  /// Wird aufgerufen, wenn der Splash fertig ist (z.B. Router -> Home).
  final VoidCallback? onFinished;

  /// Mindestens so lange anzeigen (für ein bisschen „Wow“).
  final Duration minDuration;

  @override
  State<AnimatedSplashPage> createState() => _AnimatedSplashPageState();
}

class _AnimatedSplashPageState extends State<AnimatedSplashPage>
    with SingleTickerProviderStateMixin {
  late final AnimationController _ctrl;
  late final Animation<Alignment> _begin;
  late final Animation<Alignment> _end;
  Timer? _timer;

  bool get _isMobile =>
      !kIsWeb &&
      (defaultTargetPlatform == TargetPlatform.android ||
       defaultTargetPlatform == TargetPlatform.iOS);

  @override
  void initState() {
    super.initState();
    _ctrl = AnimationController(
      vsync: this,
      duration: const Duration(seconds: 5),
    )..repeat(reverse: true);

    _begin = AlignmentTween(
      begin: const Alignment(-1.2, -1.0),
      end: const Alignment(1.2, 1.0),
    ).animate(CurvedAnimation(parent: _ctrl, curve: Curves.easeInOut));

    _end = AlignmentTween(
      begin: const Alignment(1.2, 1.0),
      end: const Alignment(-1.2, -1.0),
    ).animate(CurvedAnimation(parent: _ctrl, curve: Curves.easeInOut));

    // Mindestdauer, danach darf die App weiter
    _timer = Timer(widget.minDuration, () {
      // Wenn der Caller schon „fertig“ signalisiert hat, wird gleich gewechselt.
      // Ansonsten wartet der Caller auf eigene Init-Tasks und ruft onFinished später.
      if (widget.onFinished != null) {
        // nichts tun – Caller entscheidet den Zeitpunkt
      }
    });
  }

  @override
  void dispose() {
    _timer?.cancel();
    _ctrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final showFullLogo = !_isMobile; // Desktop = volles Logo, Mobile = Icon

    return Scaffold(
      backgroundColor: Colors.black,
      body: AnimatedBuilder(
        animation: _ctrl,
        builder: (context, _) {
          return Stack(
            fit: StackFit.expand,
            children: [
              // Bewegter Verlauf
              Container(
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    begin: _begin.value,
                    end: _end.value,
                    colors: const [
                      Color(0xFFFF0103),
                      Color(0xFFFF0089),
                    ],
                  ),
                ),
              ),
              // Leichter Overlay für Kontrast
              Container(color: Colors.black.withOpacity(0.25)),

              // Zentrum: Logo (Desktop) oder Icon (Mobile)
              Center(
                child: AnimatedScale(
                  duration: const Duration(milliseconds: 800),
                  curve: Curves.easeOutBack,
                  scale: 1.0,
                  child: Opacity(
                    opacity: 0.95,
                    child: showFullLogo
                        ? Image.asset(
                            'assets/logo_full.png',
                            width: 360,
                            fit: BoxFit.contain,
                          )
                        : ClipRRect(
                            borderRadius: BorderRadius.circular(24),
                            child: Image.asset(
                              'assets/icon.png',
                              width: 128,
                              height: 128,
                              fit: BoxFit.cover,
                            ),
                          ),
                  ),
                ),
              ),
              // Kleiner „powered by“/Version Platzhalter unten (optional)
              Positioned(
                bottom: 24,
                left: 0,
                right: 0,
                child: Center(
                  child: Text(
                    'JellyDesk',
                    style: TextStyle(
                      color: Colors.white.withOpacity(0.9),
                      fontWeight: FontWeight.w600,
                      letterSpacing: 0.6,
                    ),
                  ),
                ),
              ),
            ],
          );
        },
      ),
    );
  }
}
