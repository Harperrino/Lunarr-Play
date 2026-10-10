import 'package:material_ui/material_ui.dart';
import 'package:m3uxtream_player/core/services/audio_delay_session.dart';
import 'package:m3uxtream_player/l10n/l10n.dart';

Future<void> showAudioDelayDialog(
  BuildContext context,
  AudioDelaySession session,
) => showDialog<void>(
  context: context,
  builder: (_) => _AudioDelayDialog(session: session),
);

class _AudioDelayDialog extends StatefulWidget {
  const _AudioDelayDialog({required this.session});
  final AudioDelaySession session;

  @override
  State<_AudioDelayDialog> createState() => _AudioDelayDialogState();
}

class _AudioDelayDialogState extends State<_AudioDelayDialog> {
  late final TextEditingController _input;
  late int _preview;
  bool _busy = false;
  bool _failed = false;
  bool _invalid = false;

  @override
  void initState() {
    super.initState();
    _preview = widget.session.value;
    _input = TextEditingController(text: '$_preview');
    widget.session.addListener(_sync);
  }

  void _sync() {
    if (!mounted) return;
    setState(() {
      _preview = widget.session.value;
      _input.text = '$_preview';
    });
  }

  @override
  void dispose() {
    widget.session.removeListener(_sync);
    _input.dispose();
    super.dispose();
  }

  Future<void> _apply(int milliseconds) async {
    if (_busy) return;
    setState(() {
      _busy = true;
      _failed = false;
      _invalid = false;
    });
    try {
      await widget.session.setMilliseconds(milliseconds);
      _sync();
    } catch (_) {
      if (mounted) setState(() => _failed = true);
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  void _submit() {
    final value = int.tryParse(_input.text.trim());
    if (value == null ||
        value < AudioDelaySession.minimumMs ||
        value > AudioDelaySession.maximumMs) {
      setState(() => _invalid = true);
      return;
    }
    _apply(value);
  }

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    return AlertDialog(
      title: Text(l10n.audioDelayTitle),
      content: SizedBox(
        width: 360,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(l10n.audioDelayDescription),
            const SizedBox(height: 16),
            Text(
              l10n.audioDelayValue(_preview),
              style: Theme.of(context).textTheme.titleLarge,
            ),
            Slider(
              key: const ValueKey('audio-delay-slider'),
              min: AudioDelaySession.minimumMs.toDouble(),
              max: AudioDelaySession.maximumMs.toDouble(),
              divisions: 80,
              value: _preview.toDouble(),
              semanticFormatterCallback: (value) =>
                  l10n.audioDelayValue(value.round()),
              onChanged: _busy
                  ? null
                  : (value) {
                      setState(() {
                        _preview = value.round();
                        _input.text = '$_preview';
                      });
                    },
              onChangeEnd: _busy ? null : (value) => _apply(value.round()),
            ),
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(l10n.audioDelayEarlier),
                Text(l10n.audioDelayLater),
              ],
            ),
            const SizedBox(height: 16),
            Row(
              children: [
                IconButton(
                  tooltip: l10n.audioDelayEarlier,
                  onPressed: _busy || _preview <= AudioDelaySession.minimumMs
                      ? null
                      : () => _apply(_preview - AudioDelaySession.stepMs),
                  icon: const Icon(Icons.remove_rounded),
                ),
                Expanded(
                  child: TextField(
                    key: const ValueKey('audio-delay-input'),
                    controller: _input,
                    enabled: !_busy,
                    keyboardType: const TextInputType.numberWithOptions(
                      signed: true,
                    ),
                    decoration: InputDecoration(
                      labelText: l10n.audioDelayTitle,
                      suffixText: l10n.audioDelayUnit,
                      errorText: _invalid ? l10n.audioDelayInvalid : null,
                    ),
                    onSubmitted: (_) => _submit(),
                  ),
                ),
                IconButton(
                  tooltip: l10n.audioDelayLater,
                  onPressed: _busy || _preview >= AudioDelaySession.maximumMs
                      ? null
                      : () => _apply(_preview + AudioDelaySession.stepMs),
                  icon: const Icon(Icons.add_rounded),
                ),
              ],
            ),
            if (_failed) ...[
              const SizedBox(height: 12),
              Text(l10n.audioDelayFailed),
            ],
          ],
        ),
      ),
      actions: [
        TextButton(
          onPressed: _busy ? null : () => _apply(0),
          child: Text(l10n.audioDelayReset),
        ),
        TextButton(
          onPressed: _busy ? null : _submit,
          child: Text(l10n.audioDelayApply),
        ),
        TextButton(
          onPressed: () => Navigator.of(context).pop(),
          child: Text(l10n.audioDelayClose),
        ),
      ],
    );
  }
}
