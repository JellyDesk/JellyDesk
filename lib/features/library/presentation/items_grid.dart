import 'package:flutter/material.dart';
import '../../auth/data/jellyfin_api.dart';
import 'item_detail_page.dart';

class ItemsGrid extends StatefulWidget {
  final JfApi api;
  final String userId;
  final String parentId;
  const ItemsGrid({super.key, required this.api, required this.userId, required this.parentId});

  @override
  State<ItemsGrid> createState() => _ItemsGridState();
}

class _ItemsGridState extends State<ItemsGrid> {
  late Future<List<Map<String, dynamic>>> _future;

  @override
  void initState() {
    super.initState();
    _future = widget.api.getItems(widget.userId, parentId: widget.parentId);
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Inhalte')),
      body: FutureBuilder<List<Map<String, dynamic>>>(
        future: _future,
        builder: (context, snap) {
          if (snap.connectionState != ConnectionState.done) {
            return const Center(child: CircularProgressIndicator());
          }
          if (snap.hasError) {
            return Center(child: Text('Fehler: ${snap.error}'));
          }
          final items = snap.data ?? [];
          if (items.isEmpty) {
            return const Center(child: Text('Keine Inhalte.'));
          }
          final colCount = MediaQuery.of(context).size.width ~/ 180;
          return GridView.builder(
            padding: const EdgeInsets.all(16),
            gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
              crossAxisCount: colCount.clamp(2, 8),
              childAspectRatio: 0.66,
              mainAxisSpacing: 12,
              crossAxisSpacing: 12,
            ),
            itemCount: items.length,
            itemBuilder: (_, i) {
              final it = items[i];
              final id = it['Id'] as String;
              final name = it['Name'] as String? ?? 'Item';
              final type = it['Type'] as String? ?? 'Item';
              final img = widget.api.itemImageUrl(id, width: 480);
              return InkWell(
                onTap: () => Navigator.of(context).push(MaterialPageRoute(
                  builder: (_) => ItemDetailPage(api: widget.api, item: it),
                )),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    Expanded(
                      child: ClipRRect(
                        borderRadius: BorderRadius.circular(16),
                        child: Image.network(img, fit: BoxFit.cover),
                      ),
                    ),
                    const SizedBox(height: 8),
                    Text(name, maxLines: 2, overflow: TextOverflow.ellipsis),
                    Text(type, style: Theme.of(context).textTheme.labelSmall),
                  ],
                ),
              );
            },
          );
        },
      ),
    );
  }
}
