/// Merges [patch] over [base] for partial locale files (fallback: English).
Map<String, String> mergeTranslations(
  Map<String, String> base,
  Map<String, String> patch,
) {
  return {...base, ...patch};
}
