import 'dart:convert';
import 'dart:ui' show PlatformDispatcher;

import 'package:http/http.dart' as http;

import 'models.dart';

const _hosts = [
  'de1.api.radio-browser.info',
  'de2.api.radio-browser.info',
  'nl1.api.radio-browser.info',
  'at1.api.radio-browser.info',
  'fi1.api.radio-browser.info',
];

final _cache = <String, List<Track>>{};
final _topicCache = <String, Future<List<Track>>>{};
final _spanishFeaturedCache = <String, Future<List<Track>>>{};

enum RadioTopic { news, music }

String radioTopicLabel(RadioTopic topic) =>
    topic == RadioTopic.news ? 'Noticias' : 'Música';

RadioTopic? radioTopicFor(Track station) {
  final text = [
    station.title,
    station.artist,
    ...station.radioTags,
  ].join(' ').toLowerCase();
  if (RegExp(
    r'\b(news|noticias|informaci[oó]n|informativos|talk|actualidad|'
    r'current affairs|radio 5|24 horas|24h)\b',
  ).hasMatch(text)) {
    return RadioTopic.news;
  }
  if (RegExp(
    r'\b(music|m[uú]sica|pop|rock|hits|dance|electronic|electr[oó]nica|'
    r'flamenco|hip.?hop|regga?eton|jazz|classical|cl[aá]sica|indie|'
    r'oldies|soul|funk|radio 3|los ?40|cadena dial|europa fm|kiss fm)\b',
  ).hasMatch(text)) {
    return RadioTopic.music;
  }
  return null;
}

const _spanishFeatured = <(String, RadioTopic)>[
  ('Cadena SER', RadioTopic.news),
  ('COPE', RadioTopic.news),
  ('RNE Radio 1', RadioTopic.news),
  ('Radio 5 Todo Noticias', RadioTopic.news),
  ('Onda Cero', RadioTopic.news),
  ('RAC1', RadioTopic.news),
  ('Catalunya Ràdio', RadioTopic.news),
  ('Canal Sur Radio', RadioTopic.news),
  ('Radio Euskadi', RadioTopic.news),
  ('Radio Galega', RadioTopic.news),
  ('À Punt Ràdio', RadioTopic.news),
  ('LOS40', RadioTopic.music),
  ('Cadena Dial', RadioTopic.music),
  ('Europa FM', RadioTopic.music),
  ('KISS FM', RadioTopic.music),
  ('Rock FM', RadioTopic.music),
  ('LOS40 Classic', RadioTopic.music),
  ('LOS40 Dance', RadioTopic.music),
  ('Radio 3 RNE', RadioTopic.music),
];

const _spanishVerifiedLocalStations = <Track>[
  Track(
    id: 'radio:cope-huelva',
    title: 'COPE Huelva',
    artist: 'Huelva · Noticias',
    thumb: 'https://www.cope.es/favicon/cope/apple-touch-icon-192x192.png',
    radioTags: ['cope', 'news'],
    streamUrl: 'https://wecast09-h-cloud.flumotion.com/copesedes/huelva.mp3',
  ),
];

const radioGenres = <(String, String)>[
  ('Pop', 'pop'),
  ('Rock', 'rock'),
  ('Flamenco', 'flamenco'),
  ('Hip-Hop', 'hip hop'),
  ('Reggaeton', 'reggaeton'),
  ('Electrónica', 'electronic'),
  ('Latina', 'latin'),
  ('Jazz', 'jazz'),
  ('Clásica', 'classical'),
  ('Indie', 'indie'),
];

String localCountryCode() =>
    (PlatformDispatcher.instance.locale.countryCode ?? 'ES').toUpperCase();

String countryName(String code) {
  const m = {
    'ES': 'España',
    'MX': 'México',
    'AR': 'Argentina',
    'CO': 'Colombia',
    'CL': 'Chile',
    'PE': 'Perú',
    'US': 'Estados Unidos',
    'GB': 'Reino Unido',
    'FR': 'Francia',
    'DE': 'Alemania',
    'IT': 'Italia',
    'PT': 'Portugal',
  };
  return m[code] ?? code;
}

