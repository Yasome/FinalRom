#ifndef ARCHIVE_FFI_H
#define ARCHIVE_FFI_H

#ifdef __cplusplus
extern "C" {
#endif

#if defined(_WIN32)
#define FFI_PLUGIN_EXPORT __declspec(dllexport)
#else
#define FFI_PLUGIN_EXPORT __attribute__((visibility("default"))) __attribute__((used))
#endif

/* Result codes returned by the archive wrapper. */
#define ARCHIVE_FFI_OK 0
#define ARCHIVE_FFI_ERR_OPEN_INPUT (-7101)
#define ARCHIVE_FFI_ERR_OPEN_OUTPUT (-7102)
#define ARCHIVE_FFI_ERR_FORMAT (-7103)   /* unreadable / unsupported archive */
#define ARCHIVE_FFI_ERR_INTERNAL (-7106)
#define ARCHIVE_FFI_ERR_CANCELLED (-7107)

/* The native library was built without the vendored libarchive sources. */
#define ARCHIVE_FFI_ERR_LIB_UNAVAILABLE (-6000)

/* Compression format selectors for archive_compress_ex. */
#define ARCHIVE_FFI_FORMAT_ZIP 0
#define ARCHIVE_FFI_FORMAT_GZIP 1
#define ARCHIVE_FFI_FORMAT_ZSTD 2
#define ARCHIVE_FFI_FORMAT_7ZIP 3
/* 4+ reserved (tar, ...). */

/* Progress is reported by writing 0..1000 (per-mille complete) into the int
 * pointed to by progress_permille, if non-NULL. The native side only writes;
 * the caller reads it concurrently (e.g. from another isolate/thread). */

/* Cooperative cancellation: if cancel_flag is non-NULL and the caller stores a
 * non-zero value into it from another thread/isolate, the operation stops at
 * the next polling point and returns ARCHIVE_FFI_ERR_CANCELLED. The caller MUST
 * keep both the cancel_flag and progress_permille memory alive until the call
 * returns. */

/* Compresses the single file at input_path into the archive at output_path.
 * format is one of ARCHIVE_FFI_FORMAT_*; level <= 0 selects the format default.
 * Returns ARCHIVE_FFI_OK on success. */
FFI_PLUGIN_EXPORT int archive_compress_ex(const char *input_path,
                                          const char *output_path,
                                          int format,
                                          int level,
                                          volatile int *progress_permille,
                                          volatile int *cancel_flag);

/* Extracts the archive at input_path. When is_container is non-zero (zip, 7z,
 * tar, ...), entries are written under the directory output_path; when zero
 * (a single raw stream such as gzip/zstd), the decompressed bytes are written
 * to the file output_path. Returns ARCHIVE_FFI_OK on success. */
FFI_PLUGIN_EXPORT int archive_extract_ex(const char *input_path,
                                         const char *output_path,
                                         int is_container,
                                         volatile int *progress_permille,
                                         volatile int *cancel_flag);

#ifdef __cplusplus
}
#endif

#endif /* ARCHIVE_FFI_H */
