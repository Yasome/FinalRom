// swift-tools-version: 5.9
// Swift Package Manager manifest for the mbedtls_ffi FFI plugin (macOS).
//
// The native sources are shared across all platforms in ../../src. SwiftPM requires
// a target's sources to live inside the package directory, so Sources/mbedtls_ffi/
// contains a thin forwarder that #includes the shared wrapper, and Sources/mbedtls_src
// is an in-package symlink to ../../../src that brings the whole shared tree (the
// vendored Mbed TLS crypto AND our trimmed crypto_config.h) nominally inside the
// package root. The library is built as a dynamic framework so the Dart side can load
// it via DynamicLibrary.open.
//
// Mbed TLS 4.x exposes crypto only through PSA. The crypto is compiled by the
// `tfpsacrypto` target from the TF-PSA-Crypto subproject's source directories (core +
// platform + utilities + extras + the builtin driver). The everest/p256-m/pqcp ECC
// drivers are omitted: our config disables all asymmetric mechanisms, so they would
// compile to empty objects. Both targets are fed the same PSA config as a full
// replacement via TF_PSA_CRYPTO_CONFIG_FILE so the wrapper and the library agree on
// PSA struct layouts (an ABI must-match). Defining MBEDTLS_AVAILABLE flips the wrapper
// from its stub branch to the real one; it picks up <psa/crypto.h> from the
// tfpsacrypto target's public headers via the target dependency.
import PackageDescription

let package = Package(
    name: "mbedtls_ffi",
    platforms: [
        .iOS("13.0"),
        .macOS("10.15"),
    ],
    products: [
        .library(name: "mbedtls-ffi", type: .dynamic, targets: ["mbedtls_ffi"])
    ],
    targets: [
        .target(
            name: "mbedtls_ffi",
            dependencies: ["tfpsacrypto"],
            cSettings: [
                // src/ (via the symlink) so <psa/crypto.h> -> build_info.h ->
                // #include TF_PSA_CRYPTO_CONFIG_FILE resolves "crypto_config.h".
                .headerSearchPath("../mbedtls_src"),
                // The crypto module's public headers (include/mbedtls/*.h) pull in
                // private headers that live in the builtin driver's include dir, so a
                // consumer building that Clang module needs it on the search path too.
                .headerSearchPath("../mbedtls_src/mbedtls/tf-psa-crypto/drivers/builtin/include"),
                .define("MBEDTLS_AVAILABLE", to: "1"),
                .define("TF_PSA_CRYPTO_CONFIG_FILE", to: "\"crypto_config.h\""),
            ]
        ),
        .target(
            name: "tfpsacrypto",
            path: "Sources/mbedtls_src",
            // Non-source files SwiftPM would otherwise try to feed to clang when a
            // whole directory is listed in `sources`.
            exclude: [
                "mbedtls/tf-psa-crypto/core/CMakeLists.txt",
                "mbedtls/tf-psa-crypto/core/crypto-library.make",
                "mbedtls/tf-psa-crypto/platform/CMakeLists.txt",
                "mbedtls/tf-psa-crypto/utilities/CMakeLists.txt",
                "mbedtls/tf-psa-crypto/extras/CMakeLists.txt",
            ],
            sources: [
                "mbedtls/tf-psa-crypto/core",
                "mbedtls/tf-psa-crypto/platform",
                "mbedtls/tf-psa-crypto/utilities",
                "mbedtls/tf-psa-crypto/extras",
                "mbedtls/tf-psa-crypto/drivers/builtin/src",
            ],
            publicHeadersPath: "mbedtls/tf-psa-crypto/include",
            cSettings: [
                .headerSearchPath("."),  // src/, finds crypto_config.h
                .headerSearchPath("mbedtls/tf-psa-crypto/include"),
                .headerSearchPath("mbedtls/tf-psa-crypto/drivers/builtin/include"),
                .headerSearchPath("mbedtls/tf-psa-crypto/drivers/builtin/src"),
                .headerSearchPath("mbedtls/tf-psa-crypto/core"),
                .headerSearchPath("mbedtls/tf-psa-crypto/dispatch"),
                .headerSearchPath("mbedtls/tf-psa-crypto/extras"),
                .headerSearchPath("mbedtls/tf-psa-crypto/platform"),
                .headerSearchPath("mbedtls/tf-psa-crypto/utilities"),
                .define("TF_PSA_CRYPTO_CONFIG_FILE", to: "\"crypto_config.h\""),
            ]
        ),
    ]
)
