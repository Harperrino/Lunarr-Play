import 'dart:async';

import 'package:m3uxtream_player/core/imports/import_limit_exception.dart';

typedef ImportCancellationCallback = void Function();

/// Cooperative cancellation shared by every task in one logical import.
class ImportCancellation {
  final Set<ImportCancellationCallback> _callbacks = {};
  final Completer<void> _cancelled = Completer<void>();
  Object? _reason;

  bool get isCancelled => _reason != null;
  Object? get reason => _reason;
  Future<void> get whenCancelled => _cancelled.future;

  void cancel([Object? reason]) {
    if (isCancelled) return;
    _reason =
        reason ??
        const ImportLimitException(
          code: ImportLimitCode.cancelled,
          phase: 'import',
          actual: 1,
          limit: 0,
        );
    _cancelled.complete();
    final callbacks = List<ImportCancellationCallback>.from(_callbacks);
    _callbacks.clear();
    for (final callback in callbacks) {
      callback();
    }
  }

  void throwIfCancelled() {
    final current = _reason;
    if (current == null) return;
    if (current is ImportLimitException) throw current;
    throw const ImportLimitException(
      code: ImportLimitCode.cancelled,
      phase: 'import',
      actual: 1,
      limit: 0,
    );
  }

  void Function() register(ImportCancellationCallback callback) {
    if (isCancelled) {
      callback();
      return () {};
    }
    _callbacks.add(callback);
    return () => _callbacks.remove(callback);
  }
}
