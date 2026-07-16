// swift-tools-version: 5.9
// Swift Package Manager manifest for the archive_ffi FFI plugin (macOS).
//
// The native sources are shared across all platforms in ../../src. SwiftPM requires
// a target's sources to live inside the package directory, so Sources/archive_ffi/
// contains a thin forwarder that #includes the shared wrapper (the same trick the
// CocoaPods podspec and Flutter's FFI template use). The library is built as a
// dynamic framework so the Dart side can load it via
// DynamicLibrary.open('archive_ffi.framework/archive_ffi').
import PackageDescription

let package = Package(
    name: "archive_ffi",
    platforms: [
        .iOS("13.0"),
        .macOS("10.15"),
    ],
    products: [
        .library(name: "archive-ffi", type: .dynamic, targets: ["archive_ffi"])
    ],
    targets: [
        .target(name: "archive_ffi")
    ]
)
