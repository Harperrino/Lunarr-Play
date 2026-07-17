import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:m3uxtream_player/features/diagnostics/providers/ui_logs_providers.dart';
import 'package:m3uxtream_player/features/diagnostics/widgets/ui_log_console_card.dart';
import 'package:m3uxtream_player/features/diagnostics/widgets/streaming_diagnostics_card.dart';

/// Debug-only diagnostics page with the reusable log console card.
class DiagnosticsScreen extends ConsumerWidget {
  const DiagnosticsScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final logs = ref.watch(uiLogsProvider);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        const StreamingDiagnosticsCard(),
        const SizedBox(height: 16),
        Expanded(
          child: UiLogConsoleCard(
            logs: logs,
            onClear: () => ref.read(uiLogsProvider.notifier).clearLogs(),
          ),
        ),
      ],
    );
  }
}
