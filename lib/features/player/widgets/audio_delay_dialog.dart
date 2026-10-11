import 'package:material_ui/material_ui.dart';
import 'package:m3uxtream_player/core/services/audio_delay_adjustment.dart';
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
  late int _revision;
  int _fineAnchor = 0;
  int? _comparison;
  bool _fine = false;
  final _feedbackKey = GlobalKey();
  bool _busy = false;
  bool _invalid = false;
  bool _failed = false;
  AudioDelayFailure? _failure;

  @override
  void initState() {
    super.initState();
    _preview = widget.session.value;
    _revision = widget.session.sourceRevision;
    _input = TextEditingController(text: '$_preview');
    widget.session.addListener(_sync);
    widget.session.progress.addListener(_refresh);
  }

  int get _minimum => _fine
      ? (_fineAnchor - 500).clamp(
          AudioDelaySession.minimumMs,
          AudioDelaySession.maximumMs,
        )
      : AudioDelaySession.minimumMs;
  int get _maximum => _fine
      ? (_fineAnchor + 500).clamp(
          AudioDelaySession.minimumMs,
          AudioDelaySession.maximumMs,
        )
      : AudioDelaySession.maximumMs;
  int get _step => _fine ? 10 : AudioDelaySession.stepMs;

  void _refresh() {
    if (!mounted) return;
    if (_revision != widget.session.sourceRevision) {
      _sync();
    } else {
      setState(() {});
    }
  }

  void _sync() {
    if (!mounted) return;
    setState(() {
      if (_revision != widget.session.sourceRevision) {
        _revision = widget.session.sourceRevision;
        _comparison = null;
      }
      _preview = widget.session.value;
      _input.text = '$_preview';
      if (_preview < _minimum || _preview > _maximum) {
        _fineAnchor = (_preview / 10).round() * 10;
      }
    });
  }

  @override
  void dispose() {
    if (_busy) widget.session.cancelAdjustment();
    widget.session.removeListener(_sync);
    widget.session.progress.removeListener(_refresh);
    _input.dispose();
    super.dispose();
  }

  void _showFeedback() {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      final feedback = _feedbackKey.currentContext;
      if (feedback != null) {
        Scrollable.ensureVisible(
          feedback,
          duration: const Duration(milliseconds: 150),
        );
      }
    });
  }

  Future<void> _apply(int milliseconds) async {
    if (_busy) return;
    setState(() {
      _busy = true;
      _failed = false;
      _failure = null;
      _invalid = false;
    });
    _showFeedback();
    try {
      await widget.session.setMilliseconds(milliseconds);
      _sync();
    } on AudioDelayAdjustmentException catch (e) {
      if (mounted) {
        setState(() {
          _failure = e.failure;
          _failed = e.failure != AudioDelayFailure.cancelled;
          _comparison = null;
        });
        _sync();
        _showFeedback();
      }
    } catch (_) {
      if (mounted) {
        setState(() {
          _failed = true;
          _comparison = null;
        });
        _sync();
        _showFeedback();
      }
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

  void _setPreview(int milliseconds, {bool comparing = false}) {
    setState(() {
      _preview = milliseconds.clamp(
        AudioDelaySession.minimumMs,
        AudioDelaySession.maximumMs,
      );
      _input.text = '$_preview';
      _invalid = false;
      _failed = false;
      if (!comparing) _comparison = null;
      if (_preview < _minimum || _preview > _maximum) {
        _fineAnchor = (_preview / 10).round() * 10;
      }
    });
  }

  void _compare() {
    final saved = _comparison;
    if (saved == null) {
      _comparison = _preview;
      _setPreview(0, comparing: true);
    } else {
      _setPreview(saved);
    }
  }

  String _seconds(int value) => (value.abs() / 1000)
      .toStringAsFixed(3)
      .replaceFirst(RegExp(r'\.?0+$'), '');

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    final progress = widget.session.progress.value;
    final description = _preview == 0
        ? l10n.audioDelayNoOffset
        : (_preview < 0
              ? l10n.audioDelayEarlierSeconds(_seconds(_preview))
              : l10n.audioDelayLaterSeconds(_seconds(_preview)));
    return AlertDialog(
      scrollable: true,
      title: Text(l10n.audioDelayTitle),
      content: SizedBox(
        width: 420,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(l10n.audioDelayDescription),
            const SizedBox(height: 16),
            Text(
              description,
              key: const ValueKey('audio-delay-description'),
              style: Theme.of(context).textTheme.titleMedium,
            ),
            Text(l10n.audioDelayValue(_preview)),
            Text(
              l10n.audioDelayApplied(widget.session.value),
              key: const ValueKey('audio-delay-applied-value'),
            ),
            Text(l10n.audioDelayApplyHint),
            const SizedBox(height: 12),
            _AudioDelayTracks(milliseconds: _preview),
            const SizedBox(height: 8),
            Text(
              l10n.audioDelayTrackDescription,
              style: Theme.of(context).textTheme.bodySmall,
            ),
            SwitchListTile(
              key: const ValueKey('audio-delay-fine'),
              contentPadding: EdgeInsets.zero,
              title: Text(l10n.audioDelayFine),
              subtitle: Text(l10n.audioDelayFineDescription),
              value: _fine,
              onChanged: _busy
                  ? null
                  : (value) => setState(() {
                      _fine = value;
                      _fineAnchor = (_preview / 10).round() * 10;
                    }),
            ),
            Slider(
              key: const ValueKey('audio-delay-slider'),
              min: _minimum.toDouble(),
              max: _maximum.toDouble(),
              divisions: (_maximum - _minimum) ~/ _step,
              value: _preview.toDouble(),
              semanticFormatterCallback: (value) =>
                  l10n.audioDelayValue(value.round()),
              onChanged: _busy
                  ? null
                  : (value) => _setPreview(
                      ((value / _step).round() * _step).clamp(
                        _minimum,
                        _maximum,
                      ),
                    ),
            ),
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(l10n.audioDelayEarlier),
                Text(l10n.audioDelayLater),
              ],
            ),
            const SizedBox(height: 8),
            Row(
              children: [
                IconButton(
                  tooltip: l10n.audioDelayEarlier,
                  onPressed: _busy || _preview <= AudioDelaySession.minimumMs
                      ? null
                      : () => _setPreview(_preview - _step),
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
                    onChanged: (text) {
                      final value = int.tryParse(text.trim());
                      if (value == null ||
                          value < AudioDelaySession.minimumMs ||
                          value > AudioDelaySession.maximumMs) {
                        return;
                      }
                      setState(() {
                        _preview = value;
                        _comparison = null;
                        _invalid = false;
                        _failed = false;
                        if (_preview < _minimum || _preview > _maximum) {
                          _fineAnchor = (_preview / 10).round() * 10;
                        }
                      });
                    },
                  ),
                ),
                IconButton(
                  tooltip: l10n.audioDelayLater,
                  onPressed: _busy || _preview >= AudioDelaySession.maximumMs
                      ? null
                      : () => _setPreview(_preview + _step),
                  icon: const Icon(Icons.add_rounded),
                ),
              ],
            ),
            TextButton(
              onPressed: _busy || (_comparison == null && _preview == 0)
                  ? null
                  : _compare,
              child: Text(
                _comparison == null
                    ? l10n.audioDelayCompareOriginal
                    : l10n.audioDelayUseCorrection,
              ),
            ),
            if (_busy) ...[
              const SizedBox(height: 12),
              LinearProgressIndicator(
                value:
                    progress.phase == AudioDelayPhase.buffering &&
                        progress.targetSeconds > 0
                    ? (progress.bufferedSeconds / progress.targetSeconds).clamp(
                        0.0,
                        1.0,
                      )
                    : null,
              ),
              const SizedBox(height: 8),
              Container(
                key: _feedbackKey,
                child: Text(
                  progress.phase == AudioDelayPhase.buffering
                      ? l10n.audioDelayBuffering(
                          progress.bufferedSeconds.floor(),
                          progress.targetSeconds.ceil(),
                        )
                      : l10n.audioDelayAligning,
                  key: const ValueKey('audio-delay-status'),
                ),
              ),
              TextButton(
                onPressed: widget.session.cancelAdjustment,
                child: Text(l10n.audioDelayCancel),
              ),
            ],
            if (_failed) ...[
              const SizedBox(height: 12),
              Container(
                key: _feedbackKey,
                child: Text(
                  _failure == AudioDelayFailure.unavailable
                      ? l10n.audioDelayUnavailable
                      : _failure == AudioDelayFailure.timeout
                      ? l10n.audioDelayTimedOut
                      : _failure == AudioDelayFailure.superseded
                      ? l10n.audioDelayInterrupted
                      : l10n.audioDelayFailed,
                ),
              ),
            ],
          ],
        ),
      ),
      actions: [
        TextButton(
          onPressed: _busy ? null : () => _setPreview(0),
          child: Text(l10n.audioDelayReset),
        ),
        TextButton(
          onPressed: _busy ? null : _submit,
          child: Text(l10n.audioDelayApply),
        ),
        TextButton(
          onPressed: () {
            if (_busy) widget.session.cancelAdjustment();
            Navigator.of(context).pop();
          },
          child: Text(l10n.audioDelayClose),
        ),
      ],
    );
  }
}

