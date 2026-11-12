import 'package:flutter_test/flutter_test.dart';
import 'package:jaiplay/lyrics.dart';

void main() {
  test('parses LRC timestamps and applies the file offset', () {
    final lines = parseSyncedLyrics(
      '[offset:-500]\n[00:01.20][00:02.30]First line\n[00:04.00]Second line',
    );

    expect(lines, hasLength(3));
    expect(lines[0].at, const Duration(milliseconds: 700));
    expect(lines[1].at, const Duration(milliseconds: 1800));
    expect(lines[2].at, const Duration(milliseconds: 3500));
    expect(lines.map((line) => line.text), [
      'First line',
      'First line',
      'Second line',
    ]);
  });

  test('clamps negative offset results and parses enhanced LRC timestamps', () {
    final lines = parseSyncedLyrics(
      '[offset:-2000]\n<00:00.80>Enhanced lyric line',
    );

    expect(lines, hasLength(1));
    expect(lines.single.at, Duration.zero);
    expect(lines.single.text, 'Enhanced lyric line');
  });
}
