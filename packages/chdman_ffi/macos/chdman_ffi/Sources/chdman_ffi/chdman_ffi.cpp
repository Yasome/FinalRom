// Forwarder for SwiftPM. The real implementation is the shared C++ wrapper in the
// plugin's src/ directory, reused across every platform. Path is relative to THIS
// file: Sources/chdman_ffi/ -> chdman_ffi/ -> macos/ -> chdman_ffi/ (plugin root)
#include "../../../../src/chdman_ffi.cpp"
