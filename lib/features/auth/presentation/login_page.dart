import 'dart:async';
import 'dart:io' show Platform;
import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:provider/provider.dart';
import '../../../routing/app_router.dart';
import '../../servers/data/server_store.dart';
import '../data/jellyfin_api.dart';
import '../data/models.dart';
import 'quick_connect_sheet.dart';

class LoginPage extends StatefulWidget {
  const LoginPage({super.key});

  @override
  State<LoginPage> createState() => _LoginPageState();
}

class _LoginPageState extends State<LoginPage> {
  final _serverCtrl = TextEditingController();
  final _nameCtrl = TextEditingController();
  final _passCtrl = TextEditingController();
  bool _busy = false;
  String? _error;

  @override
  void dispose() {
    _serverCtrl.dispose();
    _nameCtrl.dispose();
    _passCtrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final store = context.watch<ServerStore>();
    final selected = store.selected;
    _serverCtrl.text = selected?.baseUrl ?? _serverCtrl.text;

    return Scaffold(
      appBar: AppBar(
        title: const Text('Jellydesk – Login'),
        actions: [
          IconButton(
            icon: const Icon(Icons.storage_rounded),
            tooltip: 'Server wechseln',
            onPressed: () => context.push('/servers'),
          ),
          IconButton(
            icon: const Icon(Icons.info_outline_rounded),
            onPressed: () => context.push('/about'),
          ),
        ],
      ),
      body: Center(
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 520),
          child: Padding(
            padding: const EdgeInsets.all(24),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Text(
                  'Verbinde deinen Jellyfin‑Server',
                  style: Theme.of(context).textTheme.headlineSmall,
                ),
                const SizedBox(height: 12),
                TextField(
                  controller: _serverCtrl,
                  decoration: const InputDecoration(
                    labelText: 'Server URL (z. B. https://media.example.com)',
                    prefixIcon: Icon(Icons.link_rounded),
                  ),
                ),
                const SizedBox(height: 12),
                Row(
                  children: [
                    Expanded(
                      child: TextField(
                        controller: _nameCtrl,
                        decoration: const InputDecoration(
                          labelText: 'Benutzername',
                          prefixIcon: Icon(Icons.person_outline_rounded),
                        ),
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: TextField(
                        controller: _passCtrl,
                        decoration: const InputDecoration(
                          labelText: 'Passwort',
                          prefixIcon: Icon(Icons.lock_outline_rounded),
                        ),
                        obscureText: true,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 12),
                if (_error != null) Text(_error!, style: TextStyle(color: Theme.of(context).colorScheme.error)),
                const SizedBox(height: 12),
                FilledButton.icon(
                  icon: const Icon(Icons.login_rounded),
                  label: _busy ? const Text('Anmelden ...') : const Text('Anmelden'),
                  onPressed: _busy ? null : () async {
                    setState(() { _busy = true; _error = null; });
                    try {
                      final api = _buildApi(_serverCtrl.text.trim());
                      final (userId, token) = await api.authenticateByName(_nameCtrl.text.trim(), _passCtrl.text);
                      final store = context.read<ServerStore>();
                      if (store.selected == null || store.selected!.baseUrl != _serverCtrl.text.trim()) {
                        await store.addServer(ServerProfile(name: 'Server', baseUrl: _serverCtrl.text.trim(), accessToken: token, userId: userId));
                      } else {
                        await store.updateSelectedToken(token: token, userId: userId);
                      }
                      if (mounted) context.go('/home');
                    } catch (e) {
                      setState(() { _error = e.toString(); });
                    } finally {
                      if (mounted) setState(() { _busy = false; });
                    }
                  },
                ),
                const SizedBox(height: 12),
                OutlinedButton.icon(
                  icon: const Icon(Icons.bolt_rounded),
                  label: const Text('Quick Connect'),
                  onPressed: _busy ? null : () async {
                    final base = _serverCtrl.text.trim();
                    if (base.isEmpty) {
                      setState(() { _error = 'Bitte zuerst die Server‑URL eintragen.'; });
                      return;
                    }
                    final api = _buildApi(base);
                    await showModalBottomSheet(
                      context: context,
                      isScrollControlled: true,
                      builder: (_) => QuickConnectSheet(api: api, onAuthorized: (userId, token) async {
                        final store = context.read<ServerStore>();
                        if (store.selected == null || store.selected!.baseUrl != base) {
                          await store.addServer(ServerProfile(name: 'Server', baseUrl: base, accessToken: token, userId: userId));
                        } else {
                          await store.updateSelectedToken(token: token, userId: userId);
                        }
                        if (context.mounted) context.go('/home');
                      }),
                    );
                  },
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  JfApi _buildApi(String baseUrl) {
    // In einer echten App: stabile DeviceId persistieren
    return JfApi(
      baseUrl: baseUrl.replaceAll(RegExp(r"/+$"), ''),
      clientName: 'Jellydesk',
      deviceName: 'FlutterClient',
      deviceId: 'flutter-device',
    );
  }
}
