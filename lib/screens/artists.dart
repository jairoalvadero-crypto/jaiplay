import 'package:flutter/material.dart';

import '../services.dart';
import '../theme.dart';
import '../widgets.dart';
import 'artist.dart';

class FollowedArtistsScreen extends StatelessWidget {
  const FollowedArtistsScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      extendBody: true,
      appBar: AppBar(title: const Text('Artistas')),
      body: ListenableBuilder(
        listenable: store,
        builder: (context, _) {
          final list = store.artists;
          if (list.isEmpty) {
            return const Center(
              child: Padding(
                padding: EdgeInsets.all(32),
                child: Text(
                  'Aún no sigues a ningún artista.\\nBúscalo y pulsa Seguir.',
                  textAlign: TextAlign.center,
                  style: TextStyle(color: kMuted, fontSize: 16),
                ),
              ),
            );
          }
          return ListView.builder(
            padding: const EdgeInsets.fromLTRB(20, 8, 20, 24),
            itemCount: list.length,
            itemBuilder: (context, i) {
              final a = list[i];
              return ListTile(
                contentPadding: EdgeInsets.zero,
                leading: Cover(a.image, size: 56, radius: 28),
                title: Text(a.name,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(
                        fontSize: 17, fontWeight: FontWeight.w600)),
                subtitle:
                    const Text('Artista', style: TextStyle(color: kMuted)),
                trailing: const Icon(Icons.chevron_right, color: kMuted),
                onTap: () => Navigator.push(
                  context,
                  MaterialPageRoute(builder: (_) => ArtistScreen(artist: a)),
                ),
              );
            },
          );
        },
      ),
      bottomNavigationBar: const MiniPlayer(),
    );
  }
}
