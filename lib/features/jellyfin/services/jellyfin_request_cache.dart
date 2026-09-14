import 'package:flutter/foundation.dart';
import 'package:m3uxtream_player/core/cache/bounded_async_cache.dart';

@immutable
class JellyfinResourceCacheKey {
  const JellyfinResourceCacheKey({
    required this.credentialId,
    required this.resourceId,
  });

  final String credentialId;
  final String resourceId;

  @override
  bool operator ==(Object other) =>
      other is JellyfinResourceCacheKey &&
      other.credentialId == credentialId &&
      other.resourceId == resourceId;

  @override
  int get hashCode => Object.hash(credentialId, resourceId);

  @override
  String toString() => 'JellyfinResourceCacheKey(<redacted>)';
}

class JellyfinRequestCache<T>
    extends BoundedAsyncCache<JellyfinResourceCacheKey, T> {
  JellyfinRequestCache({
    required super.maxEntries,
    required super.ttl,
    super.now,
  });

  void invalidateCredential(String credentialId) {
    invalidateWhere((key) => key.credentialId == credentialId);
  }
}
