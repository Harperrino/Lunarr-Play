import 'dart:ffi';
import 'dart:io';

import 'package:media_kit/media_kit.dart';
import 'package:path/path.dart' as p;

/// Ensures media_kit native libraries can load during `flutter test` on Windows.
void ensureMediaKitForTests() {
  if (Platform.isWindows) {
    _tryConfigureWindowsMpvSearchPath();
  }
  MediaKit.ensureInitialized();
}

void _tryConfigureWindowsMpvSearchPath() {
  final candidates = [
    p.join(
      Directory.current.path,
      'build',
      'windows',
      'x64',
      'runner',
      'Debug',
    ),
    p.join(Directory.current.path, 'build', 'windows', 'x64', 'libmpv'),
  ];

  for (final dir in candidates) {
    if (Directory(dir).existsSync()) {
      _setDllDirectory(dir);
      return;
    }
  }
}

void _setDllDirectory(String directory) {
  final kernel32 = DynamicLibrary.open('kernel32.dll');
  final setDllDirectory = kernel32
      .lookupFunction<
        Int32 Function(Pointer<Uint16>),
        int Function(Pointer<Uint16>)
      >('SetDllDirectoryW');

  final units = directory.codeUnits;
  final ptr = _mallocUint16(units.length + 1);
  for (var i = 0; i < units.length; i++) {
    ptr[i] = units[i];
  }
  ptr[units.length] = 0;
  try {
    setDllDirectory(ptr);
  } finally {
    _freeNative(ptr.cast());
  }
}

Pointer<Uint16> _mallocUint16(int length) {
  final byteCount = length * sizeOf<Uint16>();
  return _malloc(byteCount).cast<Uint16>();
}

final Pointer<Void> Function(int size) _malloc = () {
  final library = Platform.isWindows
      ? DynamicLibrary.open('ucrtbase.dll')
      : DynamicLibrary.process();
  return library.lookupFunction<
    Pointer<Void> Function(IntPtr),
    Pointer<Void> Function(int)
  >('malloc');
}();

final void Function(Pointer<Void>) _freeNative = () {
  final library = Platform.isWindows
      ? DynamicLibrary.open('ucrtbase.dll')
      : DynamicLibrary.process();
  return library.lookupFunction<
    Void Function(Pointer<Void>),
    void Function(Pointer<Void>)
  >('free');
}();
