import '../../services/jellyfin_client.dart';
import 'dart:convert';

class LiveTvRepository {
  LiveTvRepository(this.api);
  final JellyfinClient api;

  Future<List<Map<String, dynamic>>> channels(String userId) async {
    final res = await api.get('/LiveTv/Channels', query: {
      'UserId': userId,
      'EnableImageTypes': 'Primary,Logo,Thumb,Backdrop',
      'ImageTypeLimit': '1',
      'EnableUserData': 'true',
      'IsFavorite': 'false',
      'AddCurrentProgram': 'true',
    });
    final json = jsonDecode(res.body) as Map<String, dynamic>;
    return (json['Items'] as List).cast<Map<String, dynamic>>();
  }

  Future<List<Map<String, dynamic>>> programs({
    required String userId,
    required List<String> channelIds,
    required DateTime start,
    required DateTime end,
  }) async {
    final res = await api.get('/LiveTv/Programs', query: {
      'userId': userId,
      'channelIds': channelIds.join(','),
      'startDate': start.toUtc().toIso8601String(),
      'endDate': end.toUtc().toIso8601String(),
      'EnableImages': 'true',
      'ImageTypeLimit': '1',
      'EnableUserData': 'true',
    });
    final json = jsonDecode(res.body) as Map<String, dynamic>;
    return (json['Items'] as List).cast<Map<String, dynamic>>();
  }
}
