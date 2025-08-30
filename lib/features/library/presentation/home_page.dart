import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:provider/provider.dart';
import '../../auth/data/jellyfin_api.dart';
import '../../auth/data/models.dart';
import '../../servers/data/server_store.dart';
import 'items_grid.dart';

class HomePage extends StatefulWidget {
  const HomePage({super.key});

  @override
  State<HomePage> createState() => _HomePageState();
}

class _HomePageState extends State<HomePage> {
  late JfApi _api;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    final store = context.read<ServerStore>();
    final sel = store.selected;
    if (sel == null || sel.accessToken == null || sel.userId == null) {
      context.go('/');
    } else {
      _api = JfApi(
        baseUrl: sel.baseUrl,
        clientName: 'Jellydesk',
        deviceName: 'FlutterClient',
        deviceId: 'flutter-device',
        accessToken: sel.accessToken,
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final store = context.watch<ServerStore>();
    final sel = store.selected;

    return Scaffold(
      appBar: AppBar(
        title: const Text('Jellydesk – Bibliothek'),
        actions: [
          IconButton(
            icon: const Icon(Icons.cast),
            tooltip: 'Cast',
            onPressed: () => showDialog(context: context, builder: (_) => const _CastDialog()),
          ),
          IconButton(
            icon: const Icon(Icons.airplay),
            tooltip: 'AirPlay (iOS)',
            onPressed: () => showDialog(context: context, builder: (_) => const _AirPlayDialog()),
          ),
          IconButton(
            icon: const Icon(Icons.info_outline_rounded),
            onPressed: () => context.push('/about'),
          ),
        ],
      ),
      drawer: Drawer(
        child: SafeArea(
          child: Column(
            children: [
              ListTile(
                leading: const Icon(Icons.storage_rounded),
                title: const Text('Server wechseln'),
                onTap: () { Navigator.pop(context); context.push('/servers'); },
              ),
              const Divider(),
              ListTile(
                leading: const Icon(Icons.info_outline_rounded),
                title: const Text('About'),
                onTap: () { Navigator.pop(context); context.push('/about'); },
              ),
            ],
          ),
        ),
      ),
      body: sel == null ? const SizedBox() : _Libraries(api: _api, userId: sel.userId!),
    );
  }
}

class _Libraries extends StatefulWidget {
  final JfApi api;
  final String userId;
  const _Libraries({required this.api, required this.userId});

  @override
  State<_Libraries> createState() => _LibrariesState();
}

class _LibrariesState extends State<_Libraries> {
  late Future<List<Map<String, dynamic>>> _future;

  @override
  void initState() {
    super.initState();
    _future = widget.api.getViews(widget.userId);
  }

  @override
  Widget build(BuildContext context) {
    return FutureBuilder<List<Map<String, dynamic>>>(
      future: _future,
      builder: (context, snap) {
        if (snap.connectionState != ConnectionState.done) {
          return const Center(child: CircularProgressIndicator());
        }
        if (snap.hasError) {
          return Center(child: Text('Fehler: ${snap.error}'));
        }
        final views = snap.data ?? [];
        return ListView.separated(
          padding: const EdgeInsets.all(16),
          itemCount: views.length,
          separatorBuilder: (_, __) => const SizedBox(height: 12),
          itemBuilder: (_, i) {
            final v = views[i];
            final name = v['Name'] as String? ?? 'View';
            final id = v['Id'] as String? ?? '';
            return Card(
              child: ListTile(
                title: Text(name),
                trailing: const Icon(Icons.chevron_right_rounded),
                onTap: () {
                  Navigator.of(context).push(MaterialPageRoute(
                    builder: (_) => ItemsGrid(
                      api: widget.api,
                      userId: widget.userId,
                      parentId: id,
                    ),
                  ));
                },
              ),
            );
          },
        );
      },
    );
  }
}

class _CastDialog extends StatelessWidget {
  const _CastDialog();

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: const Text('Chromecast'),
      content: const Text('Chromecast‑Discovery/Connect ist integriert (Stub). Receiver‑App‑ID im Code anpassen.'),
      actions: [
        TextButton(onPressed: () => Navigator.pop(context), child: const Text('OK')),
      ],
    );
  }
}

class _AirPlayDialog extends StatelessWidget {
  const _AirPlayDialog();

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: const Text('AirPlay (iOS)'),
      content: const Text('AirPlay‑RoutePicker ist verfügbar (nur iOS).'),
      actions: [
        TextButton(onPressed: () => Navigator.pop(context), child: const Text('OK')),
      ],
    );
  }
}
