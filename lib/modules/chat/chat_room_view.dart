import 'dart:ui';

import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:get/get.dart';
import 'package:intl/intl.dart';

import '../../core/layout/app_layout_mode.dart';
import '../../core/services/app_settings_service.dart';
import '../../core/services/chat_service.dart';
import 'chat_online_badge.dart';
import '../../ui/glass_overlays.dart';
import '../../ui/settings_glass_panel.dart';
import '../../ui/themed_settings_background.dart';
import '../../ui/tv_dpad_focus.dart';

/// Tek bir dil odasının canlı sohbet ekranı. Mesajlar [StreamBuilder] ile
/// canlı dinlenir (son 100, kronolojik — en yeni en altta). Bu ekran açılana
/// kadar Firestore'a hiçbir dinleyici bağlanmaz.
class ChatRoomView extends StatefulWidget {
  const ChatRoomView({super.key});

  @override
  State<ChatRoomView> createState() => _ChatRoomViewState();
}

class _ChatRoomViewState extends State<ChatRoomView> {
  late final ChatService _chat = Get.find<ChatService>();
  late final ChatRoom _room;
  final TextEditingController _input = TextEditingController();
  final FocusNode _inputFocus = FocusNode();
  bool _sending = false;

  /// Destek (yöneticiye mesaj) modu — bir dil odası yerine birebir admin DM.
  ChatSupportTarget? _support;
  bool get _isSupport => _support != null;

  /// Yanıtlanmakta olan mesaj (varsa composer üstünde alıntı gösterilir).
  ChatMessage? _replyTo;

  /// Seçili yayın durumu etiketi (composer'da chip olarak görünür).
  ChatStatusTag? _statusTag;

  /// Aktif mesaj akışı — **bir kez** oluşturulur. Eskiden `build` içinde her
  /// çağrıda yeni `Stream` üretiliyordu; klavye/reply/gönder gibi her yeniden
  /// çizimde `StreamBuilder` Firestore'a yeniden abone oluyordu.
  late final Stream<List<ChatMessage>> _messagesStream;

  @override
  void initState() {
    super.initState();
    final args = Get.arguments;
    if (args is ChatSupportTarget) {
      _support = args;
      _room = const ChatRoom(langCode: 'en', nativeName: 'English');
    } else {
      _room = args is ChatRoom
          ? args
          : const ChatRoom(langCode: 'en', nativeName: 'English');
    }
    _messagesStream = _isSupport
        ? _chat.supportMessagesStream(_support!.threadUid)
        : _chat.messagesStream(_room.langCode);
  }

  @override
  void dispose() {
    _input.dispose();
    _inputFocus.dispose();
    super.dispose();
  }

  Future<void> _send() async {
    final text = _input.text.trim();
    if (text.isEmpty || _sending) return;
    setState(() => _sending = true);
    final ok = _isSupport
        ? await _chat.sendSupportMessage(
            _support!.threadUid,
            text,
            replyTo: _replyTo,
            targetUserName: _support!.title,
            targetUserPhotoUrl: _support!.photoUrl,
          )
        : await _chat.sendMessage(
            _room.langCode,
            text,
            replyTo: _replyTo,
            statusTag: _statusTag,
          );
    if (!mounted) return;
    setState(() {
      _sending = false;
      if (ok) {
        _replyTo = null;
        _statusTag = null;
      }
    });
    if (ok) {
      _input.clear();
      _inputFocus.requestFocus();
    }
  }

  void _startReply(ChatMessage msg) {
    setState(() => _replyTo = msg);
    _inputFocus.requestFocus();
  }

  void _cancelReply() => setState(() => _replyTo = null);

