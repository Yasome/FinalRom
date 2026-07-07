# Final ROM

Final ROM is an all-in-one offline utility for working with your retro and
console game ROMs. Everything runs locally on your device. There are no
accounts, no servers, and no internet connection required.

## Features

- **3DS (.3ds / CCI)** - Decrypt and re-encrypt 3DS ROMs.
- **Switch** - Compress and decompress NSP/NSZ and XCI/XCZ files, and merge or
  unmerge multi-content packages.
- **CHD** - Compress disc images to CHD and extract them back.
- **Patching** - Apply ROM patches in common formats, including IPS, UPS, BPS,
  APS, PPF, EBP, DPS, and xdelta.
- **Hashing** - Verify your files with checksum hashing.

## How it works

You pick a file, choose an operation, and Final ROM processes it directly on
your device. By default the original file is left untouched and a new output
file is written next to it. The heavy work runs in the background so the app
stays responsive.

https://github.com/user-attachments/assets/a8ea9270-d594-4aa4-9a1d-814d2031dcf9

## Important notes

- You are responsible for the ROMs and files you process. Only use Final ROM
  with content you legally own.
- Final ROM does not include, distribute, or download any game files or
  encryption keys. You must supply your own.

## Platforms

Final ROM currently builds and runs on Android, iOS, Windows, macOS, and Linux.
It does not run in a web browser, because it works with local files.

## Building and running

Final ROM is a Flutter app with native FFI plugins (`chdman_ffi`, `xdelta3_ffi`,
`zstd_ffi`) for CHD, xdelta, and Zstandard support. Their native sources are
already vendored in `final_rom/packages/`, so a normal Flutter build picks
them up automatically.

### Prerequisites

- [Flutter SDK](https://docs.flutter.dev/get-started/install) (stable channel),
  matching the Dart SDK constraint in `pubspec.yaml`.
- A C/C++ toolchain and CMake, for the native FFI plugins.

From the `final_rom/` directory, fetch dependencies once:

```sh
flutter pub get
```

### Android

Requires Android Studio (or just the Android SDK/NDK and command-line tools).

```sh
flutter run -d android      # debug
flutter build apk           # release APK
```

### iOS

Requires a Mac with Xcode and CocoaPods installed.

```sh
flutter run -d ios          # debug
flutter build ios           # release build
```

### Windows

Requires Visual Studio (with the "Desktop development with C++" workload).

```sh
flutter run -d windows      # debug
flutter build windows       # release build, output under build/windows/
```

### Linux

Requires CMake, ninja-build, clang, and GTK 3 development headers (the
usual [Flutter Linux desktop prerequisites](https://docs.flutter.dev/get-started/install/linux/desktop)).

```sh
flutter run -d linux      # debug
flutter build linux       # release build
```

### macOS

Requires a Mac with Xcode and CocoaPods installed.

```sh
flutter run -d macos      # debug
flutter build macos       # release build
```

The release build is not signed with an Apple Developer ID or notarized, so
macOS Gatekeeper will quarantine it after download and may report that the app
is "damaged" or "can't be verified". To run it, either right-click the app and
choose **Open** the first time, or clear the quarantine attribute:

```sh
xattr -cr /path/to/final_rom.app
```

## Privacy

Final ROM does not collect any personal data. See [PRIVACY_POLICY.md](PRIVACY_POLICY.md)
for details.

## Credits and acknowledgments

Final ROM builds on the work of several open source projects:

- **[MAME](https://mamedev.org)** - the `chd` source used to create and
  extract CHD disc images.
- **[UniPatcher](https://github.com/btimofeev/UniPatcher)** (btimofeev and
  contributors) - the ROM patcher module (IPS, UPS, BPS, APS, PPF, EBP, DPS,
  xdelta dispatch, and checksum helpers) is ported from UniPatcher's Kotlin/Java
  sources.
- **[NSZ](https://github.com/nicoboss/nsz)** (Nico Bosshard / nicoboss) - the
  Switch NSZ/NCZ compression logic is modeled on the reference NSZ Python
  implementation.
- **[xdelta](https://github.com/jmacd/xdelta)** (Joshua MacDonald) - the
  xdelta3 delta-compression library used for xdelta patches.
- **[b3DS](https://github.com/b1k/b3DS)** (b1k and DemonKingSwarn) - the
  3DS decryption/encryption logic is ported from the b3DSDecrypt/b3DSEncrypt
  scripts.

## License

Final ROM is licensed under the [GNU General Public License v3.0 or later](LICENSE).
