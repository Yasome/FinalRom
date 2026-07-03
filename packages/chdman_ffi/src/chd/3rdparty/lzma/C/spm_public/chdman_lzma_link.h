// chdman_lzma's SwiftPM publicHeadersPath. Intentionally isolated from the real
// codec headers: SwiftPM builds a C target's publicHeadersPath as an umbrella-directory
// clang module. Umbrella-ing the real codec dir makes SwiftPM see the codec's own
// header (e.g. zlib.h) both as a module submodule AND as its .c sources' textual
// #include -> "redefinition" errors, and can shadow system headers on the consumer's
// -I path. The chdman_ffi target reaches every codec header through explicit -I paths
// instead; this target is depended on only for LINKING. See macos/chdman_ffi/Package.swift.