  void _showReportIssueDialog() {
    final ctrl = TextEditingController();
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: const Color(0xFF1E293B),
        title: const Text('Sorun Bildir', style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text('Lütfen yaşadığınız sorunu detaylıca açıklayın.', style: TextStyle(color: Colors.white70, fontSize: 14)),
            const SizedBox(height: 12),
            TextField(
              controller: ctrl,
              style: const TextStyle(color: Colors.white),
              maxLines: 4,
              decoration: InputDecoration(
                hintText: 'Sorununuz nedir?',
                hintStyle: const TextStyle(color: Colors.white38),
                filled: true,
                fillColor: Colors.white.withValues(alpha: 0.05),
                border: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: BorderSide.none),
              ),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(),
            child: Text('common.cancel'.tr, style: const TextStyle(color: Colors.white54)),
          ),
          ElevatedButton(
            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.amberAccent,
              foregroundColor: Colors.black,
            ),
            onPressed: () async {
              final text = ctrl.text.trim();
              if (text.isEmpty) return;
              Navigator.of(ctx).pop();
              
              // Send message which automatically marks thread as 'unread' (pending)
              await _chat.sendSupportMessage(
                _support!.threadUid,
                text,
              );
              if (mounted) {
                GlassSnackbar.show('Başarılı', 'Destek talebiniz oluşturuldu.');
              }
            },
            child: const Text('Gönder', style: TextStyle(fontWeight: FontWeight.bold)),
          ),
        ],
      ),
    );
  }

  Future<void> _pickStatusTag() async {
    FocusScope.of(context).unfocus();
    // Sonuç: ChatStatusTag (seçildi), 'clear' (temizle), null (vazgeçildi).
    final picked = await showModalBottomSheet<Object?>(
      context: context,
      backgroundColor: Colors.transparent,
      builder: (sheetCtx) => _StatusTagSheet(current: _statusTag),
    );
    if (!mounted || picked == null) return;
    setState(() {
      _statusTag = picked is ChatStatusTag ? picked : null;
    });
  }

  /// Mesaja uzun basınca açılan eylem menüsü: yanıtla, kopyala, sil. Herkes
  /// yanıtlayıp kopyalayabilir; silme yalnızca kendi mesajında ya da admin ise
  /// her mesajda görünür (admin için "Herkesten Sil").
  Future<void> _showMessageMenu(ChatMessage msg, bool mine) async {
    FocusScope.of(context).unfocus();
    final canDelete = _chat.canDelete(msg);
    // Admin başkasının mesajını siliyorsa "Herkesten Sil" vurgusu.
    final adminDeletingOther = _chat.isCurrentUserAdmin && !mine;
    await showModalBottomSheet<void>(
      context: context,
      backgroundColor: Colors.transparent,
      builder: (sheetCtx) => _MessageActionSheet(
        canDelete: canDelete,
        deleteLabel: adminDeletingOther
            ? 'chat.msg.deleteForAll'.tr
            : 'chat.msg.delete'.tr,
        onReply: () {
          Navigator.of(sheetCtx).pop();
          _startReply(msg);
        },
        onCopy: () {
          Navigator.of(sheetCtx).pop();
          Clipboard.setData(ClipboardData(text: msg.messageText));
          GlassSnackbar.show('chat.title'.tr, 'chat.msg.copied'.tr);
        },
        onDelete: canDelete
            ? () {
                Navigator.of(sheetCtx).pop();
                _confirmDelete(msg, adminDeletingOther);
              }
            : null,
      ),
    );
  }

  Future<void> _confirmDelete(ChatMessage msg, bool forAll) async {
    final remote =
        Get.find<AppSettingsService>().layoutMode.value.usesRemoteNavigationStyle;
    final ok = await showDialog<bool>(
      context: context,
      builder: (dCtx) => GlassAlertDialog(
        tvOsdStyle: remote,
        title: Text(forAll ? 'chat.msg.deleteForAll'.tr : 'chat.msg.deleteTitle'.tr),
        content: Text('chat.msg.deleteBody'.tr),
        actions: [
          GlassDialogActionButton(
            label: 'common.cancel'.tr,
            onDarkSurface: remote,
            onPressed: () => Navigator.of(dCtx).pop(false),
          ),
          GlassDialogActionButton(
            label: 'chat.msg.delete'.tr,
            primary: true,
            onDarkSurface: remote,
            onPressed: () => Navigator.of(dCtx).pop(true),
          ),
        ],
      ),
    );
    if (ok != true) return;
    final done = _isSupport
        ? await _chat.deleteSupportMessage(_support!.threadUid, msg)
        : await _chat.deleteMessage(_room.langCode, msg);
    if (!mounted) return;
    if (!done) {
      GlassSnackbar.show('chat.title'.tr, 'chat.msg.deleteFailed'.tr);
    }
  }

  @override
  Widget build(BuildContext context) {
    final settings = Get.find<AppSettingsService>();
    final remote = settings.layoutMode.value.usesRemoteNavigationStyle;
    final myId = _chat.currentUserId;

    return Scaffold(
      backgroundColor: Colors.black,
      resizeToAvoidBottomInset: true,
      body: ThemedSettingsBackground(
        child: SafeArea(
          child: SettingsGlassPanel(
            blurBackground: false,
            child: Column(
              children: [
                Padding(
                  padding: const EdgeInsets.fromLTRB(12, 10, 12, 8),
                  child: Row(
                    children: [
                      remote
                          ? TvIconButton(
                              icon: Icons.arrow_back_rounded,
                              onPressed: () => Get.back<void>(),
                            )
                          : IconButton(
                              onPressed: () => Get.back<void>(),
                              icon: const Icon(Icons.arrow_back_rounded),
                              color: Colors.white,
                              tooltip: 'common.back'.tr,
                            ),
                      const SizedBox(width: 4),
                      if (_isSupport) ...[
                        _ChatAvatar(
                          name: _support!.title,
                          photoUrl: _support!.photoUrl,
                        ),
                        const SizedBox(width: 8),
                      ],
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              _isSupport ? _support!.title : _room.nativeName,
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              style: const TextStyle(
                                color: Colors.white,
                                fontSize: 17,
                                fontWeight: FontWeight.w800,
                              ),
                            ),
                            Text(
                              _isSupport
                                  ? (_support!.adminView
                                      ? 'chat.support.adminHeaderSub'.tr
                                      : 'chat.support.userHeaderSub'.tr)
                                  : 'chat.room.headerSub'.tr,
                              style: TextStyle(
                                color: Colors.white.withValues(alpha: 0.6),
                                fontSize: 11.5,
                              ),
                            ),
                          ],
                        ),
                      ),
                      if (_isSupport && !_support!.adminView) ...[
                        const SizedBox(width: 8),
                        ElevatedButton.icon(
                          style: ElevatedButton.styleFrom(
                            backgroundColor: Colors.amberAccent.withValues(alpha: 0.2),
                            foregroundColor: Colors.amberAccent,
                            elevation: 0,
                            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                          ),
                          icon: const Icon(Icons.support_agent_rounded, size: 16),
                          label: const Text('Sorun Bildir', style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold)),
                          onPressed: _showReportIssueDialog,
                        ),
                      ],
                      if (!_isSupport) ...[
                        const SizedBox(width: 8),
                        const ChatOnlineBadge(),
                      ],
                    ],
                  ),
                ),
                Expanded(
                  child: StreamBuilder<List<ChatMessage>>(
                    stream: _messagesStream,
                    builder: (context, snapshot) {
                      if (snapshot.connectionState == ConnectionState.waiting &&
                          !snapshot.hasData) {
                        return const Center(
                          child: CircularProgressIndicator(strokeWidth: 2),
                        );
                      }
                      final messages = snapshot.data ?? const <ChatMessage>[];
                      if (messages.isEmpty) {
                        return _EmptyRoom(
                          messageKey: _isSupport
                              ? (_support!.adminView
                                  ? 'chat.support.emptyAdmin'
                                  : 'chat.support.emptyUser')
                              : 'chat.room.empty',
                        );
                      }
                      return ListView.builder(
                        reverse: true,
                        padding: const EdgeInsets.fromLTRB(12, 8, 12, 8),
                        itemCount: messages.length,
                        itemBuilder: (context, index) {
                          final msg = messages[messages.length - 1 - index];
                          final mine = myId != null && msg.senderId == myId;
                          return _ChatBubble(
                            message: msg,
                            mine: mine,
                            onLongPress: () => _showMessageMenu(msg, mine),
                          );
                        },
                      );
                    },
                  ),
                ),
                _Composer(
                  controller: _input,
                  focusNode: _inputFocus,
                  sending: _sending,
                  onSend: _send,
                  replyTo: _replyTo,
                  onCancelReply: _cancelReply,
                  statusTag: _statusTag,
                  onPickStatusTag: _pickStatusTag,
                  onClearStatusTag: () => setState(() => _statusTag = null),
                  allowStatusTag: !_isSupport,
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _EmptyRoom extends StatelessWidget {
  const _EmptyRoom({this.messageKey = 'chat.room.empty'});

  final String messageKey;

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(Icons.chat_bubble_outline_rounded,
              color: Colors.white.withValues(alpha: 0.4), size: 44),
          const SizedBox(height: 12),
          Text(
            messageKey.tr,
            textAlign: TextAlign.center,
            style: TextStyle(
              color: Colors.white.withValues(alpha: 0.6),
              fontSize: 14,
            ),
          ),
        ],
      ),
    );
  }
}

