// Forwarder for SwiftPM. The real implementation is the shared wrapper in the
// plugin's src/ directory, reused across every platform. Path is relative to
// THIS file: Sources/zstd_ffi/ -> zstd_ffi/ -> macos/ -> zstd_ffi/ (plugin root)
#include "../../../../src/zstd_ffi.c"
