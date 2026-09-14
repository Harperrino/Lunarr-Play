import 'dart:async';

import 'package:flutter_test/flutter_test.dart';
import 'package:m3uxtream_player/features/player/services/player_session_lifecycle.dart';

void main() {
  test('initialization is shared and runs exactly once', () async {
    final lifecycle = PlayerSessionLifecycle<int>();
    final completer = Completer<int>();
    var calls = 0;

    Future<int> initialize() {
      calls += 1;
      return completer.future;
    }

    final first = lifecycle.initializeOnce(initialize);
    final second = lifecycle.initializeOnce(initialize);

    expect(identical(first, second), isTrue);
    expect(calls, 1);
    completer.complete(42);
    expect(await first, 42);
    expect(await second, 42);
  });

  test('session generations become stale monotonically', () {
    final lifecycle = PlayerSessionLifecycle<void>();

    final first = lifecycle.beginSession();
    expect(lifecycle.isSessionCurrent(first), isTrue);

    final second = lifecycle.beginSession();
    expect(second, greaterThan(first));
    expect(lifecycle.isSessionCurrent(first), isFalse);
    expect(lifecycle.isSessionCurrent(second), isTrue);
  });

  test('disposal is idempotent and invalidates the session once', () async {
    final lifecycle = PlayerSessionLifecycle<void>();
    final active = lifecycle.beginSession();
    var beginCalls = 0;

    void invalidate() {
      beginCalls += 1;
      lifecycle.beginSession();
    }

    final first = lifecycle.dispose(null, onBegin: invalidate);
    final second = lifecycle.dispose(null, onBegin: invalidate);

    expect(identical(first, second), isTrue);
    await Future.wait([first, second]);
    expect(beginCalls, 1);
    expect(lifecycle.isDisposed, isTrue);
    expect(lifecycle.isSessionCurrent(active), isFalse);
  });
}
