import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

void main() {
  test('UI layers do not introduce direct user-visible string literals', () {
    final roots = <Directory>[
      Directory('lib/app'),
      Directory('lib/features'),
      Directory('lib/shared/widgets'),
    ];
    final uiFiles = roots
        .expand(
          (root) => root
              .listSync(recursive: true)
              .whereType<File>()
              .where((file) => file.path.endsWith('.dart')),
        )
        .where((file) {
          final normalized = file.path.replaceAll('/', Platform.pathSeparator);
          return normalized.contains(
                '${Platform.pathSeparator}widgets${Platform.pathSeparator}',
              ) ||
              normalized.contains(
                '${Platform.pathSeparator}shell${Platform.pathSeparator}',
              );
        });
    final directUiLiteral = RegExp(
      r'''(?:\b(?:Text|SelectableText)\s*\(\s*(?:const\s+)?|'''
      r'''\b(?:tooltip|semanticLabel|hintText|helperText|errorText|'''
      r'''label|title|subtitle|message)\s*:\s*(?:const\s+)?)(['"])'''
      r'''([^'"\r\n]*)''',
      multiLine: true,
    );
    // Stable protocol names, compact time controls, and internal operation
    // labels are not natural-language UI copy and intentionally stay outside
    // ARB. Keeping this allowlist exact prevents it from masking new prose.
    const approvedTechnicalLiterals = <String>{
      'M3U',
      'Xtream',
      '-2h',
      '+2h',
      '-1d',
      '+1d',
      '−',
      '+',
      '100%',
      'pin category',
      'pin series category',
      'pin VOD category',
    };
    final violations = <String>[];

    for (final file in uiFiles) {
      final source = file.readAsStringSync();
      for (final match in directUiLiteral.allMatches(source)) {
        if (approvedTechnicalLiterals.contains(match.group(2))) continue;
        final line =
            '\n'.allMatches(source.substring(0, match.start)).length + 1;
        violations.add('${file.path}:$line');
      }
    }

    expect(
      violations,
      isEmpty,
      reason:
          'User-visible strings belong in lib/l10n/app_en.arb and must be '
          'read through generated AppLocalizations:\n${violations.join('\n')}',
    );
  });
}
