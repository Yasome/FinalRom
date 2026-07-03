// swift-tools-version: 5.9
// Swift Package Manager manifest for the xdelta3_ffi FFI plugin (macOS).
//
// The native sources are shared across all platforms in ../../src. SwiftPM requires
// a target's sources to live inside the package directory, so Sources/xdelta3_ffi/
// contains a thin forwarder that #includes the shared wrapper, which in turn
// unity-#includes xdelta/xdelta3.c. The defines mirror the CocoaPods podspec: real
// build with the DJW secondary compressor (no lzma). Built as a dynamic framework.
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
            cSettings: [
                .define("XDELTA3_AVAILABLE", to: "1"),
                .define("SECONDARY_DJW", to: "1"),
                .define("DART_SHARED_LIB", to: "1"),
            ]
        )
    ]
)
