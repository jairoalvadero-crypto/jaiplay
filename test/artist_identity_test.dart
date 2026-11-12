import 'package:flutter_test/flutter_test.dart';
import 'package:jaiplay/models.dart';

void main() {
  test('resolves Kaze to the official @putokaze channel', () {
    final artist = canonicalArtist(
      const Artist(
          name: 'Kaze - Topic', image: 'wrong-image', channelId: 'old'),
    );

    expect(artist.name, 'KAZE');
    expect(artist.image, isEmpty);
    expect(artist.channelId, kazeOfficialChannelId);
  });

  test('leaves other artist identities unchanged', () {
    const artist = Artist(name: 'Kazeem', image: 'cover', channelId: 'channel');

    expect(canonicalArtist(artist).channelId, 'channel');
  });
}
