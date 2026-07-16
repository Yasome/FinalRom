// Forwarder for SwiftPM. The real implementation is the shared wrapper in the
// plugin's src/ directory (which unity-#includes xdelta/xdelta3.c). Path is
// relative to THIS file:
//   Sources/xdelta3_ffi/ -> xdelta3_ffi/ -> macos/ -> xdelta3_ffi/ (plugin root)
#include "../../../../src/xdelta3_ffi.c"
