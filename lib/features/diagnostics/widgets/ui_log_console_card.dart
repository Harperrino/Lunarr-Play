import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:m3uxtream_player/shared/widgets/app_surface.dart';

/// Reusable diagnostic log panel.
class UiLogConsoleCard extends StatefulWidget {
  const UiLogConsoleCard({
    super.key,
    required this.logs,
    required this.onClear,
  });

  final List<String> logs;
  final VoidCallback onClear;

  @override
  State<UiLogConsoleCard> createState() => _UiLogConsoleCardState();
}

class _UiLogConsoleCardState extends State<UiLogConsoleCard> {
  late final ScrollController _scrollController;

  @override
  void initState() {
    super.initState();
    _scrollController = ScrollController();
  }

  @override
  void didUpdateWidget(UiLogConsoleCard oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (!listEquals(widget.logs, oldWidget.logs)) {
      WidgetsBinding.instance.addPostFrameCallback((_) => _scrollToEnd());
    }
  }

  @override
  void dispose() {
    _scrollController.dispose();
    super.dispose();
  }

  void _scrollToEnd() {
    if (!_scrollController.hasClients) return;
    final target = _scrollController.position.maxScrollExtent;
    final duration = MediaQuery.disableAnimationsOf(context)
        ? Duration.zero
        : const Duration(milliseconds: 200);
    if (duration == Duration.zero) {
      _scrollController.jumpTo(target);
      return;
    }
    _scrollController.animateTo(
      target,
      duration: duration,
      curve: Curves.easeOut,
    );
  }

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).colorScheme;
    return AppSurface(
      level: AppSurfaceLevel.high,
      padding: const EdgeInsets.all(24.0),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(
                Icons.terminal_rounded,
                color: Theme.of(context).colorScheme.tertiary,
                size: 24,
              ),
              const SizedBox(width: 12),
              Text(
                'SYSTEM REAL-TIME DIAGNOSTIC',
                style: Theme.of(
                  context,
                ).textTheme.titleLarge?.copyWith(fontSize: 14),
              ),
              const Spacer(),
              TextButton(
                onPressed: widget.onClear,
                child: Text(
                  'Clear',
                  style: TextStyle(
                    fontSize: 12,
                    color: colors.onSurfaceVariant,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),
          Expanded(
            child: AppSurface(
              level: AppSurfaceLevel.base,
              padding: const EdgeInsets.all(12),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(10),
              ),
              child: ListView.builder(
                controller: _scrollController,
                itemCount: widget.logs.length,
                itemBuilder: (context, idx) {
                  return Padding(
                    padding: const EdgeInsets.symmetric(vertical: 4.0),
                    child: Text(
                      widget.logs[idx],
                      style: const TextStyle(
                        fontFamily: 'monospace',
                        fontSize: 11,
                      ).copyWith(color: colors.onSurface),
                    ),
                  );
                },
              ),
            ),
          ),
          const SizedBox(height: 12),
          Text(
            'Press [Space] for Play/Pause, [F] for Fullscreen, [+/-] for Volume, [Arrow keys] to change channel.',
            style: TextStyle(fontSize: 10, color: colors.onSurfaceVariant),
          ),
        ],
      ),
    );
  }
}
