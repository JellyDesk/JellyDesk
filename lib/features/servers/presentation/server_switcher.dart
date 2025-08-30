import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../auth/data/models.dart';
import '../data/server_store.dart';

class ServerSwitcherPage extends StatefulWidget {
  const ServerSwitcherPage({super.key});

  @override
  State<ServerSwitcherPage> createState() => _ServerSwitcherPageState();
}

class _ServerSwitcherPageState extends State<ServerSwitcherPage> {
  final _nameCtrl = TextEditingController();
  final _urlCtrl = TextEditingController();

  @override
  void dispose() {
    _nameCtrl.dispose();
    _urlCtrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final store = context.watch<ServerStore>();
    return Scaffold(
      appBar: AppBar(title: const Text('Server verwalten')),
      body: Column(
        children: [
          Padding(
            padding: const EdgeInsets.all(16),
            child: Row(
              children: [
                Expanded(child: TextField(
                  controller: _nameCtrl,
                  decoration: const InputDecoration(labelText: 'Name (z. B. Zuhause)'),
                )),
                const SizedBox(width: 12),
                Expanded(child: TextField(
                  controller: _urlCtrl,
                  decoration: const InputDecoration(labelText: 'Basis‑URL (https://...)'),
                )),
                const SizedBox(width: 12),
                FilledButton.icon(
                  onPressed: () async {
                    final name = _nameCtrl.text.trim().isEmpty ? 'Server' : _nameCtrl.text.trim();
                    final url = _urlCtrl.text.trim();
                    if (url.isEmpty) return;
                    await store.addServer(ServerProfile(name: name, baseUrl: url));
                    _nameCtrl.clear();
                    _urlCtrl.clear();
                  },
                  icon: const Icon(Icons.add),
                  label: const Text('Hinzufügen'),
                ),
              ],
            ),
          ),
          const Divider(height: 1),
          Expanded(
            child: ListView.separated(
              itemCount: store.servers.length,
              separatorBuilder: (_, __) => const Divider(height: 1),
              itemBuilder: (_, i) {
                final s = store.servers[i];
                final selected = i == store.selectedIndex;
                return ListTile(
                  title: Text('${s.name}  •  ${s.baseUrl}'),
                  subtitle: Text(s.userId == null ? 'Nicht angemeldet' : 'User: ${s.userId}'),
                  leading: Icon(selected ? Icons.radio_button_checked : Icons.radio_button_off),
                  trailing: IconButton(
                    icon: const Icon(Icons.delete_outline_rounded),
                    onPressed: () => store.removeAt(i),
                  ),
                  onTap: () => store.switchTo(i),
                );
              },
            ),
          ),
        ],
      ),
    );
  }
}
