# Dependency Policy

LUNARR One uses exact dependency versions in `pubspec.yaml` so Windows release
builds stay reproducible.

- Pin direct dependencies to exact versions. Do not use `any`, caret ranges,
  dependency overrides, Git references, or unreviewed path dependencies.
- Keep Flutter on the stable channel and update the Dart and Flutter minimum
  versions to the actually adopted stable toolchain.
- Treat major dependency upgrades as separate migration waves. Review their
  changelogs, compatibility requirements, generated output, tests, and Windows
  builds before accepting them.
- Accept transitive lockfile updates only when required by an approved direct
  dependency or SDK update. Review `pubspec.lock` rather than running broad
  unconstrained upgrades.
- Update coupled packages together when their compatibility requires it, such
  as Drift with `drift_dev` or Material UI with packages that consume it.
