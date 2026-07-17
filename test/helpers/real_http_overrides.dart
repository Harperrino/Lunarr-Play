// ignore_for_file: unnecessary_overrides

import 'dart:io';

/// Bypasses Flutter test HTTP blocking for loopback mock server traffic.
class RealHttpOverrides extends HttpOverrides {
  @override
  HttpClient createHttpClient(SecurityContext? context) {
    return super.createHttpClient(context);
  }
}
