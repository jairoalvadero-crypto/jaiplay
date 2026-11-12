import 'dart:convert';
import 'dart:io';
import 'dart:typed_data';

import 'package:flutter_test/flutter_test.dart';
import 'package:jaiplay/audio_tags.dart';

void main() {
  late Directory directory;

  setUp(() async {
    directory = await Directory.systemTemp.createTemp('jaiplay-audio-tags');
  });

  tearDown(() async {
    await directory.delete(recursive: true);
  });

  test('writes title, artist and album metadata to an M4A file', () async {
    final file = File('${directory.path}/track.m4a');
    final original = _mp4Fixture();
    final originalChunkOffset = _chunkOffset(original);
    await file.writeAsBytes(original);

    await writeAudioTags(
      file,
      title: 'Canción de prueba',
      artist: 'Artista',
      album: 'Álbum',
    );

    final taggedBytes = await file.readAsBytes();
    final output = utf8.decode(taggedBytes, allowMalformed: true);
    expect(output, contains('Canción de prueba'));
    expect(output, contains('Artista'));
    expect(output, contains('Álbum'));
    expect(output, contains('mdat'));
    expect(
      _chunkOffset(taggedBytes),
      originalChunkOffset + taggedBytes.length - original.length,
    );
  });

  test('writes title, artist and album metadata to a WebM file', () async {
    final file = File('${directory.path}/track.webm');
    await file.writeAsBytes(_webmFixture());

    await writeAudioTags(
      file,
      title: 'Canción de prueba',
      artist: 'Artista',
      album: 'Álbum',
    );

    final output = utf8.decode(await file.readAsBytes(), allowMalformed: true);
    expect(output, contains('TITLE'));
    expect(output, contains('ARTIST'));
    expect(output, contains('ALBUM'));
    expect(output, contains('Canción de prueba'));
    expect(output, contains('Artista'));
    expect(output, contains('Álbum'));
    expect(output, contains('CLUSTER'));
  });
}

Uint8List _mp4Fixture() {
  final ftyp = _atom('ftyp', Uint8List.fromList(ascii('M4A ')));
  final offsets = ByteData(12)
    ..setUint32(0, 0, Endian.big)
    ..setUint32(4, 1, Endian.big)
    ..setUint32(8, 0, Endian.big);
  final stco = _atom('stco', offsets.buffer.asUint8List());
  final stbl = _atom('stbl', stco);
  final minf = _atom('minf', stbl);
  final trak = _atom('trak', minf);
  final moov = _atom('moov', trak);
  final chunkOffset = ftyp.length + moov.length + 8;
  offsets.setUint32(8, chunkOffset, Endian.big);
  final updatedStco = _atom('stco', offsets.buffer.asUint8List());
  final updatedMoov =
      _atom('moov', _atom('trak', _atom('minf', _atom('stbl', updatedStco))));
  return Uint8List.fromList([
    ...ftyp,
    ...updatedMoov,
    ..._atom('mdat', Uint8List.fromList(ascii('audio'))),
  ]);
}

Uint8List _webmFixture() {
  return Uint8List.fromList([
    ..._ebmlElement([0x1a, 0x45, 0xdf, 0xa3], []),
    ..._ebmlElement([
      0x18,
      0x53,
      0x80,
      0x67
    ], [
      ..._ebmlElement(
        [0x1f, 0x43, 0xb6, 0x75],
        ascii('CLUSTER'),
      ),
    ]),
  ]);
}

Uint8List _atom(String type, Uint8List payload) {
  final output = Uint8List(payload.length + 8);
  ByteData.sublistView(output).setUint32(0, output.length, Endian.big);
  output.setRange(4, 8, ascii(type));
  output.setRange(8, output.length, payload);
  return output;
}

Uint8List _ebmlElement(List<int> id, List<int> payload) => Uint8List.fromList([
      ...id,
      0x80 | payload.length,
      ...payload,
    ]);

List<int> ascii(String value) => value.codeUnits;

int _chunkOffset(Uint8List bytes) {
  final type = ascii('stco');
  final start = _indexOf(bytes, type) - 4;
  return ByteData.sublistView(bytes).getUint32(start + 16, Endian.big);
}

int _indexOf(Uint8List bytes, List<int> needle) {
  for (var i = 0; i <= bytes.length - needle.length; i++) {
    var matches = true;
    for (var j = 0; j < needle.length; j++) {
      if (bytes[i + j] != needle[j]) {
        matches = false;
        break;
      }
    }
    if (matches) return i;
  }
  throw StateError('No se encontró la secuencia binaria.');
}
