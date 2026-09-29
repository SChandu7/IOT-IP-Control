import 'dart:async';
import 'dart:convert';

import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;

enum LinkState { offline, connecting, online, failed }

class LogLine {
  final DateTime time;
  final String url;
  final int status;
  final int ms;
  final String note;
  LogLine(this.url, this.status, this.ms, this.note) : time = DateTime.now();
  bool get ok => status >= 200 && status < 300;
}

/// Talks to the board. Every control goes through this one place so the
/// device never gets flooded: repeated values are coalesced to the newest one.
class EspClient extends ChangeNotifier {
  String baseUrl = 'http://192.168.4.1';
  int timeoutMs = 1200;
  int minIntervalMs = 70; // rate limit per control
  bool keepAlive = true;
  bool logging = true;

  LinkState state = LinkState.offline;
  int lastLatencyMs = 0;
  String lastError = '';
  final List<LogLine> log = [];

  final http.Client _http = http.Client();
  final Map<String, DateTime> _lastSent = {};
  final Map<String, String> _queued = {};
  final Map<String, Timer> _timers = {};
  int _inFlight = 0;

  int get inFlight => _inFlight;

  /// Replaces {v} {x} {y} {a} {s} inside an endpoint or body.
  static String fill(String template, Map<String, String> vars) {
    var out = template;
    vars.forEach((k, v) => out = out.replaceAll('{$k}', v));
    return out;
  }

  Uri buildUri(String path) {
    var p = path.trim();
    if (p.startsWith('http')) return Uri.parse(p);
    if (!p.startsWith('/')) p = '/$p';
    var b = baseUrl.trim();
    if (b.isEmpty) b = 'http://192.168.4.1';
    if (!b.startsWith('http')) b = 'http://$b';
    b = b.replaceAll(RegExp(r'/+$'), '');
    return Uri.parse('$b$p');
  }

  /// Fire and forget. [key] groups requests so a slider dragged fast
  /// only sends the latest value.
  void send(
    String path, {
    String method = 'GET',
    String body = '',
    String? key,
  }) {
    if (path.trim().isEmpty) return;
    if (key == null) {
      _dispatch(path, method, body);
      return;
    }
    final last = _lastSent[key];
    final now = DateTime.now();
    if (last == null || now.difference(last).inMilliseconds >= minIntervalMs) {
      _lastSent[key] = now;
      _dispatch(path, method, body);
      return;
    }
    _queued[key] = path;
    _timers[key] ??= Timer(Duration(milliseconds: minIntervalMs), () {
      _timers.remove(key);
      final queued = _queued.remove(key);
      if (queued != null) {
        _lastSent[key] = DateTime.now();
        _dispatch(queued, method, body);
      }
    });
  }

  Future<void> _dispatch(String path, String method, String body) async {
    final uri = buildUri(path);
    final sw = Stopwatch()..start();
    _inFlight++;
    try {
      final res = method.toUpperCase() == 'POST'
          ? await _http
              .post(uri, body: body.isEmpty ? null : body)
              .timeout(Duration(milliseconds: timeoutMs))
          : await _http.get(uri).timeout(Duration(milliseconds: timeoutMs));
      sw.stop();
      lastLatencyMs = sw.elapsedMilliseconds;
      state = (res.statusCode >= 200 && res.statusCode < 300)
          ? LinkState.online
          : LinkState.failed;
      lastError = state == LinkState.failed ? 'HTTP ${res.statusCode}' : '';
      _push(LogLine(uri.toString(), res.statusCode, lastLatencyMs, ''));
    } catch (e) {
      sw.stop();
      state = LinkState.failed;
      lastError = _short(e);
      _push(LogLine(uri.toString(), 0, sw.elapsedMilliseconds, _short(e)));
    } finally {
      _inFlight--;
      notifyListeners();
    }
  }

  /// Used by gauges and the connection test.
  Future<Map<String, dynamic>?> fetchJson(String path) async {
    final uri = buildUri(path);
    final sw = Stopwatch()..start();
    try {
      final res =
          await _http.get(uri).timeout(Duration(milliseconds: timeoutMs));
      sw.stop();
      lastLatencyMs = sw.elapsedMilliseconds;
      state = LinkState.online;
      lastError = '';
      notifyListeners();
      final decoded = jsonDecode(res.body);
      if (decoded is Map) return Map<String, dynamic>.from(decoded);
      return {'value': decoded};
    } catch (e) {
      state = LinkState.failed;
      lastError = _short(e);
      notifyListeners();
      return null;
    }
  }

  Future<bool> testConnection(String path) async {
    state = LinkState.connecting;
    notifyListeners();
    final uri = buildUri(path.isEmpty ? '/' : path);
    final sw = Stopwatch()..start();
    try {
      final res =
          await _http.get(uri).timeout(Duration(milliseconds: timeoutMs));
      sw.stop();
      lastLatencyMs = sw.elapsedMilliseconds;
      state = LinkState.online;
      lastError = '';
      _push(LogLine(uri.toString(), res.statusCode, lastLatencyMs, 'test'));
      notifyListeners();
      return true;
    } catch (e) {
      sw.stop();
      state = LinkState.failed;
      lastError = _short(e);
      _push(LogLine(uri.toString(), 0, sw.elapsedMilliseconds, _short(e)));
      notifyListeners();
      return false;
    }
  }

  void _push(LogLine l) {
    if (!logging) return;
    log.insert(0, l);
    if (log.length > 200) log.removeLast();
  }

  void clearLog() {
    log.clear();
    notifyListeners();
  }

  String _short(Object e) {
    final s = e.toString();
    if (s.contains('TimeoutException')) return 'Timed out';
    if (s.contains('SocketException')) return 'No route to device';
    return s.length > 60 ? '${s.substring(0, 60)}…' : s;
  }

  @override
  void dispose() {
    for (final t in _timers.values) {
      t.cancel();
    }
    _http.close();
    super.dispose();
  }
}