/// Normal kullanıcı isimleri için rastgele (sabit) renk paleti — aynı isim
/// hep aynı rengi alır, böylece kalabalık odada kullanıcılar ayırt edilir.
const List<Color> _nameColorPalette = [
  Color(0xFF42A5F5),
  Color(0xFF66BB6A),
  Color(0xFFAB47BC),
  Color(0xFF26C6DA),
  Color(0xFFFF7043),
  Color(0xFFEC407A),
  Color(0xFF7E57C2),
  Color(0xFF9CCC65),
];

Color _nameColor(ChatMessage message, Color primary) {
  if (message.isAdmin) return const Color(0xFFFFC107); // amber
  if (message.senderName.isEmpty) return primary;
  return _nameColorPalette[
      message.senderName.hashCode.abs() % _nameColorPalette.length];
}

/// `*kalın*`, `_italik_`, `~üstü çizili~` markdown'ı [TextSpan]'lere ayırır.
List<TextSpan> _parseMarkdown(String text, TextStyle base) {
  final spans = <TextSpan>[];
  final pattern =
      RegExp(r'(\*[^*\n]+\*|_[^_\n]+_|~[^~\n]+~)');
  var last = 0;
  for (final m in pattern.allMatches(text)) {
    if (m.start > last) {
      spans.add(TextSpan(text: text.substring(last, m.start), style: base));
    }
    final token = m.group(0)!;
    final inner = token.substring(1, token.length - 1);
    final marker = token[0];
    final style = switch (marker) {
      '*' => base.copyWith(fontWeight: FontWeight.w800),
      '_' => base.copyWith(fontStyle: FontStyle.italic),
      '~' => base.copyWith(decoration: TextDecoration.lineThrough),
      _ => base,
    };
    spans.add(TextSpan(text: inner, style: style));
    last = m.end;
  }
  if (last < text.length) {
    spans.add(TextSpan(text: text.substring(last), style: base));
  }
  return spans;
}

