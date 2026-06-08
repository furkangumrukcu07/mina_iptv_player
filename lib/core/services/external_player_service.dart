import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import 'package:get/get.dart';
import 'package:url_launcher/url_launcher.dart' as url_launcher;

/// Tek bir harici oynatıcı seçeneği — Ayarlar > Harici Oynatıcı diyaloğunda
/// listelenir, kullanıcı seçtiğinde [ExternalPlayerService.launch] otomatik
/// olarak ilgili uygulamayı açar.
@immutable
class ExternalPlayerApp {
  const ExternalPlayerApp({
    required this.id,
    required this.name,
    this.icon,
    this.iosScheme,
    this.androidPackage,
  });

  /// Kalıcı kimlik. Android'de paket adı (`org.videolan.vlc`), iOS'ta
  /// bilinen scheme tanımı (`vlc`, `infuse`, …).
  final String id;

  /// Kullanıcıya gösterilecek isim ("VLC", "MX Player", "Infuse").
  final String name;

  /// Android'de uygulama ikonu (PNG bytes); iOS'ta sabit asset/glyph yerine
  /// null bırakılır — UI default ikon gösterir.
  final Uint8List? icon;

  /// iOS scheme (`vlc`, `infuse`, …) — Android'de boş.
  final String? iosScheme;

  /// Android paket adı — iOS'ta boş.
  final String? androidPackage;
}

/// Harici Oynatıcı entegrasyonu.
///
/// **Android**: [Intent.ACTION_VIEW] + `video/*` MIME türünü işleyen tüm
/// uygulamaları sistemden listeler (VLC, MX Player, Just Player, nPlayer,
/// Kodi, Mi Video, vs.). Kullanıcının seçtiği paketi `setPackage()` ile
/// hedefler; seçim yoksa Android'in seçici diyaloğu çıkar.
///
/// **iOS**: Sandbox nedeniyle yüklü uygulamalar listelenemez. Bunun yerine
/// bilinen video oynatıcıların URL şemalarını [canLaunchUrl] ile probe eder
/// ve yalnızca yüklü olanları kullanıcıya gösterir. Açma işlemi de URL
/// şeması üzerinden ([url_launcher]).
///
/// **Diğer platformlar**: Desteklenmez (sistemin varsayılan tarayıcısına
/// fallback yapılır).
class ExternalPlayerService extends GetxService {
  ExternalPlayerService();

  static const _channel = MethodChannel('mina.device/external_player');

  /// Yapılandırma sırasında platform desteği yoksa false döner — UI
  /// bölümlerinde tile gizlemek için kullanılır.
  bool get isPlatformSupported => Platform.isAndroid || Platform.isIOS;

  /// Sentinel: kullanıcı "Sistem seçicisini göster" seçeneğini seçtiğinde
  /// (yani belirli bir paketi pin'lemek istemiyor) [appId] olarak bu değer
  /// kaydedilir. [launch] çağrısında Android tarafında package boş gönderilir
  /// → sistem seçici açılır.
  static const String chooserId = '__chooser__';

  /// Bilinen iOS oynatıcıları — `canLaunchUrl` ile probe edilir.
  static const List<_IosPlayerCandidate> _iosCandidates = [
    _IosPlayerCandidate(
      id: 'vlc-x-callback',
      name: 'VLC',
      // x-callback varsa daha güvenilir; yoksa `vlc://` fallback.
      probeScheme: 'vlc-x-callback',
      buildUrl: _buildVlcXCallbackUrl,
    ),
    _IosPlayerCandidate(
      id: 'vlc',
      name: 'VLC (Basic)',
      probeScheme: 'vlc',
      buildUrl: _buildVlcBasicUrl,
    ),
    _IosPlayerCandidate(
      id: 'infuse',
      name: 'Infuse',
      probeScheme: 'infuse',
      buildUrl: _buildInfuseUrl,
    ),
    _IosPlayerCandidate(
      id: 'nplayer-https',
      name: 'nPlayer',
      probeScheme: 'nplayer-https',
      buildUrl: _buildNPlayerUrl,
    ),
    _IosPlayerCandidate(
      id: 'oplayer',
      name: 'OPlayer',
      probeScheme: 'oplayer',
      buildUrl: _buildOPlayerUrl,
    ),
    _IosPlayerCandidate(
      id: 'iina',
      name: 'IINA',
      probeScheme: 'iina',
      buildUrl: _buildIinaUrl,
    ),
    _IosPlayerCandidate(
      id: 'outplayer',
      name: 'Outplayer',
      probeScheme: 'outplayer',
      buildUrl: _buildOutplayerUrl,
    ),
  ];

