#include "archive_ffi.h"

/* The real backend is compiled only when the vendored libarchive sources are
 * present (the CMake build defines ARCHIVE_FFI_HAVE_LIBARCHIVE). Without them a
 * stub is built so the host app still links and runs, with every entry point
 * reporting ARCHIVE_FFI_ERR_LIB_UNAVAILABLE. See src/libarchive/PLACEHOLDER.md. */

#if defined(ARCHIVE_FFI_HAVE_LIBARCHIVE)

#include <archive.h>
#include <archive_entry.h>
#include <stdio.h>
#include <stdlib.h>
#include <string.h>

#define ARCHIVE_FFI_BLOCK (1 << 20) /* 1 MiB streaming buffer */

/* Returns the file-name component of a path (after the last '/' or '\\'). */
static const char *base_name(const char *path)
{
  const char *name = path;
  for (const char *p = path; *p != '\0'; ++p)
  {
    if (*p == '/' || *p == '\\')
      name = p + 1;
  }
  return name;
}

static long long file_size_of(const char *path)
{
  FILE *file = fopen(path, "rb");
  if (file == NULL)
    return -1;
#if defined(_WIN32)
  _fseeki64(file, 0, SEEK_END);
  long long size = _ftelli64(file);
#else
  fseeko(file, 0, SEEK_END);
  long long size = (long long)ftello(file);
#endif
  fclose(file);
  return size;
}

static void set_progress(volatile int *cell, long long done, long long total)
{
  if (cell == NULL)
    return;
  if (total <= 0)
  {
    *cell = 1000;
    return;
  }
  if (done > total)
    done = total;
  *cell = (int)((done * 1000) / total);
}

static int is_cancelled(volatile int *cell)
{
  return cell != NULL && *cell != 0;
}

FFI_PLUGIN_EXPORT int archive_compress_ex(const char *input_path,
                                          const char *output_path,
                                          int format,
                                          int level,
                                          volatile int *progress_permille,
                                          volatile int *cancel_flag)
{
  int result = ARCHIVE_FFI_OK;
  struct archive *out = NULL;
  struct archive_entry *entry = NULL;
  FILE *in = NULL;
  char *buffer = NULL;
  int output_opened = 0;

  const long long total = file_size_of(input_path);
  if (total < 0)
    return ARCHIVE_FFI_ERR_OPEN_INPUT;

  out = archive_write_new();
  if (out == NULL)
    return ARCHIVE_FFI_ERR_INTERNAL;

  switch (format)
  {
  case ARCHIVE_FFI_FORMAT_ZIP:
    archive_write_set_format_zip(out);
    break;
  case ARCHIVE_FFI_FORMAT_GZIP:
    archive_write_set_format_raw(out);
    archive_write_add_filter_gzip(out);
    break;
  case ARCHIVE_FFI_FORMAT_ZSTD:
    archive_write_set_format_raw(out);
    archive_write_add_filter_zstd(out);
    break;
  case ARCHIVE_FFI_FORMAT_7ZIP:
    archive_write_set_format_7zip(out);
    archive_write_set_options(out, "7zip:compression=lzma2");
    break;
  default:
    archive_write_free(out);
    return ARCHIVE_FFI_ERR_FORMAT;
  }

  /* Best-effort compression level: the option name is module-specific and not
   * every build supports it, so an ARCHIVE_WARN/FAILED here is non-fatal. */
  if (level > 0)
  {
    const char *module = NULL;
    switch (format)
    {
    case ARCHIVE_FFI_FORMAT_ZIP:
      module = "zip";
      break;
    case ARCHIVE_FFI_FORMAT_GZIP:
      module = "gzip";
      break;
    case ARCHIVE_FFI_FORMAT_ZSTD:
      module = "zstd";
      break;
    case ARCHIVE_FFI_FORMAT_7ZIP:
      module = "7zip";
      break;
    default:
      break;
    }
    if (module != NULL)
    {
      char option[64];
      snprintf(option, sizeof(option), "%s:compression-level=%d", module, level);
      archive_write_set_options(out, option);
    }
  }

  if (archive_write_open_filename(out, output_path) != ARCHIVE_OK)
  {
    archive_write_free(out);
    return ARCHIVE_FFI_ERR_OPEN_OUTPUT;
  }
  output_opened = 1;

  in = fopen(input_path, "rb");
  if (in == NULL)
  {
    result = ARCHIVE_FFI_ERR_OPEN_INPUT;
    goto cleanup;
  }

  entry = archive_entry_new();
  archive_entry_set_pathname(entry, base_name(input_path));
  archive_entry_set_size(entry, total);
  archive_entry_set_filetype(entry, AE_IFREG);
  archive_entry_set_perm(entry, 0644);
  if (archive_write_header(out, entry) != ARCHIVE_OK)
  {
    result = ARCHIVE_FFI_ERR_INTERNAL;
    goto cleanup;
  }

  buffer = (char *)malloc(ARCHIVE_FFI_BLOCK);
  if (buffer == NULL)
  {
    result = ARCHIVE_FFI_ERR_INTERNAL;
    goto cleanup;
  }

  long long done = 0;
  for (;;)
  {
    if (is_cancelled(cancel_flag))
    {
      result = ARCHIVE_FFI_ERR_CANCELLED;
      goto cleanup;
    }
    size_t read = fread(buffer, 1, ARCHIVE_FFI_BLOCK, in);
    if (read == 0)
    {
      if (ferror(in))
        result = ARCHIVE_FFI_ERR_OPEN_INPUT;
      break; /* EOF */
    }
    if (archive_write_data(out, buffer, read) < 0)
    {
      result = ARCHIVE_FFI_ERR_INTERNAL;
      goto cleanup;
    }
    done += (long long)read;
    set_progress(progress_permille, done, total);
  }

  if (result == ARCHIVE_FFI_OK)
    set_progress(progress_permille, total, total);

cleanup:
  if (buffer != NULL)
    free(buffer);
  if (entry != NULL)
    archive_entry_free(entry);
  if (in != NULL)
    fclose(in);
  if (output_opened)
    archive_write_close(out);
  archive_write_free(out);
  if (result != ARCHIVE_FFI_OK)
    remove(output_path);
  return result;
}

