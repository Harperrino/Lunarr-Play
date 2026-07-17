import 'package:m3uxtream_player/core/constants/filter_constants.dart';
import 'package:m3uxtream_player/core/database/app_database.dart';

String normalizeGroupName(String? groupName) {
  if (groupName == null || groupName.isEmpty) return kUncategorizedGroupLabel;
  return groupName;
}

List<String> distinctSortedGroups(Iterable<Channel> channels) {
  return channels.map((c) => normalizeGroupName(c.groupName)).toSet().toList()
    ..sort();
}

List<Channel> filterChannelsByGroup(
  List<Channel> channels,
  String groupFilter,
) {
  if (groupFilter == kAllGroupsFilter) return channels;
  if (groupFilter == kUncategorizedGroupLabel) {
    return channels
        .where((c) => c.groupName == null || c.groupName!.isEmpty)
        .toList();
  }
  return channels.where((c) => c.groupName == groupFilter).toList();
}

List<Channel> filterChannelsBySearch(List<Channel> channels, String query) {
  final trimmed = query.trim().toLowerCase();
  if (trimmed.isEmpty) return channels;
  return channels.where((c) {
    final name = c.name.toLowerCase();
    final group = (c.groupName ?? '').toLowerCase();
    return name.contains(trimmed) || group.contains(trimmed);
  }).toList();
}

List<Channel> filterChannelsByHiddenGroups(
  List<Channel> channels,
  Set<String> hiddenGroups,
) {
  if (hiddenGroups.isEmpty) return channels;
  return channels
      .where((c) => !hiddenGroups.contains(normalizeGroupName(c.groupName)))
      .toList();
}

List<Channel> filterChannelsByType(
  List<Channel> channels,
  String? channelType,
) {
  if (channelType == null || channelType.isEmpty) return channels;
  return channels
      .where((channel) => channel.channelType == channelType)
      .toList();
}

/// Applies the catalogue filters in one pass.
///
/// The narrower helpers above stay available for focused call sites and tests,
/// while catalogue providers use this function to avoid allocating an
/// intermediate list for every active filter.
List<Channel> filterChannels({
  required List<Channel> channels,
  String groupFilter = kAllGroupsFilter,
  String searchQuery = '',
  Set<String> hiddenGroups = const <String>{},
  String? channelType,
}) {
  final normalizedSearch = searchQuery.trim().toLowerCase();
  final filterByGroup = groupFilter != kAllGroupsFilter;
  final filterByType = channelType != null && channelType.isNotEmpty;

  if (!filterByGroup &&
      normalizedSearch.isEmpty &&
      hiddenGroups.isEmpty &&
      !filterByType) {
    return channels;
  }

  return channels
      .where((channel) {
        final normalizedGroup = normalizeGroupName(channel.groupName);

        if (hiddenGroups.contains(normalizedGroup)) return false;
        if (filterByType && channel.channelType != channelType) return false;
        if (filterByGroup && normalizedGroup != groupFilter) return false;

        if (normalizedSearch.isEmpty) return true;
        return channel.name.toLowerCase().contains(normalizedSearch) ||
            (channel.groupName ?? '').toLowerCase().contains(normalizedSearch);
      })
      .toList(growable: false);
}

List<String> visibleGroups(List<String> groups, Set<String> hiddenGroups) {
  if (hiddenGroups.isEmpty) return groups;
  return groups.where((g) => !hiddenGroups.contains(g)).toList();
}

List<String> prioritizePinnedGroups(
  List<String> groups,
  List<String> pinnedGroups,
) {
  if (groups.isEmpty || pinnedGroups.isEmpty) return groups;

  final available = groups.toSet();
  final result = <String>[];
  final added = <String>{};

  for (final pinned in pinnedGroups) {
    if (available.contains(pinned) && added.add(pinned)) {
      result.add(pinned);
    }
  }

  for (final group in groups) {
    if (added.add(group)) {
      result.add(group);
    }
  }

  return result;
}
