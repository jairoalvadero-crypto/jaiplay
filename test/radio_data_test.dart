import 'package:flutter_test/flutter_test.dart';
import 'package:jaiplay/models.dart';
import 'package:jaiplay/radio_data.dart';

void main() {
  test('classifies stations by news and music tags', () {
    final news = Track(
      id: 'radio:news',
      title: 'Radio Noticias',
      artist: 'España',
      thumb: '',
      radioTags: ['local news'],
    );
    final music = Track(
      id: 'radio:music',
      title: 'Radio Pop',
      artist: 'España',
      thumb: '',
      radioTags: ['pop'],
    );

    expect(radioTopicFor(news), RadioTopic.news);
    expect(radioTopicFor(music), RadioTopic.music);
  });

  test('does not assign unrelated talk radio to music', () {
    final station = Track(
      id: 'radio:talk',
      title: 'Radio Deportes',
      artist: 'España',
      thumb: '',
      radioTags: ['talk', 'sports'],
    );

    expect(radioTopicFor(station), RadioTopic.news);
  });
}