/* Streams one container entry from the read archive to the write-to-disk
 * archive, polling for cancellation between blocks. */
static int copy_entry_to_disk(struct archive *reader, struct archive *disk,
                              volatile int *cancel_flag)
{
  for (;;)
  {
    if (is_cancelled(cancel_flag))
      return ARCHIVE_FFI_ERR_CANCELLED;
    const void *block;
    size_t size;
    la_int64_t offset;
    int r = archive_read_data_block(reader, &block, &size, &offset);
    if (r == ARCHIVE_EOF)
      return ARCHIVE_FFI_OK;
    if (r < ARCHIVE_OK)
      return ARCHIVE_FFI_ERR_FORMAT;
    if (archive_write_data_block(disk, block, size, offset) < ARCHIVE_OK)
    {
      return ARCHIVE_FFI_ERR_OPEN_OUTPUT;
    }
  }
}

static int extract_container(struct archive *reader, const char *output_dir,
                             long long total, volatile int *progress_permille,
                             volatile int *cancel_flag)
{
  int result = ARCHIVE_FFI_OK;
  struct archive *disk = archive_write_disk_new();
  if (disk == NULL)
    return ARCHIVE_FFI_ERR_INTERNAL;
  archive_write_disk_set_options(
      disk, ARCHIVE_EXTRACT_TIME | ARCHIVE_EXTRACT_PERM |
                ARCHIVE_EXTRACT_SECURE_NODOTDOT | ARCHIVE_EXTRACT_SECURE_SYMLINKS);
  archive_write_disk_set_standard_lookup(disk);

  for (;;)
  {
    if (is_cancelled(cancel_flag))
    {
      result = ARCHIVE_FFI_ERR_CANCELLED;
      break;
    }
    struct archive_entry *entry;
    int r = archive_read_next_header(reader, &entry);
    if (r == ARCHIVE_EOF)
      break;
    if (r < ARCHIVE_OK)
    {
      result = ARCHIVE_FFI_ERR_FORMAT;
      break;
    }

    /* Re-root each entry under output_dir; the secure flags above still guard
     * against path traversal within it. */
    const char *name = archive_entry_pathname(entry);
    size_t needed = strlen(output_dir) + 1 + strlen(name) + 1;
    char *full = (char *)malloc(needed);
    if (full == NULL)
    {
      result = ARCHIVE_FFI_ERR_INTERNAL;
      break;
    }
    snprintf(full, needed, "%s/%s", output_dir, name);
    archive_entry_set_pathname(entry, full);
    free(full);

    if (archive_write_header(disk, entry) < ARCHIVE_OK)
    {
      result = ARCHIVE_FFI_ERR_OPEN_OUTPUT;
      break;
    }
    if (archive_entry_size(entry) > 0)
    {
      int copied = copy_entry_to_disk(reader, disk, cancel_flag);
      if (copied != ARCHIVE_FFI_OK)
      {
        result = copied;
        break;
      }
    }
    archive_write_finish_entry(disk);
    set_progress(progress_permille, archive_filter_bytes(reader, -1), total);
  }

  archive_write_close(disk);
  archive_write_free(disk);
  return result;
}

