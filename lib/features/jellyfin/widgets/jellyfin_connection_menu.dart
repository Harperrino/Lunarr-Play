import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:m3uxtream_player/features/jellyfin/auth/jellyfin_connection.dart';
import 'package:m3uxtream_player/features/jellyfin/providers/jellyfin_connection_providers.dart';
import 'package:m3uxtream_player/features/jellyfin/providers/jellyfin_library_providers.dart';
import 'package:m3uxtream_player/l10n/l10n.dart';
import 'package:m3uxtream_player/shared/widgets/app_surface.dart';

/// Account/server selector that replaces the playlist selector in Jellyfin.
class JellyfinConnectionMenu extends ConsumerWidget {
  const JellyfinConnectionMenu({super.key, required this.availableWidth});

  final double availableWidth;

  static double widthFor(double width) {
    if (width < 1080) return 48;
    if (width < 1240) return 196;
    return 248;
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final width = widthFor(availableWidth);
    final iconOnly = availableWidth < 1080;
    final compact = availableWidth < 1240;
    final session = ref.watch(jellyfinSessionControllerProvider);
    final connections =
        ref.watch(jellyfinConnectionsProvider).valueOrNull ??
        const <JellyfinConnection>[];
    final active = session is JellyfinAuthenticated ? session.connection : null;
    late MenuController controller;

    return SizedBox(
      width: width,
      child: MenuAnchor(
        menuChildren: [
          _ConnectionMenuSurface(
            connections: connections,
            selectedId: active?.credentialId,
            onSelect: (connection) async {
              await ref
                  .read(jellyfinSessionControllerProvider.notifier)
                  .selectConnection(connection);
              jellyfinSelectOverview(ref);
              controller.close();
            },
            onAdd: () {
              ref
                  .read(jellyfinSessionControllerProvider.notifier)
                  .startAddingConnection();
              controller.close();
            },
          ),
        ],
        builder: (context, menuController, child) {
          controller = menuController;
          return _ConnectionTrigger(
            width: width,
            iconOnly: iconOnly,
            compact: compact,
            label: active == null
                ? context.l10n.jellyfinConnectionMenuChoose
                : '${active.username} · ${_host(active.baseUrl)}',
            onPressed: () =>
                controller.isOpen ? controller.close() : controller.open(),
          );
        },
      ),
    );
  }

  static String _host(String url) => Uri.tryParse(url)?.host ?? url;
}

class _ConnectionTrigger extends StatelessWidget {
  const _ConnectionTrigger({
    required this.width,
    required this.iconOnly,
    required this.compact,
    required this.label,
    required this.onPressed,
  });

  final double width;
  final bool iconOnly;
  final bool compact;
  final String label;
  final VoidCallback onPressed;

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).colorScheme;
    if (iconOnly) {
      return IconButton(
        tooltip: label,
        onPressed: onPressed,
        icon: Icon(Icons.account_circle_rounded, color: colors.primary),
      );
    }
    return Tooltip(
      message: label,
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          onTap: onPressed,
          borderRadius: BorderRadius.circular(24),
          child: SizedBox(
            width: width,
            height: 48,
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 10),
              child: Row(
                children: [
                  Icon(Icons.account_circle_rounded, color: colors.primary),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      label,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: Theme.of(context).textTheme.labelLarge?.copyWith(
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                  ),
                  if (!compact) const SizedBox(width: 4),
                  const Icon(Icons.expand_more_rounded),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class _ConnectionMenuSurface extends StatelessWidget {
  const _ConnectionMenuSurface({
    required this.connections,
    required this.selectedId,
    required this.onSelect,
    required this.onAdd,
  });

  final List<JellyfinConnection> connections;
  final String? selectedId;
  final Future<void> Function(JellyfinConnection) onSelect;
  final VoidCallback onAdd;

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).colorScheme;
    return AppSurface(
      level: AppSurfaceLevel.high,
      width: 340,
      padding: const EdgeInsets.all(8),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(18)),
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxHeight: 440),
        child: SingleChildScrollView(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Padding(
                padding: const EdgeInsets.fromLTRB(12, 8, 12, 8),
                child: Text(
                  context.l10n.jellyfinConnectionMenuTitle.toUpperCase(),
                  style: TextStyle(
                    fontSize: 11,
                    fontWeight: FontWeight.w800,
                    letterSpacing: 1,
                    color: colors.onSurfaceVariant,
                  ),
                ),
              ),
              if (connections.isEmpty)
                Padding(
                  padding: const EdgeInsets.all(12),
                  child: Text(
                    context.l10n.jellyfinConnectionMenuEmpty,
                    style: TextStyle(color: colors.onSurfaceVariant),
                  ),
                ),
              for (final connection in connections)
                _ConnectionRow(
                  connection: connection,
                  selected: connection.credentialId == selectedId,
                  onTap: () => unawaited(onSelect(connection)),
                ),
              const Divider(height: 20),
              TextButton.icon(
                onPressed: onAdd,
                icon: const Icon(Icons.add_link_rounded),
                label: Text(context.l10n.jellyfinConnectionMenuAdd),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _ConnectionRow extends StatelessWidget {
  const _ConnectionRow({
    required this.connection,
    required this.selected,
    required this.onTap,
  });

  final JellyfinConnection connection;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).colorScheme;
    final host = Uri.tryParse(connection.baseUrl)?.host ?? connection.baseUrl;
    return Material(
      color: selected ? colors.secondaryContainer : Colors.transparent,
      borderRadius: BorderRadius.circular(14),
      child: InkWell(
        borderRadius: BorderRadius.circular(14),
        onTap: onTap,
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 9),
          child: Row(
            children: [
              Icon(
                selected
                    ? Icons.radio_button_checked_rounded
                    : Icons.radio_button_unchecked_rounded,
                size: 18,
                color: selected ? colors.primary : colors.outline,
              ),
              const SizedBox(width: 10),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      connection.username,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(fontWeight: FontWeight.w700),
                    ),
                    Text(
                      host,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(
                        fontSize: 11,
                        color: colors.onSurfaceVariant,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
