import 'package:hive/hive.dart';

part 'models.g.dart';

@HiveType(typeId: 11)
class ServerProfile extends HiveObject {
  @HiveField(0)
  String name;
  @HiveField(1)
  String baseUrl;
  @HiveField(2)
  String? accessToken;
  @HiveField(3)
  String? userId;

  ServerProfile({
    required this.name,
    required this.baseUrl,
    this.accessToken,
    this.userId,
  });
}

class JfView {
  final String id;
  final String name;
  JfView(this.id, this.name);
}

class JfItem {
  final String id;
  final String name;
  final String type; // Movie, Series, Episode
  JfItem({required this.id, required this.name, required this.type});
}
