import 'package:flutter/material.dart';
import '../../services/image_url_builder.dart';
import 'live_tv_repository.dart';

class LiveTvPage extends StatelessWidget {
  const LiveTvPage({super.key, required this.repo, required this.userId, required this.iub});
  final LiveTvRepository repo;
  final String userId;
  final ImageUrlBuilder iub;

  @override
  Widget build(BuildContext context) {
    return FutureBuilder(
      future: repo.channels(userId),
      builder: (context, snap) {
        if (!snap.hasData) return const Center(child: CircularProgressIndicator());
        final items = snap.data!;
        return ListView.separated(
          itemCount: items.length,
          separatorBuilder: (_, __) => const Divider(height: 1),
          itemBuilder: (context, i) {
            final ch = items[i];
            final url = iub.logo(ch, width: 300) ?? iub.primary(ch, width: 300);
            return ListTile(
              leading: url == null
                  ? const Icon(Icons.live_tv)
                  : ClipRRect(
                      borderRadius: BorderRadius.circular(8),
                      child: Image.network(url, width: 64, height: 36, fit: BoxFit.cover),
                    ),
              title: Text(ch['Name'] ?? 'Channel'),
              subtitle: Text('${ch['Number'] ?? ''} · ${ch['ChannelType'] ?? ''}'),
            );
          },
        );
      },
    );
  }
}
