import 'dart:async';
import 'dart:convert';
import 'dart:io' as io;
import 'dart:math';
import 'dart:typed_data';

import 'package:connectivity_plus/connectivity_plus.dart';
import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;
import 'package:path_provider/path_provider.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'lyrics.dart';
import 'models.dart';
import 'settings.dart';
import 'services.dart';

final downloads = DownloadService();
const _dlChunk = 1024 * 1024;

/// Canciones guardadas en el móvil para oírlas sin internet.
class DownloadService extends ChangeNotifier {
  final _http = http.Client();
  final _connectivity = Connectivity();
  Completer<void> _networkWake = Completer<void>();
  List<ConnectivityResult> _connection = const [ConnectivityResult.none];
  StreamSubscription<List<ConnectivityResult>>? _connectivitySubscription;
  late SharedPreferences _sp;
  String _dir = '';
  List<Track> tracks = [];
  Map<String, String> _files = {};
  final Map<String, double> progress = {};
  final Map<String, String> errors = {};
  final Set<String> paused = {};
  final Map<String, Future<void>> _activeDownloads = {};

  DownloadService() {
    appSettings.addListener(_wakeNetworkWaiters);
  }

  Future<void> load() async {
    _sp = await SharedPreferences.getInstance();
    if (!kIsWeb) {
      final docs = await getApplicationDocumentsDirectory();
      _dir = '${docs.path}/dl';
      await io.Directory(_dir).create(recursive: true);
    }
    _connection = await _connectivity.checkConnectivity();
    _connectivitySubscription ??= _connectivity.onConnectivityChanged.listen(
      (connection) {
        _connection = connection;
        errors.remove('network');
        _wakeNetworkWaiters();
        notifyListeners();
      },
      onError: (Object error) {
        errors['network'] = 'No se pudo comprobar la conexión: $error';
        notifyListeners();
      },
    );
    final raw = _sp.getString('dl_files');
    if (raw != null) {
      _files = (jsonDecode(raw) as Map).map((k, v) => MapEntry('$k', '$v'));
    }
    tracks = (_sp.getStringList('dl_tracks') ?? [])
        .map((s) => Track.fromJson(jsonDecode(s) as Map<String, dynamic>))
        .where((t) => pathFor(t.id) != null)
        .toList();
  }

  String? pathFor(String id) {
    final name = _files[id];
    if (name == null || _dir.isEmpty) return null;
    final p = '$_dir/$name';
    return io.File(p).existsSync() ? p : null;
  }

  bool isDownloaded(String id) => pathFor(id) != null;

  bool get _networkAllowed {
    if (_connection.contains(ConnectivityResult.none)) return false;
    return !appSettings.wifiOnly ||
        _connection.contains(ConnectivityResult.wifi);
  }

  void _wakeNetworkWaiters() {
    final wake = _networkWake;
    _networkWake = Completer<void>();
    if (!wake.isCompleted) wake.complete();
  }

  Future<void> _waitForAllowedNetwork(String id) async {
    while (!_networkAllowed) {
      if (paused.add(id)) notifyListeners();
      final wake = _networkWake.future;
      if (_networkAllowed) continue;
      await wake;
    }
    if (paused.remove(id)) notifyListeners();
  }

  Future<void> _refreshConnection() async {
    _connection = await _connectivity.checkConnectivity();
    errors.remove('network');
    _wakeNetworkWaiters();
  }

  void _save() {
    _sp.setStringList(
        'dl_tracks', tracks.map((t) => jsonEncode(t.toJson())).toList());
    _sp.setString('dl_files', jsonEncode(_files));
  }

  Future<void> download(Track t) async {
    final active = _activeDownloads[t.id];
    if (active != null) {
      await active;
      return;
    }
    if (t.streamUrl != null || isDownloaded(t.id)) return;
    final completed = Completer<void>();
    _activeDownloads[t.id] = completed.future;
    progress[t.id] = 0;
    errors.remove(t.id);
    io.File? tmp;
    try {
      notifyListeners();
      await _waitForAllowedNetwork(t.id);
      final pl = await music.resolve(t.id);
      final total = pl.length;
      if (total <= 0) throw Exception('tamaño desconocido');
      final name = '${t.id}.${pl.type.contains('webm') ? 'webm' : 'm4a'}';
      final file = io.File('$_dir/$name.part');
      tmp = file;
      var sink = file.openWrite();
      try {
        var from = 0;
        while (from < total) {
          await _waitForAllowedNetwork(t.id);
          final to = min(from + _dlChunk, total) - 1;
          final bytes = BytesBuilder(copy: false);
          late http.StreamedResponse res;
          try {
            final req = http.Request('GET', pl.url)
              ..headers.addAll({...pl.headers, 'Range': 'bytes=$from-$to'});
            res = await _http.send(req);
            if (res.statusCode != 200 && res.statusCode != 206) {
              throw Exception('HTTP ${res.statusCode}');
            }
            await for (final chunk in res.stream) {
              bytes.add(chunk);
            }
          } catch (_) {
            await _refreshConnection();
            if (!_networkAllowed) continue;
            rethrow;
          }
          if (!_networkAllowed) continue;
          if (res.statusCode == 200 && from > 0) {
            await sink.close();
            await file.writeAsBytes(const []);
            sink = file.openWrite();
            from = 0;
          }
          sink.add(bytes.takeBytes());
          from = res.statusCode == 200 ? total : to + 1;
          progress[t.id] = from / total;
          notifyListeners();
        }
      } finally {
        await sink.close();
      }
      if (await file.length() < total) throw Exception('descarga incompleta');
      await file.rename('$_dir/$name');
      _files[t.id] = name;
      tracks.removeWhere((x) => x.id == t.id);
      tracks.insert(0, t);
      _save();
      lyricsService.get(t).ignore();
    } catch (e) {
      errors[t.id] = '$e';
      try {
        if (tmp != null && await tmp.exists()) await tmp.delete();
      } catch (_) {}
    } finally {
      paused.remove(t.id);
      progress.remove(t.id);
      _activeDownloads.remove(t.id);
      notifyListeners();
      completed.complete();
    }
  }

  Future<void> remove(String id) async {
    final p = pathFor(id);
    if (p != null) {
      try {
        await io.File(p).delete();
      } catch (_) {}
    }
    _files.remove(id);
    tracks.removeWhere((t) => t.id == id);
    _save();
    notifyListeners();
  }
}