static int extract_raw(struct archive *reader, const char *output_path,
                       long long total, volatile int *progress_permille,
                       volatile int *cancel_flag)
{
  struct archive_entry *entry;
  if (archive_read_next_header(reader, &entry) < ARCHIVE_OK)
  {
    return ARCHIVE_FFI_ERR_FORMAT;
  }

  FILE *out = fopen(output_path, "wb");
  if (out == NULL)
    return ARCHIVE_FFI_ERR_OPEN_OUTPUT;

  char *buffer = (char *)malloc(ARCHIVE_FFI_BLOCK);
  if (buffer == NULL)
  {
    fclose(out);
    return ARCHIVE_FFI_ERR_INTERNAL;
  }

  int result = ARCHIVE_FFI_OK;
  for (;;)
  {
    if (is_cancelled(cancel_flag))
    {
      result = ARCHIVE_FFI_ERR_CANCELLED;
      break;
    }
    la_ssize_t read = archive_read_data(reader, buffer, ARCHIVE_FFI_BLOCK);
    if (read == 0)
      break; /* EOF */
    if (read < 0)
    {
      result = ARCHIVE_FFI_ERR_FORMAT;
      break;
    }
    if (fwrite(buffer, 1, (size_t)read, out) != (size_t)read)
    {
      result = ARCHIVE_FFI_ERR_OPEN_OUTPUT;
      break;
    }
    set_progress(progress_permille, archive_filter_bytes(reader, -1), total);
  }

  free(buffer);
  fclose(out);
  return result;
}

FFI_PLUGIN_EXPORT int archive_extract_ex(const char *input_path,
                                         const char *output_path,
                                         int is_container,
                                         volatile int *progress_permille,
                                         volatile int *cancel_flag)
{
  struct archive *reader = archive_read_new();
  if (reader == NULL)
    return ARCHIVE_FFI_ERR_INTERNAL;

  const long long total = file_size_of(input_path);

  if (is_container)
  {
    archive_read_support_format_all(reader);
    archive_read_support_filter_all(reader);
  }
  else
  {
    /* A single raw stream (gzip/zstd): the "raw" format yields one pseudo-entry
     * whose data is the decompressed bytes. */
    archive_read_support_format_raw(reader);
    archive_read_support_filter_all(reader);
  }

  if (archive_read_open_filename(reader, input_path, ARCHIVE_FFI_BLOCK) !=
      ARCHIVE_OK)
  {
    archive_read_free(reader);
    return ARCHIVE_FFI_ERR_OPEN_INPUT;
  }

  int result = is_container
                   ? extract_container(reader, output_path, total,
                                       progress_permille, cancel_flag)
                   : extract_raw(reader, output_path, total, progress_permille,
                                 cancel_flag);

  archive_read_close(reader);
  archive_read_free(reader);

  if (result == ARCHIVE_FFI_OK)
  {
    set_progress(progress_permille, total, total);
  }
  else if (!is_container)
  {
    /* Best-effort cleanup of the single restored file; the Dart worker removes a
     * partial extraction directory for the container case. */
    remove(output_path);
  }
  return result;
}

#else /* !ARCHIVE_FFI_HAVE_LIBARCHIVE — stub build */

FFI_PLUGIN_EXPORT int archive_compress_ex(const char *input_path,
                                          const char *output_path,
                                          int format,
                                          int level,
                                          volatile int *progress_permille,
                                          volatile int *cancel_flag)
{
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
                                         volatile int *cancel_flag)
{
  (void)input_path;
  (void)output_path;
  (void)is_container;
  (void)progress_permille;
  (void)cancel_flag;
  return ARCHIVE_FFI_ERR_LIB_UNAVAILABLE;
}

#endif /* ARCHIVE_FFI_HAVE_LIBARCHIVE */
