import 'package:m3uxtream_player/features/search/models/category_search_result.dart';
import 'package:m3uxtream_player/features/search/models/channel_search_result.dart';
import 'package:m3uxtream_player/features/search/models/search_overlay_filter.dart';

class GlobalSearchResultItem {
  const GlobalSearchResultItem.channel(this.channel) : category = null;
  const GlobalSearchResultItem.category(this.category) : channel = null;

  final ChannelSearchResult? channel;
  final CategorySearchResult? category;

  bool get isChannel => channel != null;
}

class GlobalSearchResults {
  const GlobalSearchResults({required this.channels, required this.categories});

  final List<ChannelSearchResult> channels;
  final List<CategorySearchResult> categories;

  List<GlobalSearchResultItem> itemsFor(SearchOverlayFilter filter) {
    if (filter == SearchOverlayFilter.channels) {
      return channels
          .take(12)
          .map(GlobalSearchResultItem.channel)
          .toList(growable: false);
    }
    if (filter == SearchOverlayFilter.categories) {
      return categories
          .take(12)
          .map(GlobalSearchResultItem.category)
          .toList(growable: false);
    }

    final items = <GlobalSearchResultItem>[];
    final initialChannels = channels
        .take(8)
        .map(GlobalSearchResultItem.channel);
    final initialCategories = categories
        .take(4)
        .map(GlobalSearchResultItem.category);
    items.addAll(initialChannels);
    items.addAll(initialCategories);

    for (final channel in channels.skip(8)) {
      if (items.length >= 12) break;
      items.add(GlobalSearchResultItem.channel(channel));
    }
    for (final category in categories.skip(4)) {
      if (items.length >= 12) break;
      items.add(GlobalSearchResultItem.category(category));
    }
    return items;
  }
}
