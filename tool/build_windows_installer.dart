import 'dart:io';

import 'package:crypto/crypto.dart';
import 'package:path/path.dart' as p;

const _runtimeFileNames = <String>[
  'msvcp140.dll',
  'vcruntime140.dll',
  'vcruntime140_1.dll',
];

const _debugArtifactsExcludedFromRelease = <String>[
  'data/flutter_assets/kernel_blob.bin',
  'data/flutter_assets/isolate_snapshot_data',
  'data/flutter_assets/vm_snapshot_data',
];

Future<void> main(List<String> arguments) async {
  if (!Platform.isWindows) {
    stderr.writeln('The Windows installer can only be built on Windows.');
    exitCode = 1;
    return;
  }

  final skipFlutterBuild = arguments.contains('--skip-flutter-build');
  final outputArguments = arguments.where(
    (argument) => argument.startsWith('--output-directory='),
  );
  final outputArgument = outputArguments.isEmpty
      ? null
      : outputArguments.first.substring('--output-directory='.length);
  final unsupportedArguments = arguments.where(
    (argument) =>
        argument != '--skip-flutter-build' &&
        !argument.startsWith('--output-directory='),
  );
  if (unsupportedArguments.isNotEmpty || outputArguments.length > 1) {
    stderr.writeln(
      'Unsupported or duplicate arguments: ${arguments.join(' ')}',
    );
    exitCode = 64;
    return;
  }

  final projectRoot = Directory.current.absolute;
  final pubspec = File(p.join(projectRoot.path, 'pubspec.yaml'));
  final installerScript = File(
    p.join(projectRoot.path, 'tool', 'windows_installer.iss'),
  );
  if (!await pubspec.exists() || !await installerScript.exists()) {
    stderr.writeln('Run this command from the project root.');
    exitCode = 64;
    return;
  }

  final outputDirectory = Directory(
    p.isAbsolute(outputArgument ?? '')
        ? outputArgument!
        : p.join(projectRoot.path, outputArgument ?? 'release'),
  ).absolute;
  final releaseDirectory = Directory(
    p.join(projectRoot.path, 'build', 'windows', 'x64', 'runner', 'Release'),
  );
  final temporaryRoot = await Directory.systemTemp.createTemp(
    'lunarr-installer-build-',
  );

  try {
    if (!skipFlutterBuild) {
      await _runChecked(
        'flutter',
        const ['build', 'windows', '--release', '--no-pub'],
        workingDirectory: projectRoot.path,
        runInShell: true,
      );
    }

    final appExecutable = File(p.join(releaseDirectory.path, 'lunarr_one.exe'));
    final appData = Directory(p.join(releaseDirectory.path, 'data'));
    if (!await appExecutable.exists() || !await appData.exists()) {
      throw StateError('The Flutter Windows release bundle is incomplete.');
    }

    final packageVersion = await _readPackageVersion(pubspec);
    final iscc = await _resolveInnoSetupCompiler();
    final runtimeDirectory = await _resolveVcRuntimeDirectory();
    final stagingDirectory = Directory(p.join(temporaryRoot.path, 'app'));
    await stagingDirectory.create(recursive: true);
    await outputDirectory.create(recursive: true);
    await _copyDirectory(releaseDirectory, stagingDirectory);
    await _copyRequiredReleaseFile(
      File(p.join(projectRoot.path, 'LICENSE')),
      File(p.join(stagingDirectory.path, 'LICENSE.txt')),
    );
    await _copyRequiredReleaseFile(
      File(p.join(projectRoot.path, 'THIRD_PARTY_NOTICES.md')),
      File(p.join(stagingDirectory.path, 'THIRD_PARTY_NOTICES.md')),
    );
    await _copyDirectory(
      Directory(p.join(projectRoot.path, 'third_party_licenses')),
      Directory(p.join(stagingDirectory.path, 'third_party_licenses')),
    );

    for (final relativePath in _debugArtifactsExcludedFromRelease) {
      final staleArtifact = File(
        p.joinAll([stagingDirectory.path, ...p.posix.split(relativePath)]),
      );
      if (await staleArtifact.exists()) {
        await staleArtifact.delete();
      }
    }

    for (final fileName in _runtimeFileNames) {
      await File(p.join(runtimeDirectory.path, fileName))
          .copy(p.join(stagingDirectory.path, fileName));
    }

    await _runChecked(iscc.path, [
      '/Qp',
      '/DAppVersion=$packageVersion',
      '/DSourceDir=${stagingDirectory.path}',
      '/DOutputDir=${outputDirectory.path}',
      installerScript.path,
    ], workingDirectory: projectRoot.path);

    final artifactName = 'Lunarr-Player-$packageVersion-windows-x64-setup.exe';
    final artifact = File(p.join(outputDirectory.path, artifactName));
    if (!await artifact.exists()) {
      throw StateError('Inno Setup did not create the expected installer.');
    }

    final hash = await _sha256(artifact);
    await File('${artifact.path}.sha256')
        .writeAsString('$hash  $artifactName\n', flush: true);
    final sizeMiB = (await artifact.length()) / (1024 * 1024);
    stdout.writeln(
      'Windows installer created: ${artifact.path} '
      '(${sizeMiB.toStringAsFixed(2)} MiB)',
    );
    stdout.writeln('SHA-256: $hash');
  } finally {
    final systemTemp = Directory.systemTemp.absolute.path;
    final cleanupTarget = temporaryRoot.absolute.path;
    if (!p.isWithin(systemTemp, cleanupTarget)) {
      throw StateError(
        'Refusing to clean a directory outside the system temp.',
      );
    }
    if (await temporaryRoot.exists()) {
      await temporaryRoot.delete(recursive: true);
    }
  }
}

