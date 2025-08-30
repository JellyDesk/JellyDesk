import 'dart:math';
import 'package:flutter/foundation.dart';
import 'package:hive_flutter/hive_flutter.dart';
import '../../../features/auth/data/models.dart';

class ServerStore extends ChangeNotifier {
  static const _box = 'servers';
  static const _selectedKey = 'selected';
  final bool isTvMode;

  late Box<ServerProfile> _servers;
  late Box _meta;
  int _selectedIndex = -1;

  ServerStore({this.isTvMode = false});

  List<ServerProfile> get servers => _servers.values.toList(growable: false);
  int get selectedIndex => _selectedIndex;
  ServerProfile? get selected => _selectedIndex >= 0 && _selectedIndex < _servers.length ? _servers.getAt(_selectedIndex) : null;

  static Future<void> ensureBoxes() async {
    if (!Hive.isAdapterRegistered(11)) {
      Hive.registerAdapter(ServerProfileAdapter());
    }
    await Hive.openBox<ServerProfile>(_box);
    await Hive.openBox(_box + '_meta');
  }

  Future<void> load() async {
    _servers = Hive.box<ServerProfile>(_box);
    _meta = Hive.box(_box + '_meta');
    _selectedIndex = _meta.get(_selectedKey, defaultValue: -1) as int;
    notifyListeners();
  }

  Future<void> addServer(ServerProfile profile, {bool makeActive = true}) async {
    await _servers.add(profile);
    if (makeActive) {
      _selectedIndex = _servers.length - 1;
      await _meta.put(_selectedKey, _selectedIndex);
    }
    notifyListeners();
  }

  Future<void> updateSelectedToken({required String token, required String userId}) async {
    final sel = selected;
    if (sel == null) return;
    sel.accessToken = token;
    sel.userId = userId;
    await sel.save();
    notifyListeners();
  }

  Future<void> switchTo(int index) async {
    if (index < 0 || index >= _servers.length) return;
    _selectedIndex = index;
    await _meta.put(_selectedKey, _selectedIndex);
    notifyListeners();
  }

  Future<void> removeAt(int index) async {
    if (index < 0 || index >= _servers.length) return;
    await _servers.deleteAt(index);
    if (_selectedIndex >= _servers.length) {
      _selectedIndex = _servers.length - 1;
      await _meta.put(_selectedKey, _selectedIndex);
    }
    notifyListeners();
  }
}
