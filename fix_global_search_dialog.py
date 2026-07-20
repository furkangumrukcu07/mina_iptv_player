import sys
import re

file_path = 'lib/modules/home/widgets/global_search_dialog.dart'

with open(file_path, 'r', encoding='utf-8') as f:
    content = f.read()

old_build_results_list = '''  Widget _buildResultsList() {
    final buckets = _results!;
    final total =
        buckets.channels.length + buckets.vods.length + buckets.series.length;

    if (total == 0) {
      return const SizedBox.shrink();
    }

    _syncResultFocusNodes(total);
    var row = 0;

    return ListView(
      controller: _scrollController,
      padding: const EdgeInsets.fromLTRB(8, 0, 8, 16),
      children: [
        if (buckets.channels.isNotEmpty) ...[
          _buildHeader('home.live'.tr),
          ...buckets.channels.map((ch) {
            final tile = _buildChannelTile(ch, row);
            row++;
            return tile;
          }),
        ],
        if (buckets.vods.isNotEmpty) ...[
          _buildHeader('home.films'.tr),
          ...buckets.vods.map((v) {
            final tile = _buildVodTile(v, row);
            row++;
            return tile;
          }),
        ],
        if (buckets.series.isNotEmpty) ...[
          _buildHeader('home.series'.tr),
          ...buckets.series.map((s) {
            final tile = _buildSeriesTile(s, row);
            row++;
            return tile;
          }),
        ],
      ],
    );
  }'''

new_build_results_list = '''  Widget _buildResultsList() {
    final buckets = _results!;
    final total =
        buckets.channels.length + buckets.vods.length + buckets.series.length;

    if (total == 0) {
      return const SizedBox.shrink();
    }

    _syncResultFocusNodes(total);
    
    final items = <Object>[];
    if (buckets.channels.isNotEmpty) {
      items.add('home.live'.tr);
      items.addAll(buckets.channels);
    }
    if (buckets.vods.isNotEmpty) {
      items.add('home.films'.tr);
      items.addAll(buckets.vods);
    }
    if (buckets.series.isNotEmpty) {
      items.add('home.series'.tr);
      items.addAll(buckets.series);
    }

    return ListView.builder(
      controller: _scrollController,
      padding: const EdgeInsets.fromLTRB(8, 0, 8, 16),
      itemCount: items.length,
      itemBuilder: (context, index) {
        final item = items[index];
        if (item is String) return _buildHeader(item);
        
        int row = 0;
        for (int i = 0; i < index; i++) {
          if (items[i] is! String) row++;
        }
        
        if (item is Channel) return _buildChannelTile(item, row);
        if (item is VodItem) return _buildVodTile(item, row);
        if (item is SeriesItem) return _buildSeriesTile(item, row);
        return const SizedBox.shrink();
      },
    );
  }'''

content = content.replace(old_build_results_list, new_build_results_list)

with open(file_path, 'w', encoding='utf-8') as f:
    f.write(content)
print("Successfully replaced global_search_dialog Listview")
