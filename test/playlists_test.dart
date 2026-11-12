import 'package:flutter_test/flutter_test.dart';
import 'package:jaiplay/models.dart';

Track _track(String id) => Track(
      id: id,
      title: 'Canción $id',
      artist: 'Artista',
      thumb: 'https://example.com/$id.jpg',
    );

void main() {
  test('removes a repeated artist prefix and suffix from displayed track title',
      () {
    final prefix = Track(
      id: 'prefix',
      title: 'Rosalía - Malamente',
      artist: 'Rosalía',
      thumb: '',
    );
    final suffix = Track(
      id: 'suffix',
      title: 'Malamente - Rosalía',
      artist: 'Rosalía',
      thumb: '',
    );

    expect(prefix.displayTitle, 'Malamente');
    expect(suffix.displayTitle, 'Malamente');
  });

  test('uses the first track cover unless a custom one is set', () {
    final playlist = UserPlaylist(
      id: 'test',
      name: 'Favoritas',
      tracks: [_track('one')],
    );

    expect(playlist.cover, _track('one').thumb);
    expect(
      playlist.copyWith(customCoverPath: '/covers/favoritas.jpg').cover,
      '/covers/favoritas.jpg',
    );
    expect(
      playlist.copyWith(clearCustomCover: true).cover,
      _track('one').thumb,
    );
  });

  test('round-trips tracks and custom playlist cover through JSON', () {
    final playlist = UserPlaylist(
      id: 'test',
      name: 'Mix',
      tracks: [_track('one'), _track('two')],
      customCoverPath: '/covers/mix.jpg',
    );

    final restored = UserPlaylist.fromJson(playlist.toJson());

    expect(restored.name, 'Mix');
    expect(restored.tracks.map((track) => track.id), ['one', 'two']);
    expect(restored.cover, '/covers/mix.jpg');
  });
}