  /// Yüklü oynatıcı listesini döner. Android'de native tarafa sorulur,
  /// iOS'ta bilinen scheme'ler `canLaunchUrl` ile probe edilir.
  ///
  /// Sıralama: alfabetik (kullanıcıya tanıdık tutmak için).
  Future<List<ExternalPlayerApp>> listInstalled() async {
    if (Platform.isAndroid) {
      return _listAndroid();
    }
    if (Platform.isIOS) {
      return _listIos();
    }
    return const <ExternalPlayerApp>[];
  }

  Future<List<ExternalPlayerApp>> _listAndroid() async {
    try {
      final raw = await _channel.invokeListMethod<dynamic>('list');
      if (raw == null) return const <ExternalPlayerApp>[];
      final out = <ExternalPlayerApp>[];
      for (final entry in raw) {
        if (entry is! Map) continue;
        final pkg = (entry['packageName'] as String?)?.trim();
        final name = (entry['name'] as String?)?.trim();
        if (pkg == null || pkg.isEmpty || name == null || name.isEmpty) {
          continue;
        }
        Uint8List? icon;
        final iconB64 = entry['iconBase64'] as String?;
        if (iconB64 != null && iconB64.isNotEmpty) {
          try {
            icon = base64Decode(iconB64);
          } catch (_) {
            icon = null;
          }
        }
        out.add(
          ExternalPlayerApp(
            id: pkg,
            name: name,
            icon: icon,
            androidPackage: pkg,
          ),
        );
      }
      return out;
    } on PlatformException catch (e) {
      debugPrint('mina_iptv: external_player list (android): $e');
      return const <ExternalPlayerApp>[];
    }
  }

  Future<List<ExternalPlayerApp>> _listIos() async {
    final out = <ExternalPlayerApp>[];
    for (final c in _iosCandidates) {
      final probe = Uri.parse('${c.probeScheme}://');
      bool installed = false;
      try {
        installed = await url_launcher.canLaunchUrl(probe);
      } catch (_) {
        installed = false;
      }
      if (!installed) continue;
      out.add(
        ExternalPlayerApp(
          id: c.id,
          name: c.name,
          iosScheme: c.probeScheme,
        ),
      );
    }
    return out;
  }

  /// Belirtilen [streamUrl] adresini, kullanıcının seçtiği harici
  /// oynatıcıda açar.
  ///
  /// * [appId] — `null` veya [chooserId] ise Android'de sistem seçicisini
  ///   açar; iOS'ta yüklü ilk oynatıcıya düşer.
  /// * [title] — kanal/film adı (oynatıcı üst başlığında gösterebilir).
  ///
  /// Başarılı olduğunda `true` döner.
  Future<bool> launch(
    String streamUrl, {
    String? appId,
    String? title,
  }) async {
    final url = streamUrl.trim();
    if (url.isEmpty) return false;
    if (Platform.isAndroid) {
      return _launchAndroid(url, packageName: appId, title: title);
    }
    if (Platform.isIOS) {
      return _launchIos(url, schemeId: appId);
    }
    // Diğer platformlarda yalnızca varsayılan tarayıcıya yönlendir.
    try {
      final uri = Uri.tryParse(url);
      if (uri == null) return false;
      return await url_launcher.launchUrl(
        uri,
        mode: url_launcher.LaunchMode.externalApplication,
      );
    } catch (_) {
      return false;
    }
  }

