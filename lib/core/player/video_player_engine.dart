/// Oynatıcı sayfasında o an aktif olan video motoru.
///
/// Tek bir gerçek kaynak: [PlayerController.activeVideoEngine] bunu
/// `effectiveUseMediaKit` üzerinden türetir. Hem [UniversalVideoPlayer]
/// (yüzey render'ı + dispose) hem de OSD/butonlar bu enum'a göre çalışır;
/// böylece "hangi motor aktif" sorusunun tek ve net cevabı olur.
enum VideoPlayerEngine {
  /// ExoPlayer tabanlı Better Player.
  betterPlayer,

  /// libmpv tabanlı media_kit.
  mediaKit;

  bool get isMediaKit => this == VideoPlayerEngine.mediaKit;
  bool get isBetterPlayer => this == VideoPlayerEngine.betterPlayer;

  static VideoPlayerEngine fromUseMediaKit(bool useMediaKit) =>
      useMediaKit ? VideoPlayerEngine.mediaKit : VideoPlayerEngine.betterPlayer;
}
