// swift-tools-version: 5.9
// Swift Package Manager manifest for the chdman_ffi FFI plugin (macOS).
//
// This builds the REAL MAME "chd" backend (parity with the Linux/Windows/Android
// CMake build in ../../src/CMakeLists.txt). SwiftPM only compiles sources that live
// inside the package directory and forbids source dirs / header-search-paths that
// escape the package root, so the vendored tree at ../../src/chd is brought in via
// the in-package `chd` symlink (chd -> ../../src/chd). The five vendored codecs are
// each their own static SPM target; the C++20 `chdman_ffi` target compiles the MAME
// util/osd subset (via #include forwarders under Sources/chdman_ffi) and links them.
//
// Defining CHDMAN_AVAILABLE flips the wrapper from its stub branch to the real one.
import PackageDescription

let package = Package(
    name: "chdman_ffi",
    platforms: [
        .iOS("13.0"),
        .macOS("10.15"),
    ],
    products: [
        .library(name: "chdman-ffi", type: .dynamic, targets: ["chdman_ffi"])
    ],
    targets: [
        // ---- The C++20 wrapper + MAME chd/util/osd subset (via forwarders) ----
        .target(
            name: "chdman_ffi",
            dependencies: [
                "chdman_zlib", "chdman_lzma", "chdman_utf8proc",
                "chdman_zstd", "chdman_flac",
            ],
            cxxSettings: [
                .define("CHDMAN_AVAILABLE", to: "1"),
                .define("DART_SHARED_LIB"),
                // Build the stable vendored codecs + MAME sources release-grade even
                // in Debug (mirrors ../../src/CMakeLists.txt): NDEBUG disables the
                // assert-heavy hot loops (~13x faster CHD creation) and silences
                // libFLAC's `#ifndef NDEBUG` "clipping rice_parameter" stderr spam.
                .define("NDEBUG", to: "1"),
                .define("Z7_ST"),
                .define("_7ZIP_ST"),
                .define("FLAC__NO_DLL"),
                .define("CRLF", to: "3"),
                .define("UTF8PROC_STATIC"),
                // Keep zlib's zconf.h config identical to the chdman_zlib target.
                .define("Z_HAVE_UNISTD_H", to: "1"),
                // Disable Clang modules: with modules on, our vendored zlib clashes
                // with the macOS SDK's own `zlib` module (redefinition of z_stream_s
                // etc.). Textual includes avoid the SDK module entirely.
                .unsafeFlags(["-fno-modules"]),
                // Header search paths, relative to Sources/chdman_ffi and reaching the
                // vendored tree through the package-root `chd` symlink. They resolve
                // inside the package root, which SwiftPM requires.
                .headerSearchPath("../../chd/util"),
                .headerSearchPath("../../chd/osd"),
                .headerSearchPath("../../chd/3rdparty"),            // "lzma/C/LzmaDec.h"
                .headerSearchPath("../../chd/3rdparty/zlib"),       // <zlib.h>
                // zconf.h itself: NOT the zlib dir above. That dir has no real
                // zconf.h (only zconf.h.in/.cmakein/.included -- CMake generates
                // the real one for the Linux/Windows/Android build), so a bare
                // #include "zconf.h" there falls through to the macOS SDK's own
                // system zconf.h, whose LFS64/z_off64_t macros disagree with our
                // zutil.h/crc32.c and cause "conflicting types" build errors.
                .headerSearchPath("../../chd/3rdparty/zlib/spm_public"),
                .headerSearchPath("../../chd/3rdparty/zstd/lib"),   // <zstd.h>
                .headerSearchPath("../../chd/3rdparty/flac/include"), // <FLAC/all.h>
                .headerSearchPath("../../chd/3rdparty/utf8proc"),   // <utf8proc.h>
            ]
        ),

        // ---- zlib (CDZL) ----
        .target(
            name: "chdman_zlib",
            path: "chd/3rdparty/zlib",
            sources: [
                "adler32.c", "compress.c", "crc32.c", "deflate.c", "gzclose.c",
                "gzlib.c", "gzread.c", "gzwrite.c", "infback.c", "inffast.c",
                "inflate.c", "inftrees.c", "trees.c", "uncompr.c", "zutil.c",
            ],
            publicHeadersPath: "spm_public",
            cSettings: [
                // zconf.h only includes <unistd.h> (for write/close/off_t) when this
                // is set; our vendored zconf.h leaves it unset. Must match the consumer.
                .define("Z_HAVE_UNISTD_H", to: "1"),
                .define("NDEBUG", to: "1"), // release-grade codec (see main target)
                // -fno-modules: avoid clashing with the macOS SDK's own `zlib` module.
                .unsafeFlags(["-fno-modules"]),
                // spm_public/zconf.h (see the comment in the main target) so our own
                // crc32.c etc. don't pick up the macOS SDK's system zconf.h either.
                .headerSearchPath("spm_public"),
            ]
        ),

        // ---- LZMA single-threaded subset (CDLZ) ----
        .target(
            name: "chdman_lzma",
            path: "chd/3rdparty/lzma/C",
            sources: [
                "LzmaDec.c", "LzmaEnc.c", "LzFind.c", "Alloc.c", "CpuArch.c",
            ],
            publicHeadersPath: "spm_public",
            cSettings: [
                .define("Z7_ST"),
                .define("_7ZIP_ST"),
                .define("NDEBUG", to: "1"),
                .unsafeFlags(["-fno-modules"]),
            ]
        ),

        // ---- utf8proc (util/unicode.cpp) ----
        .target(
            name: "chdman_utf8proc",
            path: "chd/3rdparty/utf8proc",
            sources: ["utf8proc.c"], // utf8proc_data.c is #included, never compiled alone
            publicHeadersPath: "spm_public",
            cSettings: [
                .define("UTF8PROC_STATIC"),
                .define("NDEBUG", to: "1"),
                .unsafeFlags(["-fno-modules"]),
            ]
        ),

        // ---- zstd (CDZS) — private copy, no ASM, no legacy ----
        .target(
            name: "chdman_zstd",
            path: "chd/3rdparty/zstd/lib",
            sources: ["common", "compress", "decompress"],
            publicHeadersPath: "spm_public",
            cSettings: [
                .headerSearchPath("common"),
                .define("ZSTD_DISABLE_ASM", to: "1"),
                .define("ZSTD_LEGACY_SUPPORT", to: "0"),
                .define("NDEBUG", to: "1"),
                .unsafeFlags(["-fno-modules"]),
            ]
        ),

        // ---- FLAC (CDFL) — static, no OGG. Uses the vendored arch-adaptive
        // src/libFLAC/include/config.h. publicHeadersPath is a dedicated (near-empty)
        // dir, NOT include/FLAC: that real dir contains a FLAC-owned assert.h which,
        // propagated to the consumer as a bare -I, shadows <assert.h> and breaks the
        // `assert` macro everywhere. The consumer gets <FLAC/all.h> from its own
        // explicit -I .../flac/include; this target is depended on only for linking. ----
        .target(
            name: "chdman_flac",
            path: "chd/3rdparty/flac",
            sources: [
                "src/libFLAC/bitmath.c", "src/libFLAC/bitreader.c",
                "src/libFLAC/bitwriter.c", "src/libFLAC/cpu.c", "src/libFLAC/crc.c",
                "src/libFLAC/fixed.c", "src/libFLAC/fixed_intrin_avx2.c",
                "src/libFLAC/fixed_intrin_sse2.c", "src/libFLAC/fixed_intrin_sse42.c",
                "src/libFLAC/fixed_intrin_ssse3.c", "src/libFLAC/float.c",
                "src/libFLAC/format.c", "src/libFLAC/lpc.c",
                "src/libFLAC/lpc_intrin_avx2.c", "src/libFLAC/lpc_intrin_fma.c",
                "src/libFLAC/lpc_intrin_neon.c", "src/libFLAC/lpc_intrin_sse2.c",
                "src/libFLAC/lpc_intrin_sse41.c", "src/libFLAC/md5.c",
                "src/libFLAC/memory.c", "src/libFLAC/metadata_iterators.c",
                "src/libFLAC/metadata_object.c", "src/libFLAC/stream_decoder.c",
                "src/libFLAC/stream_encoder.c", "src/libFLAC/stream_encoder_framing.c",
                "src/libFLAC/stream_encoder_intrin_avx2.c",
                "src/libFLAC/stream_encoder_intrin_sse2.c",
                "src/libFLAC/stream_encoder_intrin_ssse3.c", "src/libFLAC/window.c",
            ],
            publicHeadersPath: "spm_public",
            cSettings: [
                .define("HAVE_CONFIG_H", to: "1"),
                .define("FLAC__NO_DLL"),
                // Silences libFLAC's `#ifndef NDEBUG` "clipping rice_parameter" stderr.
                .define("NDEBUG", to: "1"),
                .headerSearchPath("include"),             // share/*.h, FLAC/*.h
                .headerSearchPath("src/libFLAC/include"), // config.h, private/, protected/
                .unsafeFlags(["-fno-modules"]),
            ]
        ),
    ],
    cxxLanguageStandard: .gnucxx20
)
