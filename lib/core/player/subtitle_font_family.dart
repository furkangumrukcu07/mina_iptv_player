class SubtitleFontFamilyOption {
  const SubtitleFontFamilyOption({
    required this.key,
    required this.label,
    required this.preview,
    required this.betterPlayerFamily,
    required this.mediaKitFamily,
  });

  final String key;
  final String label;
  final String preview;
  final String betterPlayerFamily;
  final String mediaKitFamily;
}

const String kDefaultSubtitleFontFamilyKey = 'sony';
const String kDefaultAppFontFamilyKey = 'sony';

const List<SubtitleFontFamilyOption> kSubtitleFontFamilyOptions = [
  // "Sony" burada marka/tarz seçeneği olarak sistem sans fontuna eşlenir.
  SubtitleFontFamilyOption(
    key: 'sony',
    label: 'Sony',
    preview: 'Sony (TV tarzı)',
    betterPlayerFamily: 'sans-serif-medium',
    mediaKitFamily: 'sans-serif',
  ),
  SubtitleFontFamilyOption(
    key: 'roboto',
    label: 'Roboto',
    preview: 'Roboto (açık lisans)',
    betterPlayerFamily: 'Roboto',
    mediaKitFamily: 'Roboto',
  ),
  SubtitleFontFamilyOption(
    key: 'noto',
    label: 'Noto Sans',
    preview: 'Noto Sans (açık lisans)',
    betterPlayerFamily: 'Noto Sans',
    mediaKitFamily: 'Noto Sans',
  ),
  SubtitleFontFamilyOption(
    key: 'mono',
    label: 'Monospace',
    preview: 'Monospace (sistem)',
    betterPlayerFamily: 'monospace',
    mediaKitFamily: 'monospace',
  ),
];

/// Uygulama arayüzü fontu seçenekleri. Altyazı listesine ek olarak Google
/// Fonts tabanlı arayüz fontlarını içerir (altyazı oynatıcısı bu fontları
/// gömmediği için yalnızca arayüzde kullanılır).
const List<SubtitleFontFamilyOption> kAppFontFamilyOptions = [
  ...kSubtitleFontFamilyOptions,
  SubtitleFontFamilyOption(
    key: 'roboto_flex',
    label: 'Roboto Flex',
    preview: 'Android / Google TV yerel tarzı',
    betterPlayerFamily: 'Roboto Flex',
    mediaKitFamily: 'Roboto Flex',
  ),
  SubtitleFontFamilyOption(
    key: 'poppins',
    label: 'Poppins',
    preview: 'Geometrik, yuvarlak — modern & premium',
    betterPlayerFamily: 'Poppins',
    mediaKitFamily: 'Poppins',
  ),
  SubtitleFontFamilyOption(
    key: 'rubik',
    label: 'Rubik',
    preview: 'Yumuşak köşeli — TV ekranında rahat',
    betterPlayerFamily: 'Rubik',
    mediaKitFamily: 'Rubik',
  ),
  SubtitleFontFamilyOption(
    key: 'montserrat',
    label: 'Montserrat',
    preview: 'Güçlü başlık fontu — sinematik',
    betterPlayerFamily: 'Montserrat',
    mediaKitFamily: 'Montserrat',
  ),
];

SubtitleFontFamilyOption subtitleFontFamilyOptionForKey(String key) {
  for (final o in kSubtitleFontFamilyOptions) {
    if (o.key == key) return o;
  }
  return kSubtitleFontFamilyOptions.first;
}

SubtitleFontFamilyOption appFontFamilyOptionForKey(String key) {
  for (final o in kAppFontFamilyOptions) {
    if (o.key == key) return o;
  }
  return kAppFontFamilyOptions.first;
}

bool isValidSubtitleFontFamilyKey(String key) {
  for (final o in kSubtitleFontFamilyOptions) {
    if (o.key == key) return true;
  }
  return false;
}

String betterPlayerSubtitleFontFamilyFor(String key) =>
    subtitleFontFamilyOptionForKey(key).betterPlayerFamily;

String mediaKitSubtitleFontFamilyFor(String key) =>
    subtitleFontFamilyOptionForKey(key).mediaKitFamily;

String appFontFamilyLabelFor(String key) =>
    appFontFamilyOptionForKey(key).label;

String appFontFamilyPreviewFor(String key) =>
    appFontFamilyOptionForKey(key).preview;

bool isValidAppFontFamilyKey(String key) {
  for (final o in kAppFontFamilyOptions) {
    if (o.key == key) return true;
  }
  return false;
}
