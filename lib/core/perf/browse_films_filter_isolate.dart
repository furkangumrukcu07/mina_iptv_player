import 'package:flutter/foundation.dart';

/// Film listesi filtreleme girdisi — isolate'e gönderilebilir hafif DTO.
class BrowseFilmsFilterInput {
  const BrowseFilmsFilterInput({
    required this.vodIds,
    required this.vodNamesLower,
    required this.vodCategoryIds,
    required this.categoryKey,
    required this.searchQueryLower,
    required this.recentVodIds,
    required this.watchedVodIds,
    required this.hiddenCategoryIds,
    required this.isAllCategories,
    required this.isRecentCategory,
    required this.isWatchedCategory,
    this.filterAdultItems = false,
    this.adultTokens = const <String>[],
  });

  final List<int> vodIds;
  final List<String> vodNamesLower;
  final List<int> vodCategoryIds;
  final int categoryKey;
  final String searchQueryLower;
  final List<int> recentVodIds;
  final List<int> watchedVodIds;
  final Set<int> hiddenCategoryIds;
  final bool isAllCategories;
  final bool isRecentCategory;
  final bool isWatchedCategory;
  final bool filterAdultItems;
  final List<String> adultTokens;
}

bool _isAdultName(String name, List<String> tokens) {
  if (name.contains('🔞')) return true;
  for (final t in tokens) {
    if (name.contains(t)) return true;
  }
  return false;
}

/// Filtrelenmiş VOD id listesi — ana thread'de [BrowseCatalogIndex] ile hydrate.
List<int> browseFilmsFilterIsolate(BrowseFilmsFilterInput input) {
  final n = input.vodIds.length;
  if (n == 0) return const [];

  Iterable<int> indices = Iterable<int>.generate(n);

  if (input.isWatchedCategory && input.searchQueryLower.isEmpty) {
    final byId = <int, int>{};
    for (var i = 0; i < n; i++) {
      byId[input.vodIds[i]] = i;
    }
    final out = <int>[];
    for (final id in input.watchedVodIds) {
      final idx = byId[id];
      if (idx == null) continue;
      if (input.hiddenCategoryIds.contains(input.vodCategoryIds[idx])) {
        continue;
      }
      if (input.filterAdultItems &&
          _isAdultName(input.vodNamesLower[idx], input.adultTokens)) {
        continue;
      }
      out.add(id);
    }
    return out;
  }

  if (input.isRecentCategory && input.searchQueryLower.isEmpty) {
    final recent = input.recentVodIds.toSet();
    indices = indices.where((i) => recent.contains(input.vodIds[i]));
  } else if (!input.isAllCategories &&
      input.searchQueryLower.isEmpty &&
      !input.isRecentCategory) {
    final key = input.categoryKey;
    indices = indices.where((i) => input.vodCategoryIds[i] == key);
  }

  if (input.searchQueryLower.isEmpty &&
      input.isAllCategories &&
      !input.isRecentCategory &&
      !input.isWatchedCategory) {
    indices = indices.where(
      (i) => !input.hiddenCategoryIds.contains(input.vodCategoryIds[i]),
    );
  }

  if (input.searchQueryLower.isNotEmpty) {
    final q = input.searchQueryLower;
    indices = indices.where((i) => input.vodNamesLower[i].contains(q));
  }

  if (input.filterAdultItems) {
    final tokens = input.adultTokens;
    indices = indices.where(
      (i) => !input.hiddenCategoryIds.contains(input.vodCategoryIds[i]) &&
          !_isAdultName(input.vodNamesLower[i], tokens),
    );
  }

  return [for (final i in indices) input.vodIds[i]];
}

Future<List<int>> browseFilmsFilterAsync(BrowseFilmsFilterInput input) {
  if (input.vodIds.length < 2500) {
    return Future.value(browseFilmsFilterIsolate(input));
  }
  return compute(browseFilmsFilterIsolate, input);
}
