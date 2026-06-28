#include "archive_ffi.h"

/* Stub build. The vendored libarchive sources are not present yet (see
 * src/libarchive/PLACEHOLDER.md), so every entry point reports that the backend
 * is unavailable and the host app falls back / shows "support not built". The
 * real libarchive implementation replaces this file in a later stage. */

FFI_PLUGIN_EXPORT int archive_compress_ex(const char *input_path,
                                          const char *output_path,
                                          int format,
                                          int level,
                                          volatile int *progress_permille,
                                          volatile int *cancel_flag) {
  (void)input_path;
  (void)output_path;
  (void)format;
  (void)level;
  (void)progress_permille;
  (void)cancel_flag;
  return ARCHIVE_FFI_ERR_LIB_UNAVAILABLE;
}

FFI_PLUGIN_EXPORT int archive_extract_ex(const char *input_path,
                                         const char *output_path,
                                         int is_container,
                                         volatile int *progress_permille,
                                         volatile int *cancel_flag) {
  (void)input_path;
  (void)output_path;
  (void)is_container;
  (void)progress_permille;
  (void)cancel_flag;
  return ARCHIVE_FFI_ERR_LIB_UNAVAILABLE;
}