/// Cam stilli mesaj balonu (Telegram tarzı). Her mesajda gönderenin profil
/// avatarı ve adı görünür. Admin mesajları amber + [Admin] rozetli; normal
/// kullanıcı isimleri rastgele renkte. Reply alıntısı, yayın durumu etiketi,
/// markdown ve gönderildi ikonu desteklenir. Uzun basınca eylem menüsü açılır.
class _ChatBubble extends StatelessWidget {
  const _ChatBubble({
    required this.message,
    required this.mine,
    required this.onLongPress,
  });

  final ChatMessage message;
  final bool mine;
  final VoidCallback onLongPress;

  @override
  Widget build(BuildContext context) {
    final primary = Theme.of(context).colorScheme.primary;
    final time = message.timestamp;
    final timeLabel = time != null ? DateFormat.Hm().format(time) : '';
    final isAdmin = message.isAdmin;
    final nameColor = _nameColor(message, primary);

    final Color bubbleColor;
    final Color borderColor;
    if (isAdmin) {
      bubbleColor = const Color(0xFFFFC107).withValues(alpha: 0.16);
      borderColor = const Color(0xFFFFC107).withValues(alpha: 0.55);
    } else if (mine) {
      bubbleColor = primary.withValues(alpha: 0.32);
      borderColor = primary.withValues(alpha: 0.5);
    } else {
      bubbleColor = Colors.white.withValues(alpha: 0.08);
      borderColor = Colors.white.withValues(alpha: 0.14);
    }

    final avatar = _ChatAvatar(
      name: message.senderName,
      photoUrl: message.senderPhotoUrl,
    );

    final tag = ChatStatusTag.fromKey(message.statusTag);

    final bubble = Flexible(
      child: GestureDetector(
        onLongPress: onLongPress,
        child: DecoratedBox(
            // Not: Her balonda BackdropFilter (blur) KULLANILMAZ — uzun listede
            // her mesaj ayrı bir GPU blur geçişi olduğu için kaydırmada
            // donmalara yol açıyordu. Camsı görünüm yarı saydam renk +
            // kenarlıkla korunur; performans çok daha akıcı.
            decoration: BoxDecoration(
              color: bubbleColor,
              borderRadius: BorderRadius.circular(16),
              border: Border.all(color: borderColor),
            ),
            child: Padding(
              padding: const EdgeInsets.fromLTRB(12, 8, 12, 8),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisSize: MainAxisSize.min,
                children: [
                  Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Flexible(
                        child: Text(
                          mine ? 'chat.msg.you'.tr : message.senderName,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: TextStyle(
                            color: nameColor,
                            fontSize: 12,
                            fontWeight: FontWeight.w800,
                          ),
                        ),
                      ),
                      if (isAdmin) ...[
                        const SizedBox(width: 5),
                        _AdminBadge(),
                      ],
                    ],
                  ),
                  if (message.replyToName != null) ...[
                    const SizedBox(height: 4),
                    _ReplyQuote(
                      name: message.replyToName!,
                      text: message.replyToText ?? '',
                      accent: nameColor,
                    ),
                  ],
                  if (tag != null) ...[
                    const SizedBox(height: 4),
                    _StatusChip(tag: tag),
                  ],
                  const SizedBox(height: 3),
                  Text.rich(
                    TextSpan(
                      children: _parseMarkdown(
                        message.messageText,
                        const TextStyle(
                          color: Colors.white,
                          fontSize: 14.5,
                          height: 1.3,
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(height: 3),
                  Row(
                    mainAxisSize: MainAxisSize.min,
                    mainAxisAlignment: MainAxisAlignment.end,
                    children: [
                      if (timeLabel.isNotEmpty)
                        Text(
                          timeLabel,
                          style: TextStyle(
                            color: Colors.white.withValues(alpha: 0.55),
                            fontSize: 10.5,
                          ),
                        ),
                      if (mine) ...[
                        const SizedBox(width: 3),
                        Icon(
                          // Sunucuya yazıldıysa tek tik; henüz yazılmadıysa saat.
                          message.timestamp != null
                              ? Icons.done_rounded
                              : Icons.access_time_rounded,
                          size: 13,
                          color: Colors.white.withValues(alpha: 0.6),
                        ),
                      ],
                    ],
                  ),
                ],
              ),
            ),
          ),
        ),
      ); // _ChatBubble bubble

    return Container(
      margin: const EdgeInsets.symmetric(vertical: 3),
      constraints: BoxConstraints(
        maxWidth: MediaQuery.sizeOf(context).width * 0.86,
      ),
      child: Row(
        mainAxisAlignment:
            mine ? MainAxisAlignment.end : MainAxisAlignment.start,
        crossAxisAlignment: CrossAxisAlignment.end,
        mainAxisSize: MainAxisSize.min,
        children: mine
            ? [bubble, const SizedBox(width: 6), avatar]
            : [avatar, const SizedBox(width: 6), bubble],
      ),
    );
  }
}

/// [Admin] rozeti — amber, küçük.
class _AdminBadge extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 5, vertical: 1),
      decoration: BoxDecoration(
        color: const Color(0xFFFFC107).withValues(alpha: 0.22),
        borderRadius: BorderRadius.circular(5),
        border: Border.all(color: const Color(0xFFFFC107).withValues(alpha: 0.6)),
      ),
      child: Text(
        'chat.role.admin'.tr,
        style: const TextStyle(
          color: Color(0xFFFFD54F),
          fontSize: 9.5,
          fontWeight: FontWeight.w900,
          letterSpacing: 0.3,
        ),
      ),
    );
  }
}