  Future<bool> _launchAndroid(
    String url, {
    String? packageName,
    String? title,
  }) async {
    try {
      final pkg = (packageName == null || packageName == chooserId)
          ? ''
          : packageName;
      final ok = await _channel.invokeMethod<bool>('launch', <String, dynamic>{
        'url': url,
        'packageName': pkg,
        'title': title ?? '',
      });
      return ok ?? false;
    } on PlatformException catch (e) {
      debugPrint('mina_iptv: external_player launch (android): $e');
      return false;
    }
  }

  Future<bool> _launchIos(String url, {String? schemeId}) async {
    final candidates = <_IosPlayerCandidate>[];
    if (schemeId != null && schemeId.isNotEmpty && schemeId != chooserId) {
      _IosPlayerCandidate? exact;
      for (final c in _iosCandidates) {
        if (c.id == schemeId) {
          exact = c;
          break;
        }
      }
      if (exact != null) candidates.add(exact);
    }
    if (candidates.isEmpty) {
      // Kayıtlı seçim yoksa yüklü olanlardan ilkini dene.
      for (final c in _iosCandidates) {
        try {
          if (await url_launcher
              .canLaunchUrl(Uri.parse('${c.probeScheme}://'))) {
            candidates.add(c);
            break;
          }
        } catch (_) {}
      }
    }
    for (final c in candidates) {
      final target = c.buildUrl(url);
      try {
        final uri = Uri.parse(target);
        if (await url_launcher.canLaunchUrl(uri)) {
          final ok = await url_launcher.launchUrl(
            uri,
            mode: url_launcher.LaunchMode.externalApplication,
          );
          if (ok) return true;
        }
      } catch (e) {
        debugPrint('mina_iptv: external_player launch (ios) ${c.id}: $e');
      }
    }
    return false;
  }
}

class _IosPlayerCandidate {
  const _IosPlayerCandidate({
    required this.id,
    required this.name,
    required this.probeScheme,
    required this.buildUrl,
  });

  final String id;
  final String name;
  final String probeScheme;
  final String Function(String url) buildUrl;
}

// =============================================================================
// iOS scheme builder'lar — bilinen tüm popüler iOS video oynatıcıları
// =============================================================================

String _buildVlcXCallbackUrl(String streamUrl) {
  final u = Uri.encodeComponent(streamUrl);
  return 'vlc-x-callback://x-callback-url/stream?url=$u';
}

String _buildVlcBasicUrl(String streamUrl) {
  // VLC iOS direkt URL'i kabul eder: `vlc://<url>`
  return 'vlc://$streamUrl';
}

String _buildInfuseUrl(String streamUrl) {
  final u = Uri.encodeComponent(streamUrl);
  return 'infuse://x-callback-url/play?url=$u';
}

String _buildNPlayerUrl(String streamUrl) {
  // nPlayer: scheme = nplayer-<orijinal scheme><rest>
  final lower = streamUrl.toLowerCase();
  if (lower.startsWith('https://')) {
    return 'nplayer-https://${streamUrl.substring('https://'.length)}';
  }
  if (lower.startsWith('http://')) {
    return 'nplayer-http://${streamUrl.substring('http://'.length)}';
  }
  return 'nplayer-$streamUrl';
}

String _buildOPlayerUrl(String streamUrl) {
  // OPlayer: oplayer://orijinal-url-encoded
  final u = Uri.encodeComponent(streamUrl);
  return 'oplayer://$u';
}

String _buildIinaUrl(String streamUrl) {
  final u = Uri.encodeComponent(streamUrl);
  return 'iina://weblink?url=$u';
}

String _buildOutplayerUrl(String streamUrl) {
  return 'outplayer://$streamUrl';
}