class _AudioDelayTracks extends StatelessWidget {
  const _AudioDelayTracks({required this.milliseconds});
  final int milliseconds;
  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    final colors = Theme.of(context).colorScheme;
    final span = (milliseconds.abs() + 500).clamp(1000, 60000);
    Widget track(String label, double position, Color color, Key key) => Row(
      children: [
        SizedBox(width: 64, child: Text(label)),
        Expanded(
          child: SizedBox(
            height: 28,
            child: Stack(
              alignment: Alignment.center,
              children: [
                Container(height: 2, color: colors.outlineVariant),
                Container(width: 1, height: 28, color: colors.outlineVariant),
                Align(
                  alignment: Alignment(position * 0.9, 0),
                  child: Container(
                    key: key,
                    width: 12,
                    height: 20,
                    decoration: BoxDecoration(
                      color: color,
                      borderRadius: BorderRadius.circular(4),
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
      ],
    );
    return Column(
      children: [
        track(
          l10n.audioDelayPicture,
          0,
          colors.onSurface,
          const ValueKey('audio-delay-picture-marker'),
        ),
        track(
          l10n.audioDelaySound,
          milliseconds / span,
          colors.primary,
          const ValueKey('audio-delay-sound-marker'),
        ),
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            const SizedBox(width: 64),
            Text(l10n.audioDelayValue(-span)),
            Text(l10n.audioDelayValue(0)),
            Text(l10n.audioDelayValue(span)),
          ],
        ),
      ],
    );
  }
}
