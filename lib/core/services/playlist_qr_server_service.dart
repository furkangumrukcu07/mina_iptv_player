import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:network_info_plus/network_info_plus.dart';

/// **Karekod (QR) ile playlist yükleme — Yöntem 1: Telefon Kumanda.**
///
/// Bu servis kullanıcı "Karekod ile yükle" butonuna bastığında dahili bir
/// hafif HTTP sunucusu açar (`HttpServer.bind(InternetAddress.anyIPv4, 0)`).
/// Yerel ağda telefon bu sunucudan formu yükleyip POST atar — veri
/// `submissionStream` üzerinden caller'a iletilir, sunucu otomatik
/// kapanır.
///
/// Bulut/veritabanı yok; her şey LAN üzerinden. Aynı Wi-Fi ağında
/// olmak yeterli. Sunucu sadece dialog açıkken yaşar:
/// `start()` ile kalkar, `stop()` ile kapanır, `Completer` ile veri
/// gelince otomatik kapanır.
class PlaylistQrServerService {
  PlaylistQrServerService();

  HttpServer? _server;
  StreamSubscription<HttpRequest>? _sub;
  Timer? _autoShutdown;

  /// Sunucu açık değilken `null`. Açıkken (örn) `http://192.168.1.50:54321/`.
  String? _localUrl;
  String? get localUrl => _localUrl;

  /// Telefondan POST geldiğinde tetiklenir. Dialog bunu dinler.
  final _submissions = StreamController<QrPlaylistSubmission>.broadcast();
  Stream<QrPlaylistSubmission> get submissionStream => _submissions.stream;

  bool get isRunning => _server != null;

  /// Sunucuyu başlatır ve telefonun açacağı URL'i döner. Hata durumunda
  /// exception fırlatır (UI snackbar ile gösterir).
  ///
  /// [timeout] doluncağı zaman sunucu otomatik kapanır (kullanıcı dialog'u
  /// açık unutsa bile RAM ve port sızıntısı olmaz). Varsayılan 10 dk.
  Future<String> start({
    Duration timeout = const Duration(minutes: 10),
  }) async {
    if (_server != null) return _localUrl!;

    // 1. Yerel IP'yi bul.
    final ip = await _resolveLanIp();
    if (ip == null) {
      throw const QrServerException('no_lan_ip');
    }

    // 2. HttpServer dinamik port üzerinde başlatılır.
    final server = await HttpServer.bind(InternetAddress.anyIPv4, 0);
    _server = server;
    _localUrl = 'http://$ip:${server.port}/';

    _sub = server.listen(
      _handleRequest,
      onError: (e, st) {
        if (kDebugMode) debugPrint('mina_iptv: qr server error: $e');
      },
      cancelOnError: false,
    );

    // 3. Otomatik kapanma sayacı.
    _autoShutdown = Timer(timeout, () {
      if (kDebugMode) debugPrint('mina_iptv: qr server timed out, stopping');
      stop();
    });

    return _localUrl!;
  }

  /// Sunucuyu kapatır. Idempotent.
  Future<void> stop() async {
    _autoShutdown?.cancel();
    _autoShutdown = null;
    await _sub?.cancel();
    _sub = null;
    final s = _server;
    _server = null;
    _localUrl = null;
    if (s != null) {
      try {
        await s.close(force: true);
      } catch (e) {
        if (kDebugMode) debugPrint('mina_iptv: qr server close error: $e');
      }
    }
  }

  // ---------------------------------------------------------------------------
  // İçeride.
  // ---------------------------------------------------------------------------

  /// Cihazın LAN üzerindeki birincil IP adresi. Wi-Fi tercih edilir;
  /// network_info_plus yetmezse `NetworkInterface.list` ile fallback yapılır.
  /// TV cihazlarında Ethernet de olabilir, oraya da bakar.
  Future<String?> _resolveLanIp() async {
    try {
      final wifiIp = await NetworkInfo().getWifiIP();
      if (wifiIp != null && wifiIp.isNotEmpty && wifiIp != '0.0.0.0') {
        return wifiIp;
      }
    } catch (e) {
      if (kDebugMode) debugPrint('mina_iptv: getWifiIP failed: $e');
    }
    // Fallback: tüm interface'leri tarayıp ilk gerçek IPv4'ü al.
    try {
      final ifaces = await NetworkInterface.list(
        type: InternetAddressType.IPv4,
        includeLinkLocal: false,
        includeLoopback: false,
      );
      for (final iface in ifaces) {
        for (final addr in iface.addresses) {
          if (!addr.isLoopback &&
              addr.type == InternetAddressType.IPv4 &&
              addr.address != '0.0.0.0') {
            return addr.address;
          }
        }
      }
    } catch (e) {
      if (kDebugMode) debugPrint('mina_iptv: NetworkInterface.list failed: $e');
    }
    return null;
  }

