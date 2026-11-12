import 'dart:convert';
import 'dart:io';
import 'dart:typed_data';

Future<void> writeAudioTags(
  File file, {
  required String title,
  required String artist,
  String? album,
}) async {
  final bytes = await file.readAsBytes();
  final extension = file.path.split('.').last.toLowerCase();
  final tagged = switch (extension) {
    'm4a' => _tagMp4(bytes, title, artist, album),
    'webm' => _tagWebm(bytes, title, artist, album),
    _ => throw FormatException('Formato de audio no compatible: $extension'),
  };
  await file.writeAsBytes(tagged, flush: true);
}

Uint8List _tagMp4(Uint8List bytes, String title, String artist, String? album) {
  final topLevel = _atoms(bytes, 0, bytes.length);
  final moov = topLevel.where((atom) => atom.type == 'moov').firstOrNull;
  if (moov == null) throw const FormatException('El archivo no contiene moov.');

  final originalChildren = _atoms(bytes, moov.start + moov.header, moov.end);
  final udta = _atom(
    'udta',
    _atom(
      'meta',
      Uint8List.fromList([
        0,
        0,
        0,
        0,
        ..._atom(
          'hdlr',
          Uint8List.fromList([
            0,
            0,
            0,
            0,
            ..._asciiBytes('mdir'),
            ...List<int>.filled(12, 0),
            0,
          ]),
        ),
        ..._atom('ilst', _mp4Items(title, artist, album)),
      ]),
    ),
  );

  final delta = udta.length;
  final children = <Uint8List>[
    for (final child in originalChildren)
      _adjustChunkOffsets(
        Uint8List.fromList(bytes.sublist(child.start, child.end)),
        child.type,
        moov.end,
        delta,
      ),
    udta,
  ];
  final newMoov = _atom('moov', _join(children));
  final out = BytesBuilder(copy: false)
    ..add(bytes.sublist(0, moov.start))
    ..add(newMoov)
    ..add(bytes.sublist(moov.end));
  return out.takeBytes();
}

Uint8List _mp4Items(String title, String artist, String? album) {
  final items = BytesBuilder(copy: false);
  for (final entry in [
    (type: [0xa9, 0x6e, 0x61, 0x6d], value: title),
    (type: [0xa9, 0x41, 0x52, 0x54], value: artist),
    if (album != null && album.trim().isNotEmpty)
      (type: [0xa9, 0x61, 0x6c, 0x62], value: album),
  ]) {
    final value = Uint8List.fromList(utf8.encode(entry.value));
    final data = _atom(
      'data',
      Uint8List.fromList([0, 0, 0, 1, 0, 0, 0, 0, ...value]),
    );
    items.add(_atomBytes(entry.type, data));
  }
  return items.takeBytes();
}

Uint8List _adjustChunkOffsets(
  Uint8List atomBytes,
  String type,
  int oldMoovEnd,
  int delta,
) {
  if (type == 'stco' || type == 'co64') {
    final header = _atomAt(atomBytes, 0, atomBytes.length);
    final countOffset = header.header + 4;
    if (countOffset + 4 > atomBytes.length) {
      throw const FormatException('Tabla de offsets inválida.');
    }
    final data = ByteData.sublistView(atomBytes);
    final count = data.getUint32(countOffset, Endian.big);
    final stride = type == 'stco' ? 4 : 8;
    final offsetsStart = countOffset + 4;
    if (offsetsStart + count * stride > atomBytes.length) {
      throw const FormatException('Tabla de offsets incompleta.');
    }
    for (var i = 0; i < count; i++) {
      final offset = offsetsStart + i * stride;
      final value = stride == 4
          ? data.getUint32(offset, Endian.big)
          : data.getUint64(offset, Endian.big);
      if (value >= oldMoovEnd) {
        final shifted = value + delta;
        if (stride == 4 && shifted > 0xffffffff) {
          throw const FormatException('Offset MP4 fuera de rango.');
        }
        if (stride == 4) {
          data.setUint32(offset, shifted, Endian.big);
        } else {
          data.setUint64(offset, shifted, Endian.big);
        }
      }
    }
    return atomBytes;
  }

  if (!_mp4Containers.contains(type)) return atomBytes;
  final atom = _atomAt(atomBytes, 0, atomBytes.length);
  final childStart = atom.header + (type == 'meta' ? 4 : 0);
  final children = _atoms(atomBytes, childStart, atomBytes.length);
  for (final child in children) {
    final adjusted = _adjustChunkOffsets(
      Uint8List.fromList(atomBytes.sublist(child.start, child.end)),
      child.type,
      oldMoovEnd,
      delta,
    );
    atomBytes.setRange(child.start, child.end, adjusted);
  }
  return atomBytes;
}

