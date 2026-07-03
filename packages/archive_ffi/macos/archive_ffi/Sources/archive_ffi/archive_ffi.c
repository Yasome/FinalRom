// Forwarder for SwiftPM. The real implementation is the shared wrapper in the
// plugin's src/ directory, reused across every platform. SwiftPM cannot list
// sources outside the package directory, so this file pulls it in via a relative
// #include (path is relative to THIS file):
//   Sources/archive_ffi/ -> archive_ffi/ -> macos/ -> archive_ffi/ (plugin root)
#include "../../../../src/archive_ffi.c"