  Future<void> _handleRequest(HttpRequest req) async {
    try {
      // CORS açık tutulur — bazı browser'lar OPTIONS preflight atar.
      req.response.headers
        ..add('Access-Control-Allow-Origin', '*')
        ..add('Access-Control-Allow-Methods', 'GET, POST, OPTIONS')
        ..add('Access-Control-Allow-Headers', 'Content-Type');

      if (req.method == 'OPTIONS') {
        req.response.statusCode = 204;
        await req.response.close();
        return;
      }

      final path = req.uri.path;
      if (req.method == 'GET' && (path == '/' || path == '/add_playlist')) {
        await _serveForm(req);
        return;
      }
      if (req.method == 'POST' && path == '/submit') {
        await _handleSubmit(req);
        return;
      }
      req.response.statusCode = 404;
      req.response.headers.contentType =
          ContentType('text', 'plain', charset: 'utf-8');
      req.response.write('Not Found');
      await req.response.close();
    } catch (e) {
      if (kDebugMode) debugPrint('mina_iptv: qr server handle error: $e');
      try {
        req.response.statusCode = 500;
        await req.response.close();
      } catch (_) {}
    }
  }

  Future<void> _serveForm(HttpRequest req) async {
    req.response.headers.contentType =
        ContentType('text', 'html', charset: 'utf-8');
    req.response.write(_formHtml);
    await req.response.close();
  }

  Future<void> _handleSubmit(HttpRequest req) async {
    final bytes = <int>[];
    await for (final chunk in req) {
      bytes.addAll(chunk);
      if (bytes.length > 64 * 1024) {
        req.response.statusCode = 413;
        await req.response.close();
        return;
      }
    }
    final raw = utf8.decode(bytes, allowMalformed: true);
    Map<String, dynamic> data;
    try {
      data = jsonDecode(raw) as Map<String, dynamic>;
    } catch (_) {
      // x-www-form-urlencoded fallback.
      data = Uri.splitQueryString(raw);
    }
    final type = (data['type'] as String? ?? '').trim().toLowerCase();
    QrPlaylistSubmission? sub;
    if (type == 'm3u') {
      final url = (data['m3u_url'] as String? ?? '').trim();
      if (url.isEmpty) {
        await _respondJson(req, false, 'm3u_url required');
        return;
      }
      sub = QrPlaylistSubmission.m3u(url: url);
    } else if (type == 'xtream') {
      final server = (data['xtream_server'] as String? ?? '').trim();
      final user = (data['xtream_user'] as String? ?? '').trim();
      final pass = (data['xtream_pass'] as String? ?? '');
      if (server.isEmpty || user.isEmpty || pass.isEmpty) {
        await _respondJson(req, false, 'all xtream fields required');
        return;
      }
      sub = QrPlaylistSubmission.xtream(
        server: server,
        username: user,
        password: pass,
      );
    } else {
      await _respondJson(req, false, 'unknown type');
      return;
    }

    await _respondJson(req, true, 'ok');
    _submissions.add(sub);
    // Caller stop() çağıracak (UI tarafı submit'i tamamladıktan sonra).
  }

  Future<void> _respondJson(HttpRequest req, bool ok, String msg) async {
    req.response.statusCode = ok ? 200 : 400;
    req.response.headers.contentType =
        ContentType('application/', 'json', charset: 'utf-8');
    req.response.write(jsonEncode({'ok': ok, 'message': msg}));
    await req.response.close();
  }

  Future<void> dispose() async {
    await stop();
    await _submissions.close();
  }
}

/// Telefondan TV'ye gelen playlist verisi.
sealed class QrPlaylistSubmission {
  const QrPlaylistSubmission();

