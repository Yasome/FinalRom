#ifndef CHDMAN_FFI_H
#define CHDMAN_FFI_H

#ifdef __cplusplus
extern "C" {
#endif

#if defined(_WIN32)
#define FFI_PLUGIN_EXPORT __declspec(dllexport)
#else
#define FFI_PLUGIN_EXPORT __attribute__((visibility("default"))) __attribute__((used))
#endif

/* Result codes returned by the chdman wrapper. */
#define CHDMAN_FFI_OK 0
#define CHDMAN_FFI_ERR_OPEN_INPUT (-7001)
#define CHDMAN_FFI_ERR_OPEN_OUTPUT (-7002)
#define CHDMAN_FFI_ERR_INVALID_INPUT (-7003)
#define CHDMAN_FFI_ERR_OUTPUT_EXISTS (-7004)
#define CHDMAN_FFI_ERR_CODEC (-7005)
#define CHDMAN_FFI_ERR_INTERNAL (-7006)
#define CHDMAN_FFI_ERR_CANCELLED (-7007)

/* The native library was built without the vendored MAME chd sources. */
#define CHDMAN_FFI_ERR_LIB_UNAVAILABLE (-6000)

/* Caller-tunable options, mirroring the relevant chdman command-line flags.
 * A NULL options pointer (or zero/empty field) selects the documented default
 * for that field, so callers only set what they care about. */
typedef struct chdman_options {
  /* Comma-separated CD codec tokens for create, tried in order per hunk:
   * "cdlz" (LZMA), "cdzl" (Deflate), "cdfl" (FLAC), "cdzs" (Zstandard),
   * "none". NULL/empty means the chdman default "cdlz,cdzl,cdfl". Ignored by
   * extract. */
  const char *codecs;
  /* Max CPU threads chdman may use (chdman -np). <= 0 means all processors. */
  int num_processors;
  /* CHD hunk size in bytes for create (chdman -hs). <= 0 means the default
   * (cdrom_file::FRAMES_PER_HUNK * cdrom_file::FRAME_SIZE). Ignored by extract. */
  int hunk_bytes;
  /* Non-zero overwrites existing output files instead of failing. */
  int force;
} chdman_options;

/* Progress is reported by writing 0..1000 (per-mille complete) into the int
 * pointed to by progress_permille, if non-NULL. The native side only writes;
 * the caller reads it concurrently (e.g. from another isolate/thread). */

/* Cooperative cancellation: if cancel_flag is non-NULL and the caller stores a
 * non-zero value into it from another thread/isolate, the operation stops at
 * the next polling point, deletes any partial output, and returns
 * CHDMAN_FFI_ERR_CANCELLED. The caller MUST keep both the cancel_flag and
 * progress_permille memory alive until the call returns, since the native side
 * (and its worker threads) write to them right up to that point. */

/* Creates a CD CHD at output_chd_path from a CD image (.cue/.gdi/.toc/.iso)
 * at input_path. options may be NULL for all defaults. Returns CHDMAN_FFI_OK
 * on success. */
FFI_PLUGIN_EXPORT int chdman_create_cd_ex(const char *input_path,
                                          const char *output_chd_path,
                                          const chdman_options *options,
                                          volatile int *progress_permille,
                                          volatile int *cancel_flag);

/* Creates a DVD CHD at output_chd_path from a raw DVD image (.iso) at
 * input_path. The input is treated as a flat stream of 2048-byte logical
 * sectors (chdman createdvd), so its size must be a multiple of 2048. The
 * options.codecs field accepts the general codec tokens "lzma","zlib","huff",
 * "flac","zstd","none"; NULL/empty (or any CD token) selects the createdvd
 * default "lzma,zlib,huff,flac". options may be NULL for all defaults. Returns
 * CHDMAN_FFI_OK on success. */
FFI_PLUGIN_EXPORT int chdman_create_dvd_ex(const char *input_path,
                                           const char *output_chd_path,
                                           const chdman_options *options,
                                           volatile int *progress_permille,
                                           volatile int *cancel_flag);

/* Extracts a CD CHD at input_chd_path back to a .cue/.bin pair. Only the force
 * field of options is used. options may be NULL. Returns CHDMAN_FFI_OK. */
FFI_PLUGIN_EXPORT int chdman_extract_cd_ex(const char *input_chd_path,
                                           const char *output_cue_path,
                                           const char *output_bin_path,
                                           const chdman_options *options,
                                           volatile int *progress_permille,
                                           volatile int *cancel_flag);

/* Back-compatible wrappers using all defaults and no progress reporting. */
FFI_PLUGIN_EXPORT int chdman_create_cd(const char *input_path,
                                       const char *output_chd_path,
                                       int force);

FFI_PLUGIN_EXPORT int chdman_create_dvd(const char *input_path,
                                        const char *output_chd_path,
                                        int force);

FFI_PLUGIN_EXPORT int chdman_extract_cd(const char *input_chd_path,
                                        const char *output_cue_path,
                                        const char *output_bin_path,
                                        int force);

#ifdef __cplusplus
}
#endif

#endif /* CHDMAN_FFI_H */
