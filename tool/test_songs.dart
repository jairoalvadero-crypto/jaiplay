import 'package:http/http.dart' as http;
import 'package:youtube_explode_dart/youtube_explode_dart.dart';

const ua = 'com.google.android.youtube/20.10.38 (Linux; U; Android 11) gzip';

const sdkless = YoutubeApiClient({
  'context': {
    'client': {
      'clientName': 'ANDROID',
      'clientVersion': '20.10.38',
      'userAgent': 'com.google.android.youtube/20.10.38 (Linux; U; Android 11) gzip',
      'hl': 'en',
      'timeZone': 'UTC',
      'utcOffsetMinutes': 0,
    },
  },
}, 'https://www.youtube.com/youtubei/v1/player?prettyPrint=false');

final clients = <String, YoutubeApiClient>{
  'sdkless': sdkless,
  'androidVr': YoutubeApiClient.androidVr,
  'tv': YoutubeApiClient.tv,
  'ios': YoutubeApiClient.ios,
  'safari': YoutubeApiClient.safari,
};

const queries = [
  'bad bunny dakiti', 'shakira bzrp session', 'rosalia despecha',
  'coldplay yellow', 'queen bohemian rhapsody', 'daft punk get lucky',
  'the weeknd blinding lights', 'adele hello', 'ed sheeran shape of you',
  'rauw alejandro cap 8', 'quevedo bzrp 52', 'c tangana tuyo',
  'estopa como camaron', 'extremoduro so payaso', 'melendi tu jardinero',
  'alejandro sanz corazon partio', 'karol g tqg', 'feid ferxxo 100',
  'duki she dont give a fo', 'nathy peluso buenos aires', 'metallica one',
  'ac dc back in black', 'nirvana smells like teen spirit',
  'michael jackson billie jean', 'rihanna diamonds', 'dua lipa levitating',
  'taylor swift anti-hero', 'mora memorias', 'anuel aa', 'bizarrap quevedo',
];

Future<int> probe(Uri u, int from, int len) async {
  try {
    final r = await http
        .get(u, headers: {'User-Agent': ua, 'Range': 'bytes=$from-${from + len - 1}'})
        .timeout(const Duration(seconds: 20));
    return r.statusCode;
  } catch (_) {
    return -1;
  }
}

Future<void> main() async {
  final yt = YoutubeExplode();
  final ok = <String, int>{for (final k in clients.keys) k: 0};
  var songs = 0;
  final noClient = <String>[];

  for (final q in queries) {
    try {
      final res = await yt.search.search(q);
      Video? v;
      for (final x in res) {
        final d = x.duration?.inSeconds ?? 0;
        if (d >= 60 && d <= 600) {
          v = x;
          break;
        }
      }
      if (v == null) continue;
      songs++;
      final line = StringBuffer('${v.title.length > 40 ? v.title.substring(0, 40) : v.title} | ');
      var any = false;
      for (final e in clients.entries) {
        String result;
        try {
          final m = await yt.videos.streamsClient.getManifest(v.id, ytClients: [e.value]);
          final audio = m.audioOnly.toList()
            ..sort((a, b) {
              final am = a.container.name == 'mp4' ? 1 : 0;
              final bm = b.container.name == 'mp4' ? 1 : 0;
              if (am != bm) return bm - am;
              return b.bitrate.bitsPerSecond.compareTo(a.bitrate.bitsPerSecond);
            });
          result = 'sin audio';
          for (final s in audio.take(2)) {
            final total = s.size.totalBytes;
            final points = <int>{
              0,
              if (total > 1700000) 1048576,
              if (total > 1200000) total - 524288,
            };
            var good = true;
            var why = '';
            for (final at in points) {
              final left = total - at;
              final len = left < 524288 ? left : 524288;
              final c = await probe(s.url, at, len);
              if (c != 200 && c != 206) {
                good = false;
                why = '${s.tag}@$at=$c';
                break;
              }
            }
            if (good) {
              result = 'OK${s.tag}';
              break;
            } else {
              result = why;
            }
          }
        } catch (err) {
          result = 'ERR';
        }
        if (result.startsWith('OK')) {
          ok[e.key] = ok[e.key]! + 1;
          any = true;
        }
        line.write('${e.key}:$result  ');
      }
      if (!any) noClient.add(v.title);
      print(line);
    } catch (err) {
      print('$q -> fallo de busqueda');
    }
  }

  print('\n===== RESUMEN ($songs canciones) =====');
  for (final e in ok.entries) {
    print('${e.key}: ${e.value}/$songs');
  }
  print('Sin ningun cliente valido: ${noClient.length}');
  for (final t in noClient) {
    print('  - $t');
  }
  yt.close();
}