/// Balon içindeki "yanıtlanan mesaj" alıntı kutusu.
class _ReplyQuote extends StatelessWidget {
  const _ReplyQuote({
    required this.name,
    required this.text,
    required this.accent,
  });

  final String name;
  final String text;
  final Color accent;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.fromLTRB(8, 5, 8, 5),
      decoration: BoxDecoration(
        color: Colors.black.withValues(alpha: 0.22),
        borderRadius: BorderRadius.circular(8),
        border: Border(left: BorderSide(color: accent, width: 3)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(
            name,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: TextStyle(
              color: accent,
              fontSize: 11.5,
              fontWeight: FontWeight.w800,
            ),
          ),
          Text(
            text,
            maxLines: 2,
            overflow: TextOverflow.ellipsis,
            style: TextStyle(
              color: Colors.white.withValues(alpha: 0.7),
              fontSize: 12,
            ),
          ),
        ],
      ),
    );
  }
}

/// Gönderenin profil avatarı: Google fotoğrafı varsa onu, yoksa ismin baş
/// harfinden türetilen renkli cam daireyi gösterir.
class _ChatAvatar extends StatelessWidget {
  const _ChatAvatar({
    required this.name,
    required this.photoUrl,
  });

  final String name;
  final String? photoUrl;
  static const double size = 34;

  static const List<Color> _palette = [
    Color(0xFFEF5350),
    Color(0xFFAB47BC),
    Color(0xFF5C6BC0),
    Color(0xFF29B6F6),
    Color(0xFF26A69A),
    Color(0xFF66BB6A),
    Color(0xFFFFA726),
    Color(0xFF8D6E63),
  ];

