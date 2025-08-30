import 'dart:async';
import 'package:flutter/material.dart';
import '../data/jellyfin_api.dart';

class QuickConnectSheet extends StatefulWidget {
  final JfApi api;
  final void Function(String userId, String token) onAuthorized;
  const QuickConnectSheet({super.key, required this.api, required this.onAuthorized});

  @override
  State<QuickConnectSheet> createState() => _QuickConnectSheetState();
}

class _QuickConnectSheetState extends State<QuickConnectSheet> {
  String? _secret;
  String? _code;
  bool _polling = false;
  String? _status;

  Timer? _timer;

  @override
  void initState() {
    super.initState();
    _start();
  }

  @override
  void dispose() {
    _timer?.cancel();
    super.dispose();
  }

  Future<void> _start() async {
    try {
      final (secret, code) = await widget.api.quickConnectInitiate();
      setState(() {
        _secret = secret;
        _code = code;
        _status = 'Bitte gib den Code auf einem bereits angemeldeten Gerät ein.';
      });
      _beginPolling();
    } catch (e) {
      setState(() { _status = 'Fehler: $e'; });
    }
  }

  void _beginPolling() {
    _polling = true;
    _timer = Timer.periodic(const Duration(seconds: 2), (_) async {
      if (!_polling || _secret == null) return;
      try {
        final state = await widget.api.quickConnectState(_secret!);
        final status = state['Status'] as String? ?? 'Unknown';
        if (status == 'Authorized') {
          final token = state['AccessToken'] as String?;
          final userId = state['UserId'] as String?;
          if (token != null && userId != null) {
            _polling = false;
            _timer?.cancel();
            if (mounted) {
              widget.onAuthorized(userId, token);
              Navigator.of(context).pop();
            }
          } else {
            setState(() { _status = 'Autorisiert – warte auf Token...'; });
          }
        } else {
          setState(() { _status = 'Status: $status'; });
        }
      } catch (e) {
        setState(() { _status = 'Polling‑Fehler: $e'; });
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: EdgeInsets.only(
        bottom: MediaQuery.of(context).viewInsets.bottom,
        left: 24, right: 24, top: 24,
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Text('Quick Connect', style: Theme.of(context).textTheme.titleLarge),
          const SizedBox(height: 8),
          if (_code != null)
            SelectableText('Dein Code: $_code', style: Theme.of(context).textTheme.headlineMedium),
          const SizedBox(height: 12),
          if (_status != null) Text(_status!),
          const SizedBox(height: 16),
          FilledButton.icon(
            onPressed: () => Navigator.of(context).pop(),
            icon: const Icon(Icons.close),
            label: const Text('Schließen'),
          ),
          const SizedBox(height: 24),
        ],
      ),
    );
  }
}