const _mp4Containers = {
  'moov',
  'trak',
  'mdia',
  'minf',
  'stbl',
  'edts',
  'dinf',
  'udta',
  'meta',
};

Uint8List _tagWebm(
    Uint8List bytes, String title, String artist, String? album) {
  final topLevel = _ebmlElements(bytes, 0, bytes.length);
  final segment =
      topLevel.where((element) => element.id == 0x18538067).firstOrNull;
  if (segment == null) {
    throw const FormatException('El archivo no contiene un segmento WebM.');
  }

  final simpleTags = <Uint8List>[
    _webmSimpleTag('TITLE', title),
    _webmSimpleTag('ARTIST', artist),
    if (album != null && album.trim().isNotEmpty)
      _webmSimpleTag('ALBUM', album),
  ];
  final tag = _webmElement(0x7373, _join(simpleTags));
  final tags = _webmElement(0x1254c367, tag);
  final payloadEnd = segment.start + segment.header + segment.size;
  if (payloadEnd != bytes.length) {
    throw const FormatException(
        'No se puede actualizar un WebM con datos finales.');
  }

  final segmentSize = _readVint(bytes, segment.start + segment.idWidth);
  final payloadStart = segment.start + segment.header;
  final updatedSize = _encodeVint(segment.size + tags.length);
  final sizeStart = segment.start + segment.idWidth;
  if (segmentSize.unknown) {
    return Uint8List.fromList([
      ...bytes.sublist(0, sizeStart),
      ...List<int>.filled(segment.sizeWidth, 0xff),
      ...bytes.sublist(sizeStart + segment.sizeWidth, payloadEnd),
      ...tags,
      ...bytes.sublist(payloadEnd),
    ]);
  }
  return (BytesBuilder(copy: false)
        ..add(bytes.sublist(0, sizeStart))
        ..add(updatedSize)
        ..add(bytes.sublist(
            sizeStart + segment.sizeWidth, payloadStart + segment.size))
        ..add(tags)
        ..add(bytes.sublist(payloadEnd)))
      .takeBytes();
}

Uint8List _webmSimpleTag(String name, String value) {
  final children = [
    _webmElement(0x45a3, Uint8List.fromList(utf8.encode(name))),
    _webmElement(0x4487, Uint8List.fromList(utf8.encode(value))),
  ];
  return _webmElement(0x67c8, _join(children));
}

Uint8List _webmElement(int id, Uint8List payload) {
  final idBytes = <int>[];
  var shift = 0;
  do {
    idBytes.insert(0, (id >> shift) & 0xff);
    shift += 8;
  } while ((id >> shift) > 0);
  return Uint8List.fromList(
      [...idBytes, ..._encodeVint(payload.length), ...payload]);
}

Uint8List _encodeVint(int value) {
  for (var width = 1; width <= 8; width++) {
    final maxValue = (1 << (7 * width)) - 1;
    if (value < maxValue) {
      final out = Uint8List(width);
      var remaining = value;
      for (var i = width - 1; i >= 0; i--) {
        out[i] = remaining & 0xff;
        remaining >>= 8;
      }
      out[0] |= 1 << (8 - width);
      return out;
    }
  }
  throw const FormatException('Tamaño EBML fuera de rango.');
}

