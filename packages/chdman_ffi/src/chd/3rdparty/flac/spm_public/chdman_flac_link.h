// Intentionally (almost) empty. This directory is chdman_flac's SwiftPM
// publicHeadersPath. We do NOT expose FLAC's real include/FLAC dir to consumers,
// because that dir contains a FLAC-owned assert.h which, when placed on a bare -I
// search path, shadows the C library <assert.h> and leaves the `assert` macro
// undefined for every consumer TU. The chdman_ffi target reaches <FLAC/all.h>
// through its own explicit -I .../flac/include instead; this dependency exists only
// for LINKING the static libFLAC. See macos/chdman_ffi/Package.swift.
