import 'package:flutter/widgets.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:m3uxtream_player/features/epg/providers/visible_live_channel_registry.dart';

/// Registers its channel projection as built (visible or prerendered) for the
/// bounded Live EPG pipeline and unregisters again on dispose.
///
/// The list must key this row with `ValueKey(channel.id)` so Flutter binds
/// one element to exactly one channel across catalogue switches.
class VisibleLiveChannelRow extends ConsumerStatefulWidget {
  const VisibleLiveChannelRow({
    super.key,
    required this.candidate,
    required this.child,
  });

  final VisibleLiveChannelCandidate candidate;
  final Widget child;

  @override
  ConsumerState<VisibleLiveChannelRow> createState() =>
      _VisibleLiveChannelRowState();
}

class _VisibleLiveChannelRowState extends ConsumerState<VisibleLiveChannelRow> {
  late final VisibleLiveChannelRegistry _registry;

  @override
  void initState() {
    super.initState();
    // The registry instance is captured here because "ref" is already
    // invalid by the time [dispose] runs.
    _registry = ref.read(visibleLiveChannelRegistryProvider);
    _registry.register(widget.candidate);
  }

  @override
  void dispose() {
    _registry.unregister(widget.candidate.channelId);
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => widget.child;
}
