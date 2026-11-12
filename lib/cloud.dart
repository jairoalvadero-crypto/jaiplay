import 'dart:async';
import 'dart:convert';

import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;
import 'package:shared_preferences/shared_preferences.dart';

import 'services.dart';

const _supaUrl = 'https://pisyrxagkphhnzybbsgo.supabase.co';
const _supaKey = 'sb_publishable_LhoWSufiOZ4ZeLqbJNtRmQ_ttAa9MJC';

final cloud = Cloud();

class Cloud extends ChangeNotifier {
  String? _access;
  String? _refresh;
  String? userId;
  String? email;
  String? displayName;
  int _expiresAt = 0;
  bool dirty = false;
  bool busy = false;
  String status = '';
  DateTime? lastSync;
  Timer? _timer;
  SharedPreferences? _sp;

  bool get loggedIn => _refresh != null && userId != null;

  Map<String, String> _h([bool auth = false]) => {
        'apikey': _supaKey,
        'Content-Type': 'application/json',
        if (auth && _access != null) 'Authorization': 'Bearer $_access',
      };

  Future<http.Response> _auth(String path, Map<String, dynamic> body) => http
      .post(Uri.parse('$_supaUrl/auth/v1/$path'),
          headers: _h(), body: jsonEncode(body))
      .timeout(const Duration(seconds: 15));

  String _err(http.Response r) {
    try {
      final j = jsonDecode(utf8.decode(r.bodyBytes)) as Map<String, dynamic>;
      final code = '${j['error_code'] ?? j['code'] ?? ''}';
      final msg =
          '${j['msg'] ?? j['message'] ?? j['error_description'] ?? j['error'] ?? ''}';
      switch (code) {
        case 'invalid_credentials':
          return 'Correo o contraseña incorrectos.';
        case 'user_already_exists':
        case 'email_exists':
          return 'Ese correo ya tiene una cuenta. Inicia sesión.';
        case 'weak_password':
          return 'La contraseña es demasiado débil (mínimo 6 caracteres).';
        case 'email_not_confirmed':
          return 'Falta confirmar el correo.';
        case 'over_email_send_rate_limit':
        case 'over_request_rate_limit':
          return 'Demasiados intentos. Espera un poco.';
        case 'signup_disabled':
          return 'El registro está desactivado en Supabase.';
        case 'email_address_invalid':
          return 'Ese correo no es válido.';
      }
      return msg.isNotEmpty ? msg : 'Error ${r.statusCode}';
    } catch (_) {
      return 'Error ${r.statusCode}';
    }
  }

  bool _takeSession(Map<String, dynamic> j) {
    final a = j['access_token'] as String?;
    final r = j['refresh_token'] as String?;
    final u = j['user'] as Map?;
    if (a == null || r == null || u == null) return false;
    _access = a;
    _refresh = r;
    userId = u['id'] as String?;
    email = (u['email'] as String?) ?? email;
    final metadata = u['user_metadata'];
    if (metadata is Map) {
      final name =
          metadata['full_name'] ?? metadata['name'] ?? metadata['display_name'];
      if (name is String && name.trim().isNotEmpty) {
        displayName = name.trim();
      }
    }
    displayName ??= _nameFromEmail(email);
    _expiresAt = (j['expires_at'] as num?)?.toInt() ??
        (DateTime.now().millisecondsSinceEpoch ~/ 1000 +
            ((j['expires_in'] as num?)?.toInt() ?? 3600));
    _sp?.setString(
        'cloud_session',
        jsonEncode({
          'a': _access,
          'r': _refresh,
          'u': userId,
          'e': email,
          'n': displayName,
          'x': _expiresAt,
        }));
    return true;
  }

  void _clear() {
    _access = null;
    _refresh = null;
    userId = null;
    email = null;
    displayName = null;
    _expiresAt = 0;
    status = '';
    _sp?.remove('cloud_session');
    notifyListeners();
  }

  Future<void> load() async {
    _sp = await SharedPreferences.getInstance();
    dirty = _sp!.getBool('cloud_dirty') ?? false;
    final s = _sp!.getString('cloud_session');
    if (s != null) {
      try {
        final j = jsonDecode(s) as Map<String, dynamic>;
        _access = j['a'] as String?;
        _refresh = j['r'] as String?;
        userId = j['u'] as String?;
        email = j['e'] as String?;
        displayName = j['n'] as String? ?? _nameFromEmail(email);
        _expiresAt = (j['x'] as num?)?.toInt() ?? 0;
      } catch (_) {}
    }
    notifyListeners();
  }

  String? _nameFromEmail(String? value) {
    final localPart = value?.split('@').first;
    if (localPart == null || localPart.trim().isEmpty) return null;
    final words = localPart
        .replaceAll(RegExp(r'[._+-]+'), ' ')
        .trim()
        .split(RegExp(r'\s+'));
    if (words.isEmpty) return null;
    return words
        .map((word) => word.isEmpty
            ? word
            : '${word[0].toUpperCase()}${word.substring(1)}')
        .join(' ');
  }