  String get _initials {
    final parts =
        name.trim().split(RegExp(r'\s+')).where((p) => p.isNotEmpty).toList();
    if (parts.isEmpty) return '?';
    if (parts.length == 1) {
      return parts.first.characters.first.toUpperCase();
    }
    return (parts.first.characters.first + parts[1].characters.first)
        .toUpperCase();
  }

  Color get _bgColor {
    if (name.isEmpty) return _palette.first;
    return _palette[name.hashCode.abs() % _palette.length];
  }

  @override
  Widget build(BuildContext context) {
    final fallback = Container(
      width: size,
      height: size,
      alignment: Alignment.center,
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [
            _bgColor.withValues(alpha: 0.95),
            _bgColor.withValues(alpha: 0.6),
          ],
        ),
        border: Border.all(color: Colors.white.withValues(alpha: 0.22)),
      ),
      child: Text(
        _initials,
        style: TextStyle(
          color: Colors.white,
          fontSize: size * 0.4,
          fontWeight: FontWeight.w800,
        ),
      ),
    );

    if (photoUrl == null) return fallback;
    return ClipOval(
      child: CachedNetworkImage(
        imageUrl: photoUrl!,
        width: size,
        height: size,
        fit: BoxFit.cover,
        fadeInDuration: Duration.zero,
        placeholder: (_, __) => fallback,
        errorWidget: (_, __, ___) => fallback,
      ),
    );
  }
}

/// Mesaja uzun basınca açılan cam stilli eylem menüsü (yanıtla / kopyala / sil).
class _MessageActionSheet extends StatelessWidget {
  const _MessageActionSheet({
    required this.canDelete,
    required this.deleteLabel,
    required this.onReply,
    required this.onCopy,
    required this.onDelete,
  });

  final bool canDelete;
  final String deleteLabel;
  final VoidCallback onReply;
  final VoidCallback onCopy;
  final VoidCallback? onDelete;

