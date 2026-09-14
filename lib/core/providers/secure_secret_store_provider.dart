import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:m3uxtream_player/core/security/persistent_secure_secret_store.dart';
import 'package:m3uxtream_player/core/security/secure_secret_store.dart';

final secureSecretStoreProvider = Provider<SecureSecretStore>((ref) {
  if (!kIsWeb && Platform.isWindows) {
    return PersistentSecureSecretStore(const WindowsDpapiSecretCipher());
  }
  return InMemorySecureSecretStore();
});
