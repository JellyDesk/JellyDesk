import 'package:flutter/material.dart';
import '../../auth/data/jellyfin_api.dart';
import '../../playback/presentation/player_page.dart';

class ItemDetailPage extends StatelessWidget {
  final JfApi api;
  final Map<String, dynamic> item;
  const ItemDetailPage({super.key, required this.api, required this.item});

  @override
  Widget build(BuildContext context) {
    final id = item['Id'] as String;
    final title = item['Name'] as String? ?? 'Titel';
    final overview = item['Overview'] as String? ?? '';
    final img = api.itemImageUrl(id, width: 800);

    return Scaffold(
      appBar: AppBar(title: Text(title)),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          ClipRRect(
            borderRadius: BorderRadius.circular(20),
            child: Image.network(img, fit: BoxFit.cover, height: 320),
          ),
          const SizedBox(height: 16),
          Text(overview.isEmpty ? 'Keine Beschreibung.' : overview),
          const SizedBox(height: 24),
          FilledButton.icon(
            onPressed: () {
              Navigator.of(context).push(MaterialPageRoute(
                builder: (_) => PlayerPage(api: api, itemId: id, title: title),
              ));
            },
            icon: const Icon(Icons.play_arrow_rounded),
            label: const Text('Abspielen'),
          ),
        ],
      ),
    );
  }
}