  Future<String?> signUp(String mail, String pass) =>
      _enter('signup', mail, pass);

  Future<String?> signIn(String mail, String pass) =>
      _enter('token?grant_type=password', mail, pass);

  Future<String?> _enter(String path, String mail, String pass) async {
    busy = true;
    notifyListeners();
    try {
      final r = await _auth(path, {'email': mail.trim(), 'password': pass});
      if (r.statusCode >= 400) return _err(r);
      final j = jsonDecode(utf8.decode(r.bodyBytes)) as Map<String, dynamic>;
      if (!_takeSession(j)) {
        return 'Cuenta creada, pero falta confirmar el correo. Revisa tu bandeja.';
      }
      await syncNow(merge: true);
      return null;
    } catch (_) {
      return 'No se pudo conectar. ¿Hay internet?';
    } finally {
      busy = false;
      notifyListeners();
    }
  }

  Future<void> signOut() async {
    _timer?.cancel();
    if (dirty) {
      try {
        await _push();
      } catch (_) {}
    }
    try {
      await _authed((h) => http.post(
            Uri.parse('$_supaUrl/auth/v1/logout'),
            headers: h,
          ));
    } catch (_) {}
    _clear();
  }

  Future<void> _refreshSession() async {
    final r = await _auth(
        'token?grant_type=refresh_token', {'refresh_token': _refresh});
    if (r.statusCode >= 400) {
      if (r.statusCode == 400 || r.statusCode == 401) {
        _clear();
        throw Exception('La sesión ha caducado. Inicia sesión otra vez.');
      }
      throw Exception('HTTP ${r.statusCode} al renovar la sesión');
    }
    _takeSession(jsonDecode(utf8.decode(r.bodyBytes)) as Map<String, dynamic>);
  }

  Future<http.Response> _authed(
      Future<http.Response> Function(Map<String, String> h) send) async {
    if (DateTime.now().millisecondsSinceEpoch ~/ 1000 > _expiresAt - 60) {
      await _refreshSession();
    }
    var r = await send(_h(true)).timeout(const Duration(seconds: 15));
    if (r.statusCode == 401) {
      await _refreshSession();
      r = await send(_h(true)).timeout(const Duration(seconds: 15));
    }
    return r;
  }

  Future<Map<String, dynamic>?> _fetch() async {
    final r = await _authed((h) => http.get(
          Uri.parse(
              '$_supaUrl/rest/v1/user_data?select=data&user_id=eq.$userId'),
          headers: h,
        ));
    if (r.statusCode != 200) {
      throw Exception('HTTP ${r.statusCode} ${utf8.decode(r.bodyBytes)}');
    }
    final list = jsonDecode(utf8.decode(r.bodyBytes)) as List;
    if (list.isEmpty) return null;
    return Map<String, dynamic>.from((list.first as Map)['data'] as Map);
  }

  Future<void> _push() async {
    final body = jsonEncode({
      'user_id': userId,
      'data': store.snapshot(),
      'updated_at': DateTime.now().toUtc().toIso8601String(),
    });
    final r = await _authed((h) => http.post(
          Uri.parse('$_supaUrl/rest/v1/user_data'),
          headers: {
            ...h,
            'Prefer': 'resolution=merge-duplicates,return=minimal',
          },
          body: body,
        ));
    if (r.statusCode >= 300) {
      throw Exception('HTTP ${r.statusCode} ${utf8.decode(r.bodyBytes)}');
    }
    dirty = false;
    _sp?.setBool('cloud_dirty', false);
  }

  String _short(Object e) {
    final s = '$e'.replaceFirst('Exception: ', '');
    return s.length > 140 ? s.substring(0, 140) : s;
  }

  Future<void> syncNow({bool merge = false}) async {
    if (!loggedIn) return;
    try {
      status = 'Sincronizando…';
      notifyListeners();
      final remote = await _fetch();
      if (remote == null) {
        await _push();
      } else if (merge || dirty) {
        store.mergeRemote(remote);
        await _push();
      } else {
        store.applyRemote(remote);
      }
      lastSync = DateTime.now();
      status = 'Sincronizado';
    } catch (e) {
      status = 'Error al sincronizar: ${_short(e)}';
    }
    notifyListeners();
  }

  /// Llamado por Store cada vez que cambia algo.
  void markChanged() {
    if (!loggedIn) return;
    dirty = true;
    _sp?.setBool('cloud_dirty', true);
    _timer?.cancel();
    _timer = Timer(const Duration(seconds: 2), () async {
      try {
        await _push();
        lastSync = DateTime.now();
        status = 'Sincronizado';
      } catch (e) {
        status = 'Cambios pendientes: ${_short(e)}';
      }
      notifyListeners();
    });
  }
}
