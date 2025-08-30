import 'package:flutter/material.dart';
import 'package:url_launcher/url_launcher.dart';

class AboutPage extends StatelessWidget {
  const AboutPage({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('About Jellydesk')),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          Row(
            children: [
              ClipRRect(
                borderRadius: BorderRadius.circular(20),
                child: Image.asset('assets/logo.svg', height: 64, width: 64, package: null, errorBuilder: (c, e, s) {
                  // Fallback: show an icon if SVG can't be rendered as Image.asset
                  return const SizedBox(height: 64, width: 64, child: Icon(Icons.movie_creation_outlined, size: 48));
                }),
              ),
              const SizedBox(width: 16),
              Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text('Jellydesk', style: Theme.of(context).textTheme.headlineSmall),
                  Text('Version 0.1.0'),
                ],
              ),
            ],
          ),
          const SizedBox(height: 24),
          const Text('The most modern Jellyfin client in the world.'),
          const SizedBox(height: 12),
          Wrap(
            spacing: 12,
            children: [
              FilledButton(
                onPressed: () => _open('https://github.com/JellyDesk/JellyDesk'),
                child: const Text('GitHub Repo'),
              ),
              OutlinedButton(
                onPressed: () => showLicensePage(
                  context: context,
                  applicationName: 'Jellydesk',
                  applicationVersion: '0.1.0',
                  applicationLegalese: '© 2025 SchmittDEV.',
                ),
                child: const Text('Open‑Source‑Licenses'),
              ),
            ],
          ),
          const SizedBox(height: 24),
          const Text('Hinweis: Apple TV (tvOS) ist experimentell (keine offizielle Flutter‑Unterstützung). Android TV läuft im TV‑Modus als Android‑Ziel.'),
        ],
      ),
    );
  }

  static Future<void> _open(String url) async {
    final uri = Uri.parse(url);
    if (!await launchUrl(uri, mode: LaunchMode.externalApplication)) {}
  }
}
