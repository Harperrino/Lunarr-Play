import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:m3uxtream_player/core/services/app_shutdown_service.dart';

final appShutdownControllerProvider = Provider<AppShutdownController>((ref) {
  return AppShutdownController(RiverpodAppShutdownActions(ref));
});