  const factory QrPlaylistSubmission.m3u({required String url}) =
      QrM3uSubmission;
  const factory QrPlaylistSubmission.xtream({
    required String server,
    required String username,
    required String password,
  }) = QrXtreamSubmission;
}

class QrM3uSubmission extends QrPlaylistSubmission {
  const QrM3uSubmission({required this.url});
  final String url;
}

class QrXtreamSubmission extends QrPlaylistSubmission {
  const QrXtreamSubmission({
    required this.server,
    required this.username,
    required this.password,
  });
  final String server;
  final String username;
  final String password;
}

class QrServerException implements Exception {
  const QrServerException(this.code);
  final String code;
  @override
  String toString() => 'QrServerException($code)';
}

// =============================================================================
// Telefonda gösterilecek hafif HTML form. Tek dosya, harici CSS/JS yok.
// =============================================================================

const String _formHtml = '''
<!DOCTYPE html>
<html lang="tr">
<head>
<meta charset="utf-8" />
<meta name="viewport" content="width=device-width,initial-scale=1,maximum-scale=1,viewport-fit=cover" />
<title>Mina IPTV — Liste Ekle</title>
<style>
  :root { color-scheme: dark; }
  * { box-sizing: border-box; -webkit-tap-highlight-color: transparent; }
  body {
    margin: 0; padding: 0;
    font-family: -apple-system, BlinkMacSystemFont, "Segoe UI", Roboto, "Helvetica Neue", sans-serif;
    background: radial-gradient(ellipse at top, #1e293b 0%, #0b1220 60%, #050810 100%);
    color: #f1f5f9;
    min-height: 100vh;
  }
  .wrap {
    max-width: 480px; margin: 0 auto; padding: 24px 18px 60px;
  }
  .brand {
    display: flex; align-items: center; gap: 10px;
    margin-bottom: 4px;
  }
  .brand .dot {
    width: 36px; height: 36px; border-radius: 12px;
    background: linear-gradient(135deg, #38bdf8, #22d3ee);
    display: flex; align-items: center; justify-content: center;
    font-weight: 800; color: #051022; font-size: 20px;
    box-shadow: 0 6px 20px rgba(56, 189, 248, .35);
  }
  .brand h1 { font-size: 18px; margin: 0; font-weight: 800; letter-spacing: .2px; }
  .sub { font-size: 13px; color: #94a3b8; margin: 6px 0 22px; line-height: 1.45; }

  .tabs {
    display: flex; gap: 6px; padding: 5px;
    background: rgba(255,255,255,.06); border: 1px solid rgba(255,255,255,.10);
    border-radius: 14px; margin-bottom: 14px;
  }
  .tab {
    flex: 1; text-align: center; padding: 10px 0; font-weight: 700;
    color: #cbd5e1; font-size: 14px; border-radius: 10px;
    cursor: pointer; transition: all .2s ease;
  }
  .tab.active {
    background: rgba(56, 189, 248, .22);
    color: #fff;
    border: 1px solid rgba(56, 189, 248, .55);
  }

  .card {
    background: rgba(15,23,42,.55);
    border: 1px solid rgba(255,255,255,.14);
    backdrop-filter: blur(14px); -webkit-backdrop-filter: blur(14px);
    border-radius: 18px; padding: 18px 16px;
    box-shadow: 0 12px 40px rgba(0,0,0,.45);
  }

  label { display: block; font-size: 12.5px; color: #94a3b8; font-weight: 600;
    margin: 12px 0 6px; letter-spacing: .3px; }
  input {
    width: 100%; padding: 14px 14px;
    border-radius: 12px; border: 1px solid rgba(255,255,255,.12);
    background: rgba(255,255,255,.05); color: #fff; font-size: 15px;
    outline: none; transition: border .15s ease, background .15s ease;
  }
  input:focus { border-color: #38bdf8; background: rgba(56,189,248,.08); }

  button {
    width: 100%; margin-top: 18px; padding: 16px;
    background: linear-gradient(135deg, #38bdf8, #22d3ee);
    color: #04111f; font-weight: 800; font-size: 16px;
    border: none; border-radius: 14px; cursor: pointer;
    box-shadow: 0 12px 30px rgba(34, 211, 238, .35);
    transition: transform .1s ease, box-shadow .15s ease;
  }
  button:active { transform: scale(.97); }
  button:disabled { opacity: .55; cursor: not-allowed; }

  .status {
    margin-top: 16px; padding: 12px; border-radius: 10px;
    font-size: 13.5px; display: none; line-height: 1.4;
  }
  .status.ok { background: rgba(34,197,94,.16); border: 1px solid rgba(34,197,94,.45); color: #bbf7d0; display: block; }
  .status.err { background: rgba(239,68,68,.18); border: 1px solid rgba(239,68,68,.45); color: #fecaca; display: block; }

  .pane { display: none; }
  .pane.active { display: block; }
</style>
</head>
<body>
<div class="wrap">
  <div class="brand">
    <div class="dot">M</div>
    <h1>Mina IPTV — Liste Ekle</h1>
  </div>
  <div class="sub">Bu sayfa TV'nizdeki uygulamayla aynı Wi-Fi ağı üzerinden konuşur. Listeyi gönderdiğinizde TV otomatik yüklemeye başlar.</div>

  <div class="card">
    <div class="tabs">
      <div class="tab active" data-pane="m3u">M3U</div>
      <div class="tab" data-pane="xtream">Xtream</div>
    </div>

    <div class="pane active" id="pane-m3u">
      <label>M3U URL</label>
      <input id="m3u_url" type="url" inputmode="url" autocomplete="off"
             placeholder="http://example.com/playlist.m3u" />
    </div>

    <div class="pane" id="pane-xtream">
      <label>Sunucu URL</label>
      <input id="xtream_server" type="url" inputmode="url" autocomplete="off"
             placeholder="http://server.com:8080" />
      <label>Kullanıcı adı</label>
      <input id="xtream_user" type="text" autocomplete="off" />
      <label>Şifre</label>
      <input id="xtream_pass" type="password" autocomplete="off" />
    </div>

    <button id="sendBtn">Gönder</button>
    <div id="status" class="status"></div>
  </div>
</div>

<script>
(function(){
  var activePane = 'm3u';
  var tabs = document.querySelectorAll('.tab');
  tabs.forEach(function(t){
    t.addEventListener('click', function(){
      tabs.forEach(function(x){ x.classList.remove('active'); });
      t.classList.add('active');
      activePane = t.getAttribute('data-pane');
      document.querySelectorAll('.pane').forEach(function(p){ p.classList.remove('active'); });
      document.getElementById('pane-' + activePane).classList.add('active');
      hideStatus();
    });
  });

  var btn = document.getElementById('sendBtn');
  var statusEl = document.getElementById('status');

  function showStatus(msg, ok){
    statusEl.className = 'status ' + (ok ? 'ok' : 'err');
    statusEl.textContent = msg;
  }
  function hideStatus(){ statusEl.className = 'status'; statusEl.textContent = ''; }

  btn.addEventListener('click', function(){
    hideStatus();
    var body = { type: activePane };
    if (activePane === 'm3u') {
      var u = document.getElementById('m3u_url').value.trim();
      if (!u) { showStatus('M3U URL gerekli.', false); return; }
      body.m3u_url = u;
    } else {
      var s = document.getElementById('xtream_server').value.trim();
      var us = document.getElementById('xtream_user').value.trim();
      var ps = document.getElementById('xtream_pass').value;
      if (!s || !us || !ps) { showStatus('Tüm Xtream alanları gerekli.', false); return; }
      body.xtream_server = s; body.xtream_user = us; body.xtream_pass = ps;
    }
    btn.disabled = true; btn.textContent = 'Gönderiliyor…';
    fetch('/submit', {
      method: 'POST',
      headers: { 'Content-Type': 'application/json' },
      body: JSON.stringify(body),
    }).then(function(r){ return r.json().then(function(j){ return { ok: r.ok, j: j }; }); })
      .then(function(res){
        if (res.ok && res.j && res.j.ok) {
          showStatus('TV listeyi aldı. Yükleme başladı, telefonu kapatabilirsiniz.', true);
          btn.textContent = 'Gönderildi ✓';
        } else {
          showStatus((res.j && res.j.message) || 'Gönderim hatası.', false);
          btn.disabled = false; btn.textContent = 'Gönder';
        }
      })
      .catch(function(){
        showStatus('TV ile bağlantı kuruldu ama sonuç alınamadı. TV ekranını kontrol edin.', false);
        btn.disabled = false; btn.textContent = 'Tekrar dene';
      });
  });
})();
</script>
</body>
</html>
''';
