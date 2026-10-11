import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:http/http.dart' as http;
import 'package:package_info_plus/package_info_plus.dart';
import 'package:m3uxtream_player/core/services/release_update_service.dart';

final playerPackageInfoProvider = FutureProvider<PackageInfo>(
  (ref) => PackageInfo.fromPlatform(),
);

final startupUpdateProvider = FutureProvider<AvailableRelease?>((ref) {
  final client = http.Client();
  ref.onDispose(client.close);
  return ReleaseUpdateService(
    currentVersion: () async =>
        (await ref.read(playerPackageInfoProvider.future)).version,
    client: client,
  ).checkOnce();
});
