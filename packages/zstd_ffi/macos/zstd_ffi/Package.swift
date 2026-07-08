// swift-tools-version: 5.9
// Swift Package Manager manifest for the zstd_ffi FFI plugin (macOS).
//
// The native sources are shared across all platforms in ../../src. SwiftPM requires
// a target's sources to live inside the package directory, so Sources/zstd_ffi/
// contains a thin forwarder that #includes the shared wrapper. The library is built
// as a dynamic framework so the Dart side can load it via DynamicLibrary.open.
//
// The real libzstd is compiled by a second SPM target `libzstd` whose sources live
// under Sources/libzstd — an in-package symlink to ../../src/zstd/lib. SwiftPM
// forbids source dirs and header-search-paths outside the package root, so the
// symlink brings the vendored tree nominally *inside* the root. This mirrors the
// vendored upstream manifest's own `libzstd` target (lib/{common,compress,
// decompress}, publicHeadersPath "."; dictBuilder is omitted — the wrapper
// never calls the ZDICT_* API). Defining ZSTD_AVAILABLE flips
// the wrapper from its stub branch to the real one; it picks up <zstd.h> from the
// libzstd target's public headers via the target dependency.
import PackageDescription

let package = Package(
    name: "zstd_ffi",
    platforms: [
        .iOS("13.0"),
        .macOS("10.15"),
    ],
    products: [
        .library(name: "zstd-ffi", type: .dynamic, targets: ["zstd_ffi"])
    ],
    targets: [
        .target(
            name: "zstd_ffi",
            dependencies: ["libzstd"],
            cSettings: [
                .define("ZSTD_AVAILABLE", to: "1")
            ]
        ),
        .target(
            name: "libzstd",
            path: "Sources/libzstd",
            sources: ["common", "compress", "decompress"],
            publicHeadersPath: ".",
            cSettings: [
                .headerSearchPath("."),
                // Enable multi-threaded compression (ZSTD_c_nbWorkers), matching the
                // CMake build's ZSTD_MULTITHREAD_SUPPORT=ON. The MT source
                // (compress/zstdmt_compress.c) is already compiled; this macro flips it
                // on. On Darwin pthread is in libSystem, so no extra link flag is needed.
                .define("ZSTD_MULTITHREAD"),
            ]
        ),
    ]
)