  @override
  Widget build(BuildContext context) {
    return SafeArea(
      child: Padding(
        padding: const EdgeInsets.fromLTRB(12, 8, 12, 12),
        child: ClipRRect(
          borderRadius: BorderRadius.circular(18),
          child: BackdropFilter(
            filter: ImageFilter.blur(sigmaX: 18, sigmaY: 18),
            child: Container(
              decoration: BoxDecoration(
                color: Colors.black.withValues(alpha: 0.55),
                borderRadius: BorderRadius.circular(18),
                border: Border.all(color: Colors.white.withValues(alpha: 0.16)),
              ),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  _SheetAction(
                    icon: Icons.reply_rounded,
                    label: 'chat.msg.reply'.tr,
                    onTap: onReply,
                  ),
                  Divider(
                    height: 1,
                    color: Colors.white.withValues(alpha: 0.1),
                  ),
                  _SheetAction(
                    icon: Icons.copy_rounded,
                    label: 'chat.msg.copy'.tr,
                    onTap: onCopy,
                  ),
                  if (canDelete && onDelete != null) ...[
                    Divider(
                      height: 1,
                      color: Colors.white.withValues(alpha: 0.1),
                    ),
                    _SheetAction(
                      icon: Icons.delete_outline_rounded,
                      label: deleteLabel,
                      destructive: true,
                      onTap: onDelete!,
                    ),
                  ],
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}

/// Yayın durumu etiketini seçtiren cam stilli alt menü. Seçim yapılırsa
/// [ChatStatusTag], "temizle" seçilirse `'clear'`, kapatılırsa `null` döner.
class _StatusTagSheet extends StatelessWidget {
  const _StatusTagSheet({required this.current});

  final ChatStatusTag? current;

  @override
  Widget build(BuildContext context) {
    return SafeArea(
      child: Padding(
        padding: const EdgeInsets.fromLTRB(12, 8, 12, 12),
        child: ClipRRect(
          borderRadius: BorderRadius.circular(18),
          child: BackdropFilter(
            filter: ImageFilter.blur(sigmaX: 18, sigmaY: 18),
            child: Container(
              decoration: BoxDecoration(
                color: Colors.black.withValues(alpha: 0.55),
                borderRadius: BorderRadius.circular(18),
                border: Border.all(color: Colors.white.withValues(alpha: 0.16)),
              ),
              padding: const EdgeInsets.symmetric(vertical: 6),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Padding(
                    padding: const EdgeInsets.fromLTRB(18, 8, 18, 6),
                    child: Align(
                      alignment: AlignmentDirectional.centerStart,
                      child: Text(
                        'chat.tag.title'.tr,
                        style: TextStyle(
                          color: Colors.white.withValues(alpha: 0.7),
                          fontSize: 12.5,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                    ),
                  ),
                  for (final tag in ChatStatusTag.values)
                    _SheetAction(
                      icon: _statusTagIcon(tag),
                      iconColor: _statusTagColor(tag),
                      label: tag.labelKey.tr,
                      selected: tag == current,
                      onTap: () => Navigator.of(context).pop(tag),
                    ),
                  if (current != null) ...[
                    Divider(
                      height: 1,
                      color: Colors.white.withValues(alpha: 0.1),
                    ),
                    _SheetAction(
                      icon: Icons.clear_rounded,
                      label: 'chat.tag.clear'.tr,
                      onTap: () => Navigator.of(context).pop('clear'),
                    ),
                  ],
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}

/// Yayın durumu etiketi çipi (composer'da veya balonda).
class _StatusChip extends StatelessWidget {
  const _StatusChip({required this.tag, this.onClear});

  final ChatStatusTag tag;
  final VoidCallback? onClear;

  @override
  Widget build(BuildContext context) {
    final color = _statusTagColor(tag);
    return Container(
      padding: EdgeInsets.fromLTRB(8, 4, onClear != null ? 4 : 8, 4),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.18),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: color.withValues(alpha: 0.55)),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(_statusTagIcon(tag), size: 14, color: color),
          const SizedBox(width: 5),
          Text(
            tag.labelKey.tr,
            style: TextStyle(
              color: Colors.white.withValues(alpha: 0.95),
              fontSize: 11.5,
              fontWeight: FontWeight.w700,
            ),
          ),
          if (onClear != null)
            GestureDetector(
              onTap: onClear,
              child: Padding(
                padding: const EdgeInsets.only(left: 4),
                child: Icon(Icons.close_rounded,
                    size: 14, color: Colors.white.withValues(alpha: 0.7)),
              ),
            ),
        ],
      ),
    );
  }
}

Color _statusTagColor(ChatStatusTag tag) => switch (tag) {
      ChatStatusTag.flowing => const Color(0xFF66BB6A),
      ChatStatusTag.noFreeze => const Color(0xFF26A69A),
      ChatStatusTag.freeze => const Color(0xFFFFA726),
      ChatStatusTag.down => const Color(0xFFEF5350),
    };

IconData _statusTagIcon(ChatStatusTag tag) => switch (tag) {
      ChatStatusTag.flowing => Icons.play_circle_fill_rounded,
      ChatStatusTag.noFreeze => Icons.check_circle_rounded,
      ChatStatusTag.freeze => Icons.ac_unit_rounded,
      ChatStatusTag.down => Icons.error_rounded,
    };

class _SheetAction extends StatelessWidget {
  const _SheetAction({
    required this.icon,
    required this.label,
    required this.onTap,
    this.destructive = false,
    this.iconColor,
    this.selected = false,
  });

  final IconData icon;
  final String label;
  final VoidCallback onTap;
  final bool destructive;
  final Color? iconColor;
  final bool selected;

  @override
  Widget build(BuildContext context) {
    final textColor = destructive ? const Color(0xFFFF6B6B) : Colors.white;
    final icColor = iconColor ?? textColor;
    return Material(
      color: selected ? Colors.white.withValues(alpha: 0.08) : Colors.transparent,
      child: InkWell(
        onTap: onTap,
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 16),
          child: Row(
            children: [
              Icon(icon, color: icColor, size: 22),
              const SizedBox(width: 14),
              Expanded(
                child: Text(
                  label,
                  style: TextStyle(
                    color: textColor,
                    fontSize: 15,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ),
              if (selected)
                Icon(Icons.check_rounded,
                    size: 18, color: Colors.white.withValues(alpha: 0.8)),
            ],
          ),
        ),
      ),
    );
  }
}

/// Alt mesaj yazma çubuğu (cam stili) — reply alıntısı, yayın durumu etiketi
/// ve metin girişi. Yalnızca metin + emoji (medya butonu yok).
class _Composer extends StatelessWidget {
  const _Composer({
    required this.controller,
    required this.focusNode,
    required this.sending,
    required this.onSend,
    required this.replyTo,
    required this.onCancelReply,
    required this.statusTag,
    required this.onPickStatusTag,
    required this.onClearStatusTag,
    this.allowStatusTag = true,
  });

  final TextEditingController controller;
  final FocusNode focusNode;
  final bool sending;
  final VoidCallback onSend;
  final ChatMessage? replyTo;
  final VoidCallback onCancelReply;
  final ChatStatusTag? statusTag;
  final VoidCallback onPickStatusTag;
  final VoidCallback onClearStatusTag;

  /// Yayın durumu etiketi butonu gösterilsin mi? (Destek modunda gizli.)
  final bool allowStatusTag;

  @override
  Widget build(BuildContext context) {
    final primary = Theme.of(context).colorScheme.primary;
    return Padding(
      padding: const EdgeInsets.fromLTRB(10, 6, 10, 10),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          if (replyTo != null)
            _ReplyPreview(message: replyTo!, onCancel: onCancelReply),
          if (allowStatusTag && statusTag != null)
            Padding(
              padding: const EdgeInsets.only(bottom: 6),
              child: Align(
                alignment: Alignment.centerLeft,
                child: _StatusChip(
                  tag: statusTag!,
                  onClear: onClearStatusTag,
                ),
              ),
            ),
          ClipRRect(
            borderRadius: BorderRadius.circular(24),
            child: BackdropFilter(
              filter: ImageFilter.blur(sigmaX: 10, sigmaY: 10),
              child: Container(
                decoration: BoxDecoration(
                  color: Colors.white.withValues(alpha: 0.08),
                  borderRadius: BorderRadius.circular(24),
                  border:
                      Border.all(color: Colors.white.withValues(alpha: 0.16)),
                ),
                padding: const EdgeInsets.fromLTRB(6, 2, 6, 2),
                child: Row(
                  children: [
                    if (allowStatusTag)
                      IconButton(
                        onPressed: onPickStatusTag,
                        icon: Icon(
                          Icons.cell_tower_rounded,
                          color: statusTag != null
                              ? primary
                              : Colors.white.withValues(alpha: 0.6),
                        ),
                        tooltip: 'chat.tag.pick'.tr,
                      )
                    else
                      const SizedBox(width: 10),
                    Expanded(
                      child: TextField(
                        controller: controller,
                        focusNode: focusNode,
                        minLines: 1,
                        maxLines: 4,
                        maxLength: ChatService.maxMessageLength,
                        textInputAction: TextInputAction.send,
                        onSubmitted: (_) => onSend(),
                        style: const TextStyle(
                            color: Colors.white, fontSize: 14.5),
                        cursorColor: primary,
                        decoration: InputDecoration(
                          counterText: '',
                          border: InputBorder.none,
                          hintText: 'chat.composer.hint'.tr,
                          hintStyle: TextStyle(
                            color: Colors.white.withValues(alpha: 0.45),
                          ),
                        ),
                      ),
                    ),
                    IconButton(
                      onPressed: sending ? null : onSend,
                      icon: sending
                          ? const SizedBox(
                              width: 20,
                              height: 20,
                              child: CircularProgressIndicator(strokeWidth: 2),
                            )
                          : Icon(Icons.send_rounded, color: primary),
                      tooltip: 'chat.composer.send'.tr,
                    ),
                  ],
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

/// Composer üstünde gösterilen "yanıtlanıyor" alıntı önizlemesi.
class _ReplyPreview extends StatelessWidget {
  const _ReplyPreview({required this.message, required this.onCancel});

  final ChatMessage message;
  final VoidCallback onCancel;

  @override
  Widget build(BuildContext context) {
    final primary = Theme.of(context).colorScheme.primary;
    return Container(
      margin: const EdgeInsets.only(bottom: 6),
      padding: const EdgeInsets.fromLTRB(10, 8, 6, 8),
      decoration: BoxDecoration(
        color: Colors.white.withValues(alpha: 0.06),
        borderRadius: BorderRadius.circular(12),
        border: Border(
          left: BorderSide(color: primary, width: 3),
        ),
      ),
      child: Row(
        children: [
          Icon(Icons.reply_rounded,
              size: 18, color: primary.withValues(alpha: 0.9)),
          const SizedBox(width: 8),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  message.senderName,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(
                    color: primary.withValues(alpha: 0.95),
                    fontSize: 12,
                    fontWeight: FontWeight.w800,
                  ),
                ),
                Text(
                  message.messageText,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(
                    color: Colors.white.withValues(alpha: 0.7),
                    fontSize: 12.5,
                  ),
                ),
              ],
            ),
          ),
          IconButton(
            onPressed: onCancel,
            icon: Icon(Icons.close_rounded,
                size: 18, color: Colors.white.withValues(alpha: 0.6)),
            tooltip: 'common.cancel'.tr,
            visualDensity: VisualDensity.compact,
          ),
        ],
      ),
    );
  }
}
