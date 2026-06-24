# Patch test fixtures

Static source/patch/expected files for `test/patch_fixtures_test.dart`. No
ROM needed — these are small synthetic blobs.

Most are vendored from UniPatcher's test resources (`app/src/test/resources/` in
https://github.com/btimofeev/UniPatcher).

Naming per format: `<name>.bin` is the source, `<name>.ips`/`.ups`/`.bps` is the patch,
and `<name>_modified.bin` (or `_mod.bin` / `m.bin`) is the expected output.
`ips/not_ips.ips` is a deliberately invalid patch for the rejection test.

## ebp / ppf / dps / aps

UniPatcher has no fixtures for these, so `tool/gen_patch_fixtures.dart` builds a
source/patch/modified triple for each straight from the format spec and the test checks
the three SHA-256 hashes. Regenerate with `dart run tool/gen_patch_fixtures.dart`.

## xdelta

point the env-driven tests (`test/aps_test.dart`,
`test/xdelta_test.dart`) at your own files instead. Set `<FMT>_ROM` / `<FMT>_PATCH` /
`<FMT>_EXPECTED` / `<FMT>_DST` and run `flutter test`; the test skips when they're unset.
Use a ROM from your own  dump.

Patches to try:

- **xdelta** — 999: Nine Hours, Nine Persons, Nine Doors, Arabic translation (Nintendo
  DS). https://www.romhacking.net/translations/5617/. Base ROM: *Nine Hours, Nine
  Persons, Nine Doors (USA)* `.nds`.
