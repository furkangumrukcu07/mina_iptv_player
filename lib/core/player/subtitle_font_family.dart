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

SubtitleFontFamilyOption subtitleFontFamilyOptionForKey(String key) {
  for (final o in kSubtitleFontFamilyOptions) {
    if (o.key == key) return o;
  }
  return kSubtitleFontFamilyOptions.first;
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

String appFontFamilyLabelFor(String key) => subtitleFontFamilyOptionForKey(key).label;

String appFontFamilyPreviewFor(String key) =>
    subtitleFontFamilyOptionForKey(key).preview;

bool isValidAppFontFamilyKey(String key) => isValidSubtitleFontFamilyKey(key);