Future<String> _readPackageVersion(File pubspec) async {
  final versionLine = (await pubspec.readAsLines()).where(
    (line) => line.trimLeft().startsWith('version:'),
  );
  if (versionLine.length != 1) {
    throw StateError('pubspec.yaml must contain exactly one version field.');
  }
  final rawVersion = versionLine.single.split(':').last.trim();
  final packageVersion = rawVersion.split('+').first;
  if (!RegExp(r'^\d+\.\d+\.\d+(?:[-+][0-9A-Za-z.-]+)?$')
      .hasMatch(packageVersion)) {
    throw StateError('Unsupported package version: $rawVersion');
  }
  return packageVersion;
}

Future<File> _resolveInnoSetupCompiler() async {
  final candidates = <String>[
    Platform.environment['INNO_SETUP_ISCC'] ?? '',
    if (Platform.environment['LOCALAPPDATA'] case final root?)
      p.join(root, 'Programs', 'Inno Setup 6', 'ISCC.exe'),
    if (Platform.environment['ProgramFiles(x86)'] case final root?)
      p.join(root, 'Inno Setup 6', 'ISCC.exe'),
    if (Platform.environment['ProgramFiles'] case final root?)
      p.join(root, 'Inno Setup 6', 'ISCC.exe'),
  ];
  for (final candidate in candidates) {
    final compiler = File(candidate);
    if (await compiler.exists()) {
      return compiler;
    }
  }

  throw StateError(
    'Inno Setup 6 was not found. Install JRSoftware.InnoSetup with winget '
    'or set INNO_SETUP_ISCC to ISCC.exe.',
  );
}

Future<Directory> _resolveVcRuntimeDirectory() async {
  final visualStudioRoots = <Directory>[
    if (Platform.environment['ProgramFiles'] case final root?)
      Directory(p.join(root, 'Microsoft Visual Studio')),
    if (Platform.environment['ProgramFiles(x86)'] case final root?)
      Directory(p.join(root, 'Microsoft Visual Studio')),
  ];

  final candidates = <Directory>[];
  for (final root in visualStudioRoots) {
    if (!await root.exists()) {
      continue;
    }
    await for (final year in root.list(followLinks: false)) {
      if (year is! Directory) {
        continue;
      }
      await for (final edition in year.list(followLinks: false)) {
        if (edition is! Directory) {
          continue;
        }
        final redistRoot = Directory(
          p.join(edition.path, 'VC', 'Redist', 'MSVC'),
        );
        if (!await redistRoot.exists()) {
          continue;
        }
        await for (final version in redistRoot.list(followLinks: false)) {
          if (version is! Directory) {
            continue;
          }
          final x64Directory = Directory(p.join(version.path, 'x64'));
          if (!await x64Directory.exists()) {
            continue;
          }
          await for (final crt in x64Directory.list(followLinks: false)) {
            if (crt is Directory &&
                p.basename(crt.path).startsWith('Microsoft.VC') &&
                p.basename(crt.path).endsWith('.CRT')) {
              candidates.add(crt);
            }
          }
        }
      }
    }
  }

  candidates.sort((left, right) => right.path.compareTo(left.path));
  for (final candidate in candidates) {
    final hasAllFiles = await Future.wait(
      _runtimeFileNames.map(
        (fileName) => File(p.join(candidate.path, fileName)).exists(),
      ),
    );
    if (hasAllFiles.every((exists) => exists)) {
      return candidate;
    }
  }
  throw StateError('The x64 Visual C++ runtime files could not be located.');
}

Future<void> _copyDirectory(Directory source, Directory destination) async {
  if (!await source.exists()) {
    throw StateError('Required release directory is missing: ${source.path}');
  }
  await for (final entity in source.list(recursive: true, followLinks: false)) {
    final relativePath = p.relative(entity.path, from: source.path);
    final targetPath = p.join(destination.path, relativePath);
    switch (entity) {
      case Directory():
        await Directory(targetPath).create(recursive: true);
      case File():
        await Directory(p.dirname(targetPath)).create(recursive: true);
        await entity.copy(targetPath);
      case Link():
        throw StateError('Release bundles must not contain symbolic links.');
    }
  }
}

Future<void> _copyRequiredReleaseFile(File source, File destination) async {
  if (!await source.exists()) {
    throw StateError('Required release file is missing: ${source.path}');
  }
  await destination.parent.create(recursive: true);
  await source.copy(destination.path);
}

Future<String> _sha256(File file) async =>
    (await sha256.bind(file.openRead()).first).toString();

Future<void> _runChecked(
  String executable,
  List<String> arguments, {
  String? workingDirectory,
  bool runInShell = false,
}) async {
  final process = await Process.start(
    executable,
    arguments,
    workingDirectory: workingDirectory,
    runInShell: runInShell,
    mode: ProcessStartMode.normal,
  );
  await Future.wait([
    stdout.addStream(process.stdout),
    stderr.addStream(process.stderr),
  ]);
  final result = await process.exitCode;
  if (result != 0) {
    throw ProcessException(executable, arguments, 'Exit code $result', result);
  }
}
