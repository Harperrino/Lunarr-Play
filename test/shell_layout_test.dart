import 'package:flutter_test/flutter_test.dart';
import 'package:m3uxtream_player/app/shell/shell_layout.dart';
import 'package:m3uxtream_player/shared/theme/app_spacing.dart';

void main() {
  test('classifies exact shell width breakpoints', () {
    expect(shellWidthClassFor(719), ShellWidthClass.compact);
    expect(shellWidthClassFor(720), ShellWidthClass.medium);
    expect(shellWidthClassFor(1199), ShellWidthClass.medium);
    expect(shellWidthClassFor(1200), ShellWidthClass.expanded);
    expect(shellWidthClassFor(1599), ShellWidthClass.expanded);
    expect(shellWidthClassFor(1600), ShellWidthClass.wide);
  });

  test('uses standard adaptive content gutters', () {
    expect(shellContentGutterFor(719), 12);
    expect(shellContentGutterFor(720), 16);
    expect(shellContentGutterFor(1200), 24);
    expect(shellContentGutterFor(1600), 32);
  });

  test('uses supplied spacing tokens when available', () {
    const spacing = AppSpacing(
      compactContentGutter: 13,
      mediumContentGutter: 17,
      expandedContentGutter: 25,
      wideContentGutter: 33,
    );

    expect(shellContentGutterFor(719, spacing), 13);
    expect(shellContentGutterFor(720, spacing), 17);
    expect(shellContentGutterFor(1200, spacing), 25);
    expect(shellContentGutterFor(1600, spacing), 33);
  });
}
