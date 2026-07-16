// swift-tools-version: 5.9
// Swift Package Manager manifest for the xdelta3_ffi FFI plugin (macOS).
//
// The native sources are shared across all platforms in ../../src. SwiftPM requires
// a target's sources to live inside the package directory, so Sources/xdelta3_ffi/
// contains a thin forwarder that #includes the shared wrapper, which in turn
// unity-#includes xdelta/xdelta3.c. This build enables BOTH the DJW and LZMA
// secondary compressors (parity with the CMake platforms), so patches made with
// `xdelta3 -S lzma` apply here too. liblzma (xz 5.4.6) is compiled as a second SPM
// target `xdelta3_lzma` whose sources live under the in-package `xz` symlink
// (-> ../../src/xz), mirroring how chdman_ffi's manifest builds its vendored codecs.
// The xz tree is built without config.h: its feature set is supplied via -D macros
// (as xz's own MSVC build does), threads off, LZMA1/LZMA2 only.
import PackageDescription

let package = Package(
    name: "xdelta3_ffi",
    platforms: [
        .iOS("13.0"),
        .macOS("10.15"),
    ],
    products: [
        .library(name: "xdelta3-ffi", type: .dynamic, targets: ["xdelta3_ffi"])
    ],
    targets: [
        .target(
            name: "xdelta3_ffi",
            dependencies: ["xdelta3_lzma"],
            cSettings: [
                .define("XDELTA3_AVAILABLE", to: "1"),
                .define("SECONDARY_DJW", to: "1"),
                // xdelta3.c auto-sets SECONDARY_LZMA=1 when HAVE_LZMA_H is defined.
                // LZMA_API_STATIC keeps <lzma.h> from marking the API dllimport
                // (harmless on Darwin; kept for parity with the CMake build).
                .define("HAVE_LZMA_H", to: "1"),
                .define("LZMA_API_STATIC"),
                .define("DART_SHARED_LIB", to: "1"),
                // Include <lzma.h> textually rather than importing the
                // xdelta3_lzma clang module: the auto-generated umbrella
                // module map includes lzma/*.h subheaders directly, which
                // xz's API headers reject (#error unless LZMA_H_INTERNAL).
                .unsafeFlags(["-fno-modules"]),
            ]
        ),

        // ---- liblzma (xz 5.4.6), LZMA1/LZMA2 only, single-threaded. Built from
        // the vendored tree via the in-package `xz` symlink. No config.h: the
        // feature set below comes entirely from -D macros. ----
        .target(
            name: "xdelta3_lzma",
            path: "xz/src",
            sources: [
                "common/tuklib_physmem.c",
                "liblzma/common/block_util.c",
                "liblzma/common/common.c",
                "liblzma/common/easy_preset.c",
                "liblzma/common/filter_common.c",
                "liblzma/common/hardware_physmem.c",
                "liblzma/common/index.c",
                "liblzma/common/stream_flags_common.c",
                "liblzma/common/string_conversion.c",
                "liblzma/common/vli_size.c",
                "liblzma/common/alone_encoder.c",
                "liblzma/common/block_buffer_encoder.c",
                "liblzma/common/block_encoder.c",
                "liblzma/common/block_header_encoder.c",
                "liblzma/common/easy_buffer_encoder.c",
                "liblzma/common/easy_encoder.c",
                "liblzma/common/easy_encoder_memusage.c",
                "liblzma/common/filter_buffer_encoder.c",
                "liblzma/common/filter_encoder.c",
                "liblzma/common/filter_flags_encoder.c",
                "liblzma/common/index_encoder.c",
                "liblzma/common/stream_buffer_encoder.c",
                "liblzma/common/stream_encoder.c",
                "liblzma/common/stream_flags_encoder.c",
                "liblzma/common/vli_encoder.c",
                "liblzma/common/alone_decoder.c",
                "liblzma/common/auto_decoder.c",
                "liblzma/common/block_buffer_decoder.c",
                "liblzma/common/block_decoder.c",
                "liblzma/common/block_header_decoder.c",
                "liblzma/common/easy_decoder_memusage.c",
                "liblzma/common/file_info.c",
                "liblzma/common/filter_buffer_decoder.c",
                "liblzma/common/filter_decoder.c",
                "liblzma/common/filter_flags_decoder.c",
                "liblzma/common/index_decoder.c",
                "liblzma/common/index_hash.c",
                "liblzma/common/stream_buffer_decoder.c",
                "liblzma/common/stream_decoder.c",
                "liblzma/common/stream_flags_decoder.c",
                "liblzma/common/vli_decoder.c",
                "liblzma/check/check.c",
                "liblzma/check/crc32_fast.c",
                "liblzma/check/crc32_table.c",
                "liblzma/check/crc64_fast.c",
                "liblzma/check/crc64_table.c",
                "liblzma/check/sha256.c",
                "liblzma/lz/lz_encoder.c",
                "liblzma/lz/lz_encoder_mf.c",
                "liblzma/lz/lz_decoder.c",
                "liblzma/lzma/fastpos_table.c",
                "liblzma/lzma/lzma_encoder.c",
                "liblzma/lzma/lzma_encoder_optimum_fast.c",
                "liblzma/lzma/lzma_encoder_optimum_normal.c",
                "liblzma/lzma/lzma_encoder_presets.c",
                "liblzma/lzma/lzma_decoder.c",
                "liblzma/lzma/lzma2_encoder.c",
                "liblzma/lzma/lzma2_decoder.c",
                "liblzma/rangecoder/price_table.c",
            ],
            publicHeadersPath: "liblzma/api",
            cSettings: [
                .headerSearchPath("liblzma/api"),
                .headerSearchPath("liblzma/common"),
                .headerSearchPath("liblzma/check"),
                .headerSearchPath("liblzma/lz"),
                .headerSearchPath("liblzma/lzma"),
                .headerSearchPath("liblzma/rangecoder"),
                // The simple/ and delta/ filters are compiled out (no HAVE_*
                // defines for them), but filter_encoder.c/filter_decoder.c
                // #include their headers unconditionally.
                .headerSearchPath("liblzma/simple"),
                .headerSearchPath("liblzma/delta"),
                .headerSearchPath("common"),
                .define("HAVE_STDBOOL_H", to: "1"),
                .define("HAVE__BOOL", to: "1"),
                .define("HAVE_STDINT_H", to: "1"),
                .define("HAVE_INTTYPES_H", to: "1"),
                .define("HAVE_ENCODERS", to: "1"),
                .define("HAVE_DECODERS", to: "1"),
                .define("HAVE_ENCODER_LZMA1", to: "1"),
                .define("HAVE_DECODER_LZMA1", to: "1"),
                .define("HAVE_ENCODER_LZMA2", to: "1"),
                .define("HAVE_DECODER_LZMA2", to: "1"),
                .define("HAVE_MF_HC3", to: "1"),
                .define("HAVE_MF_HC4", to: "1"),
                .define("HAVE_MF_BT2", to: "1"),
                .define("HAVE_MF_BT3", to: "1"),
                .define("HAVE_MF_BT4", to: "1"),
                .define("HAVE_CHECK_CRC32", to: "1"),
                .define("HAVE_CHECK_CRC64", to: "1"),
                .define("HAVE_CHECK_SHA256", to: "1"),
                .define("TUKLIB_SYMBOL_PREFIX", to: "lzma_"),
                .define("NDEBUG", to: "1"),
                .unsafeFlags(["-fno-modules"]),
            ]
        ),
    ]
)