List<_EbmlElement> _ebmlElements(Uint8List bytes, int start, int end) {
  final elements = <_EbmlElement>[];
  var pos = start;
  while (pos < end) {
    final idWidth = _vintWidth(bytes[pos]);
    final id = _readId(bytes, pos, idWidth);
    final sizeStart = pos + idWidth;
    final size = _readVint(bytes, sizeStart);
    final header = idWidth + size.width;
    final elementSize = size.unknown ? end - pos - header : size.value;
    if (elementSize < 0 || pos + header + elementSize > end) {
      throw const FormatException('Elemento EBML inválido.');
    }
    elements.add(_EbmlElement(
      id,
      pos,
      elementSize,
      header,
      idWidth,
      size.width,
    ));
    pos += header + elementSize;
    if (size.unknown) break;
  }
  return elements;
}

int _readId(Uint8List bytes, int offset, int width) {
  var id = 0;
  for (var i = 0; i < width; i++) {
    id = (id << 8) | bytes[offset + i];
  }
  return id;
}

_Vint _readVint(Uint8List bytes, int offset) {
  final first = bytes[offset];
  final width = _vintWidth(first);
  final marker = 1 << (8 - width);
  var value = first & (marker - 1);
  var unknown = value == marker - 1;
  for (var i = 1; i < width; i++) {
    final byte = bytes[offset + i];
    value = (value << 8) | byte;
    unknown = unknown && byte == 0xff;
  }
  return _Vint(value, width, unknown);
}

int _vintWidth(int first) {
  for (var width = 1; width <= 8; width++) {
    if ((first & (1 << (8 - width))) != 0) return width;
  }
  throw const FormatException('VINT EBML inválido.');
}

class _Vint {
  final int value;
  final int width;
  final bool unknown;
  const _Vint(this.value, this.width, this.unknown);
}

class _EbmlElement {
  final int id;
  final int start;
  final int size;
  final int header;
  final int idWidth;
  final int sizeWidth;
  const _EbmlElement(this.id, this.start, this.size, this.header, this.idWidth,
      this.sizeWidth);
}

Uint8List _atom(String type, Uint8List payload) =>
    _atomBytes(_asciiBytes(type), payload);

Uint8List _atomBytes(List<int> type, Uint8List payload) {
  if (payload.length + 8 > 0xffffffff) {
    throw const FormatException('Átomo MP4 demasiado grande.');
  }
  final out = Uint8List(payload.length + 8);
  final data = ByteData.sublistView(out);
  data.setUint32(0, out.length, Endian.big);
  out.setRange(4, 8, type);
  out.setRange(8, out.length, payload);
  return out;
}

List<_Mp4Atom> _atoms(Uint8List bytes, int start, int end) {
  final result = <_Mp4Atom>[];
  var pos = start;
  while (pos < end) {
    final atom = _atomAt(bytes, pos, end);
    result.add(atom);
    pos = atom.end;
  }
  return result;
}

_Mp4Atom _atomAt(Uint8List bytes, int start, int end) {
  if (start + 8 > end) throw const FormatException('Átomo MP4 incompleto.');
  final data = ByteData.sublistView(bytes);
  final shortSize = data.getUint32(start, Endian.big);
  final type = latin1.decode(bytes.sublist(start + 4, start + 8));
  final header = shortSize == 1 ? 16 : 8;
  final size =
      shortSize == 1 ? data.getUint64(start + 8, Endian.big) : shortSize;
  final actualSize = shortSize == 0 ? end - start : size;
  if (actualSize < header || start + actualSize > end) {
    throw const FormatException('Tamaño de átomo MP4 inválido.');
  }
  return _Mp4Atom(type, start, start + actualSize, header);
}

class _Mp4Atom {
  final String type;
  final int start;
  final int end;
  final int header;
  const _Mp4Atom(this.type, this.start, this.end, this.header);
}

Uint8List _join(Iterable<Uint8List> chunks) {
  final builder = BytesBuilder(copy: false);
  for (final chunk in chunks) {
    builder.add(chunk);
  }
  return builder.takeBytes();
}

List<int> _asciiBytes(String value) => value.codeUnits;