/// Busca emisoras en Radio Browser (directorio gratuito) y las convierte en
/// Track con enlace de directo.
Future<List<Track>> fetchStations(Map<String, String> params,
    {String? excludeCountry}) async {
  final key = '$params|${excludeCountry ?? ''}';
  final hit = _cache[key];
  if (hit != null) return hit;
  Object? last;
  for (final host in _hosts) {
    try {
      final r = await http.get(
        Uri.https(host, '/json/stations/search', {
          ...params,
          'hidebroken': 'true',
          'reverse': 'true',
        }),
        headers: const {'User-Agent': 'JaiPlay/1.0'},
      ).timeout(const Duration(seconds: 10));
      if (r.statusCode != 200) {
        last = 'HTTP ${r.statusCode}';
        continue;
      }
      final list = (jsonDecode(utf8.decode(r.bodyBytes)) as List)
          .cast<Map<String, dynamic>>();
      final seen = <String>{};
      final out = <Track>[];
      for (final m in list) {
        final name = '${m['name'] ?? ''}'.trim();
        final resolved = '${m['url_resolved'] ?? ''}'.trim();
        final url = resolved.isNotEmpty ? resolved : '${m['url'] ?? ''}'.trim();
        final cc = '${m['countrycode'] ?? ''}'.toUpperCase();
        if (name.isEmpty || !url.startsWith('http')) continue;
        if (excludeCountry != null && cc == excludeCountry) continue;
        if (!seen.add(name.toLowerCase())) continue;
        final tag = '${m['tags'] ?? ''}'
            .split(',')
            .map((e) => e.trim())
            .firstWhere((e) => e.isNotEmpty, orElse: () => '');
        final tags = '${m['tags'] ?? ''}'
            .split(',')
            .map((e) => e.trim().toLowerCase())
            .where((e) => e.isNotEmpty)
            .toSet()
            .toList();
        final country = '${m['country'] ?? ''}'.trim();
        out.add(Track(
          id: 'radio:${m['stationuuid'] ?? name}',
          title: name,
          artist: [country, tag].where((e) => e.isNotEmpty).join(' • '),
          thumb: '${m['favicon'] ?? ''}'.trim(),
          radioTags: tags,
          streamUrl: url,
        ));
      }
      if (out.isNotEmpty) _cache[key] = out;
      return out;
    } catch (e) {
      last = e;
    }
  }
  throw Exception('$last');
}

Future<List<Track>> searchStations(String query) {
  final normalized = query.trim();
  if (normalized.length < 2) return Future.value(const []);
  return fetchStations({
    'name': normalized,
    'order': 'votes',
    'limit': '60',
  });
}

Future<List<Track>> fetchStationsByTopic({
  required RadioTopic topic,
  String? countryCode,
  String? excludeCountry,
}) async {
  final key = '${topic.name}|${countryCode ?? ''}|${excludeCountry ?? ''}';
  final cached = _topicCache[key];
  if (cached != null) return cached;
  final future = _loadStationsByTopic(
    topic: topic,
    countryCode: countryCode,
    excludeCountry: excludeCountry,
  );
  _topicCache[key] = future;
  try {
    return await future;
  } catch (_) {
    _topicCache.remove(key);
    rethrow;
  }
}

Future<List<Track>> _loadStationsByTopic({
  required RadioTopic topic,
  String? countryCode,
  String? excludeCountry,
}) async {
  final countryParams = <String, String>{
    if (countryCode != null) 'countrycode': countryCode,
    'order': 'votes',
    'limit': '250',
  };
  final bulk =
      await fetchStations(countryParams, excludeCountry: excludeCountry);
  final candidates = <Track>[...bulk];

  if (topic == RadioTopic.news) {
    final newsQueries = await Future.wait([
      for (final tag in ['news', 'noticias', 'talk'])
        fetchStations({
          if (countryCode != null) 'countrycode': countryCode,
          'tag': tag,
          'order': 'votes',
          'limit': '100',
        }, excludeCountry: excludeCountry)
            .catchError((_) => <Track>[]),
    ]);
    candidates.addAll(newsQueries.expand((list) => list));
  }

  if (countryCode == 'ES') {
    final featured = await _spanishFeaturedCache.putIfAbsent(
      'ES',
      () => _loadSpanishFeatured(excludeCountry: excludeCountry),
    );
    candidates.addAll(featured);
    candidates.addAll(_spanishVerifiedLocalStations);
  }

  final selected = <String, Track>{};
  for (final station in candidates) {
    if (radioTopicFor(station) != topic) continue;
    selected.putIfAbsent(station.id, () => station);
  }
  return selected.values.toList();
}

Future<List<Track>> _loadSpanishFeatured({String? excludeCountry}) async {
  final results = await Future.wait([
    for (final (name, _) in _spanishFeatured)
      fetchStations({
        'countrycode': 'ES',
        'name': name,
        'order': 'votes',
        'limit': '3',
      }, excludeCountry: excludeCountry)
          .catchError((_) => <Track>[]),
  ]);
  final found = <String, Track>{};
  for (var i = 0; i < results.length; i++) {
    final expectedName = _spanishFeatured[i].$1.toLowerCase();
    for (final station in results[i]) {
      final name = station.title.toLowerCase();
      if (name.contains(expectedName) ||
          expectedName.contains(name) ||
          (expectedName == 'cope' && name.startsWith('cope '))) {
        final topic = _spanishFeatured[i].$2;
        found.putIfAbsent(
          station.id,
          () => Track(
            id: station.id,
            title: station.title,
            artist: station.artist,
            thumb: station.thumb,
            radioTags: [...station.radioTags, topic.name],
            streamUrl: station.streamUrl,
          ),
        );
      }
    }
  }
  return found.values.toList();
}
