import 'package:flutter_test/flutter_test.dart';

import 'package:m3uxtream_player/core/models/streaming_diagnostics.dart';
import 'package:m3uxtream_player/core/services/live_stream_url.dart';
import 'package:m3uxtream_player/features/player/services/live_open_coordinator.dart';

void main() {
  const coordinator = LiveOpenCoordinator();
  const source = 'http://iptv.example.com/live/user/pass/123';

  test('plan keeps normalized source identity across fallback candidates', () {
    final plan = coordinator.createPlan(
      sourceUrl: '  $source  ',
      autoFallbackEnabled: true,
    );

    expect(plan.sourceUrl, source);
    expect(plan.sourceDelivery, LiveStreamDelivery.continuous);
    expect(plan.attempts, hasLength(greaterThan(1)));
    expect(
      plan.attempts.every((attempt) => attempt.sourceUrl == source),
      isTrue,
    );
  });

  test('disabled fallback keeps only the provider-default candidate', () {
    final plan = coordinator.createPlan(
      sourceUrl: source,
      autoFallbackEnabled: false,
    );

    expect(plan.attempts, hasLength(1));
    expect(plan.attempts.single.headerProfile, LiveStreamHeaderProfile.appMpv);
  });

  test('attempt context distinguishes source and effective playback URL', () {
    final plan = coordinator.createPlan(
      sourceUrl: source,
      autoFallbackEnabled: true,
    );
    final tsCandidate = plan.attempts.firstWhere(
      (attempt) =>
          LiveStreamUrl.deliveryFor(attempt.playbackUrl) ==
          LiveStreamDelivery.tsSegment,
    );

    final context = coordinator.attemptContext(
      plan: plan,
      playbackUrl: tsCandidate.playbackUrl,
      sessionToken: 7,
    );

    expect(context.sourceUrl, source);
    expect(context.playbackUrl, tsCandidate.playbackUrl);
    expect(context.playbackUrl, isNot(context.sourceUrl));
    expect(context.sessionToken, 7);
  });

  test('structural quick switch requires a later TS candidate', () {
    final plan = coordinator.createPlan(
      sourceUrl: source,
      autoFallbackEnabled: true,
    );
    final extensionlessIndex = plan.attempts.indexWhere(
      (attempt) => attempt.playbackUrl == source,
    );

    expect(
      coordinator.isQuickSwitchStructurallyEligible(
        canSeek: false,
        delivery: LiveStreamDelivery.continuous,
        playbackUrl: source,
        attempts: plan.attempts,
        currentIndex: extensionlessIndex,
      ),
      isTrue,
    );
    expect(
      coordinator.isQuickSwitchStructurallyEligible(
        canSeek: true,
        delivery: LiveStreamDelivery.continuous,
        playbackUrl: source,
        attempts: plan.attempts,
        currentIndex: extensionlessIndex,
      ),
      isFalse,
    );
  });
}
