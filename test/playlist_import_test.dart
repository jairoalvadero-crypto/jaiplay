import 'package:flutter_test/flutter_test.dart';
import 'package:jaiplay/models.dart';
import 'package:jaiplay/playlist_import.dart';

void main() {
  test('parses public Spotify embed playlist name and tracks', () {
    final playlist = PlaylistImportService.parseSpotifyEmbed(
      '<title>Mix &amp; Más - Spotify</title>'
      '"trackList":[{"uri":"spotify:track:abc","uid":"1",'
      '"title":"Song \\"One\\"","subtitle":"Artist A"}]',
    );

    expect(playlist.name, 'Mix & Más');
    expect(playlist.tracks, hasLength(1));
    expect(playlist.tracks.single.title, 'Song "One"');
    expect(playlist.tracks.single.artist, 'Artist A');
  });

  test('parses Apple Music track lockups and artist names', () {
    final playlist = PlaylistImportService.parseAppleMusicPage(
      '<meta property="og:title" content="Lista de prueba on Apple Music">'
      '"id":"track-lockup - pl.test - 123","title":"Canción &amp; Sol",'
      '"trackNumber":1,"artistName":"Artista Uno",'
      '"id":"track-lockup - pl.test - 456","title":"Otra canción",'
      '"trackNumber":2,"artistName":"Artista Dos"',
    );

    expect(playlist.name, 'Lista de prueba');
    expect(playlist.tracks, hasLength(2));
    expect(playlist.tracks.first.title, 'Canción & Sol');
    expect(playlist.tracks.first.artist, 'Artista Uno');
    expect(playlist.tracks.last.title, 'Otra canción');
  });

  test('uses duration metadata when parsing public playlist tracks', () {
    final spotify = PlaylistImportService.parseSpotifyEmbed(
      '"uri":"spotify:track:abc","title":"Song","subtitle":"Artist",'
      '"duration":213500',
    );
    final apple = PlaylistImportService.parseAppleMusicPage(
      '"id":"track-lockup - pl.test - 123","title":"Song",'
      '"duration":"PT3M33S","artistName":"Artist"',
    );

    expect(spotify.tracks.single.seconds, 214);
    expect(apple.tracks.single.seconds, 213);
  });

  test('matches catalog variants using title, artist and duration', () {
    final source = const ImportedPlaylistTrack(
      title: 'La canción (Remastered)',
      artist: 'Artista Uno, Artista Dos',
      seconds: 203,
    );
    final wrongVersion = const Track(
      id: 'wrong',
      title: 'La canción',
      artist: 'Artista Uno - Topic',
      thumb: '',
      seconds: 260,
    );
    final correct = const Track(
      id: 'correct',
      title: 'Artista Uno - La canción (Official Audio)',
      artist: 'Artista Uno, Artista Dos',
      thumb: '',
      seconds: 204,
    );

    final result = ImportedPlaylistMatcher.bestMatch(
      source,
      [wrongVersion, correct],
    );

    expect(result?.id, 'correct');
    expect(ImportedPlaylistMatcher.isConfident(source, result), isTrue);
  });

  test('rejects a Spotify embed without public track metadata', () {
    expect(
      () => PlaylistImportService.parseSpotifyEmbed('<title>Private</title>'),
      throwsStateError,
    );
  });
}
