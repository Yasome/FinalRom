/*
 * Thin C-ABI wrapper around MAME's CHD ("chdman") library so CD CHD images can
 * be created and extracted from Dart via dart:ffi. The create/extract logic is
 * adapted from MAME's `src/tools/chdman.cpp` (do_create_cd / do_extract_cd),
 * with the command-line front-end replaced by plain exported functions that
 * return result codes instead of calling report_error()/exit().
 *
 * The MAME chd sources live under ./chd (vendored subset of MAME's util/osd
 * plus the zlib/lzma/FLAC/zstd/utf8proc codec dependencies). When
 * chd/util/chd.cpp is present the CMake build defines CHDMAN_AVAILABLE and the
 * real implementation below is compiled; otherwise a stub is built that reports
 * CHDMAN_FFI_ERR_LIB_UNAVAILABLE so the host app still builds and links.
 */

#include "chdman_ffi.h"

#ifdef CHDMAN_AVAILABLE

#include <cstdio>
#include <cstdlib>
#include <cstring>
#include <memory>
#include <string>
#include <vector>

#include "chd.h"
#include "chdcodec.h"
#include "cdrom.h"
#include "corefile.h"
#include "coretmpl.h"
#include "ioprocs.h"

namespace {

bool file_exists(const char *path) {
  if (!path) return false;
  FILE *probe = std::fopen(path, "rb");
  if (!probe) return false;
  std::fclose(probe);
  return true;
}

// MSF (minute:second:frame) string for a CD frame count, as chdman emits in cues.
std::string msf_string_from_frames(uint32_t frames) {
  char buffer[16];
  std::snprintf(buffer, sizeof(buffer), "%02d:%02d:%02d",
                frames / (75 * 60), (frames / 75) % 60, frames % 75);
  return std::string(buffer);
}

// ======================> chd_cd_compressor (ported from chdman.cpp)
class chd_cd_compressor : public chd_file_compressor {
 public:
  chd_cd_compressor(cdrom_file::toc &toc, cdrom_file::track_input_info &info)
      : m_file(), m_toc(toc), m_info(info) {}
  ~chd_cd_compressor() {}

  virtual uint32_t read_data(void *_dest, uint64_t offset, uint32_t length) override {
    if ((offset % cdrom_file::FRAME_SIZE) != 0 || (length % cdrom_file::FRAME_SIZE) != 0) {
      return 0;
    }
    uint8_t *dest = reinterpret_cast<uint8_t *>(_dest);
    std::memset(dest, 0, length);

    uint64_t startoffs = 0;
    uint32_t length_remaining = length;
    for (int tracknum = 0; tracknum < m_toc.numtrks; tracknum++) {
      const cdrom_file::track_info &trackinfo = m_toc.tracks[tracknum];
      uint64_t endoffs =
          startoffs + (uint64_t)(trackinfo.frames + trackinfo.extraframes) * cdrom_file::FRAME_SIZE;

      if (offset >= startoffs && offset < endoffs) {
        if (!m_file || m_lastfile.compare(m_info.track[tracknum].fname) != 0) {
          m_file.reset();
          m_lastfile = m_info.track[tracknum].fname;
          std::error_condition const filerr =
              util::core_file::open(m_lastfile, OPEN_FLAG_READ, m_file);
          if (filerr) throw filerr;
        }

        uint64_t bytesperframe = trackinfo.datasize + trackinfo.subsize;
        uint64_t src_track_start = m_info.track[tracknum].offset;
        uint64_t src_track_end = src_track_start + bytesperframe * (uint64_t)trackinfo.frames;
        uint64_t split_track_start = src_track_end - ((uint64_t)trackinfo.splitframes * bytesperframe);
        uint64_t pad_track_start = split_track_start - ((uint64_t)trackinfo.padframes * bytesperframe);

        if ((uint64_t)trackinfo.splitframes == 0L) split_track_start = UINT64_MAX;

        while (length_remaining != 0 && offset < endoffs) {
          uint64_t src_frame_start =
              src_track_start + ((offset - startoffs) / cdrom_file::FRAME_SIZE) * bytesperframe;

          if (src_frame_start >= split_track_start && src_frame_start < src_track_end &&
              m_lastfile.compare(m_info.track[tracknum + 1].fname) != 0) {
            m_file.reset();
            m_lastfile = m_info.track[tracknum + 1].fname;
            std::error_condition const filerr =
                util::core_file::open(m_lastfile, OPEN_FLAG_READ, m_file);
            if (filerr) throw filerr;
          }

          if (src_frame_start < src_track_end) {
            if (src_frame_start >= pad_track_start && src_frame_start < split_track_start) {
              std::memset(dest, 0, bytesperframe);
            } else {
              std::error_condition err = m_file->seek(
                  (src_frame_start >= split_track_start) ? src_frame_start - split_track_start
                                                         : src_frame_start,
                  SEEK_SET);
              std::size_t count = 0;
              if (!err) std::tie(err, count) = util::read(*m_file, dest, bytesperframe);
              if (err || (count != bytesperframe)) throw std::error_condition(std::errc::io_error);
            }

            if (m_info.track[tracknum].swap)
              for (uint32_t swapindex = 0; swapindex < 2352; swapindex += 2) {
                uint8_t temp = dest[swapindex];
                dest[swapindex] = dest[swapindex + 1];
                dest[swapindex + 1] = temp;
              }
          }

          offset += cdrom_file::FRAME_SIZE;
          dest += cdrom_file::FRAME_SIZE;
          length_remaining -= cdrom_file::FRAME_SIZE;
          if (length_remaining == 0) break;
        }
      }
      startoffs = endoffs;
    }
    return length - length_remaining;
  }

 private:
  util::core_file::ptr m_file;
  std::string m_lastfile;
  cdrom_file::toc &m_toc;
  cdrom_file::track_input_info &m_info;
};

// ======================> chd_rawfile_compressor (ported from chdman.cpp)
// Feeds a flat byte range of an already-open file to the compressor, with no CD
// framing. Used by createdvd, where the input ISO is just a stream of 2048-byte
// logical sectors. The referenced file must outlive this object (its worker
// threads read through m_file until the compressor is destroyed).
class chd_rawfile_compressor : public chd_file_compressor {
 public:
  chd_rawfile_compressor(util::random_read &file, uint64_t offset, uint64_t maxoffset)
      : m_file(file), m_offset(offset), m_maxoffset(maxoffset) {}

  virtual uint32_t read_data(void *dest, uint64_t offset, uint32_t length) override {
    offset += m_offset;
    if (offset >= m_maxoffset) return 0;
    if (offset + length > m_maxoffset) length = static_cast<uint32_t>(m_maxoffset - offset);
    auto const [err, actual] = util::read_at(m_file, offset, dest, length);
    if (err) throw err;
    return static_cast<uint32_t>(actual);
  }

 private:
  util::random_read &m_file;
  uint64_t m_offset;
  uint64_t m_maxoffset;
};

// Maps a comma-separated chdman codec token list (e.g. "cdlz,cdzl,cdfl") to the
// chd_codec_type array create() expects. NULL/empty input, or any unrecognized
// token, leaves the chdman CD default in place. The array is always
// CHD_CODEC_NONE-terminated within its 4 slots.
void parse_cd_codecs(const char *codecs, chd_codec_type out[4]) {
  out[0] = CHD_CODEC_CD_LZMA;
  out[1] = CHD_CODEC_CD_ZLIB;
  out[2] = CHD_CODEC_CD_FLAC;
  out[3] = CHD_CODEC_NONE;
  if (!codecs || !*codecs) return;

  chd_codec_type parsed[4] = {CHD_CODEC_NONE, CHD_CODEC_NONE, CHD_CODEC_NONE, CHD_CODEC_NONE};
  int count = 0;
  const std::string list(codecs);
  size_t start = 0;
  while (count < 4 && start <= list.size()) {
    const size_t comma = list.find(',', start);
    std::string token = list.substr(start, comma == std::string::npos ? std::string::npos : comma - start);
    const size_t first = token.find_first_not_of(" \t");
    const size_t last = token.find_last_not_of(" \t");
    token = (first == std::string::npos) ? std::string() : token.substr(first, last - first + 1);

    chd_codec_type type;
    if (token == "cdlz") type = CHD_CODEC_CD_LZMA;
    else if (token == "cdzl") type = CHD_CODEC_CD_ZLIB;
    else if (token == "cdfl") type = CHD_CODEC_CD_FLAC;
    else if (token == "cdzs") type = CHD_CODEC_CD_ZSTD;
    else if (token == "none" || token.empty()) type = CHD_CODEC_NONE;
    else return;  // unknown token: keep the safe default rather than guess

    parsed[count++] = type;
    if (comma == std::string::npos) break;
    start = comma + 1;
  }
  if (count == 0) return;
  for (int slot = 0; slot < 4; slot++) out[slot] = (slot < count) ? parsed[slot] : CHD_CODEC_NONE;
}

// DVD counterpart of parse_cd_codecs using the general (non-CD) codec tokens.
// The default matches chdman's createdvd, which reuses the hard-disk set
// "lzma,zlib,huff,flac". Any unrecognized token (e.g. a CD token like "cdlz"
// passed through from the shared options) leaves that default in place.
void parse_dvd_codecs(const char *codecs, chd_codec_type out[4]) {
  out[0] = CHD_CODEC_LZMA;
  out[1] = CHD_CODEC_ZLIB;
  out[2] = CHD_CODEC_HUFFMAN;
  out[3] = CHD_CODEC_FLAC;
  if (!codecs || !*codecs) return;

  chd_codec_type parsed[4] = {CHD_CODEC_NONE, CHD_CODEC_NONE, CHD_CODEC_NONE, CHD_CODEC_NONE};
  int count = 0;
  const std::string list(codecs);
  size_t start = 0;
  while (count < 4 && start <= list.size()) {
    const size_t comma = list.find(',', start);
    std::string token = list.substr(start, comma == std::string::npos ? std::string::npos : comma - start);
    const size_t first = token.find_first_not_of(" \t");
    const size_t last = token.find_last_not_of(" \t");
    token = (first == std::string::npos) ? std::string() : token.substr(first, last - first + 1);

    chd_codec_type type;
    if (token == "lzma") type = CHD_CODEC_LZMA;
    else if (token == "zlib") type = CHD_CODEC_ZLIB;
    else if (token == "huff") type = CHD_CODEC_HUFFMAN;
    else if (token == "flac") type = CHD_CODEC_FLAC;
    else if (token == "zstd") type = CHD_CODEC_ZSTD;
    else if (token == "none" || token.empty()) type = CHD_CODEC_NONE;
    else return;  // unknown token (incl. CD tokens): keep the safe default

    parsed[count++] = type;
    if (comma == std::string::npos) break;
    start = comma + 1;
  }
  if (count == 0) return;
  for (int slot = 0; slot < 4; slot++) out[slot] = (slot < count) ? parsed[slot] : CHD_CODEC_NONE;
}

// Honors chdman's -np by routing through the OSDPROCESSORS env var that the osd
// work queue reads when sizing its thread pool (osd_getenv -> std::getenv). Must
// run before any osd_work_queue_alloc, i.e. before constructing the compressor.
void apply_num_processors(int num_processors) {
  if (num_processors <= 0) return;
  char buf[64];
  std::snprintf(buf, sizeof(buf), "OSDPROCESSORS=%d", num_processors);
#if defined(_WIN32)
  _putenv(buf);
#else
  setenv("OSDPROCESSORS", std::to_string(num_processors).c_str(), 1);
#endif
}

int run_compression(chd_file_compressor &chd, volatile int *progress_permille,
                    volatile int *cancel_flag) {
  chd.compress_begin();
  double complete = 0.0, ratio = 0.0;
  std::error_condition err;
  while ((err = chd.compress_continue(complete, ratio)) == chd_file::error::WALKING_PARENT ||
         err == chd_file::error::COMPRESSING) {
    if (cancel_flag && *cancel_flag) return CHDMAN_FFI_ERR_CANCELLED;
    if (progress_permille) *progress_permille = static_cast<int>(complete * 1000.0 + 0.5);
  }
  if (!err && progress_permille) *progress_permille = 1000;
  return err ? CHDMAN_FFI_ERR_CODEC : CHDMAN_FFI_OK;
}

const char *cue_mode_string(const cdrom_file::track_info &info, char *buf, size_t buflen) {
  switch (info.trktype) {
    case cdrom_file::CD_TRACK_MODE1:
    case cdrom_file::CD_TRACK_MODE1_RAW:
      std::snprintf(buf, buflen, "MODE1/%04d", info.datasize);
      return buf;
    case cdrom_file::CD_TRACK_MODE2:
    case cdrom_file::CD_TRACK_MODE2_FORM1:
    case cdrom_file::CD_TRACK_MODE2_FORM2:
    case cdrom_file::CD_TRACK_MODE2_FORM_MIX:
    case cdrom_file::CD_TRACK_MODE2_RAW:
      std::snprintf(buf, buflen, "MODE2/%04d", info.datasize);
      return buf;
    case cdrom_file::CD_TRACK_AUDIO:
    default:
      std::snprintf(buf, buflen, "AUDIO");
      return buf;
  }
}

}  // namespace

FFI_PLUGIN_EXPORT int chdman_create_cd_ex(const char *input_path, const char *output_chd_path,
                                          const chdman_options *options,
                                          volatile int *progress_permille,
                                          volatile int *cancel_flag) {
  if (!input_path || !output_chd_path) return CHDMAN_FFI_ERR_INVALID_INPUT;
  if (!file_exists(input_path)) return CHDMAN_FFI_ERR_OPEN_INPUT;
  const int force = options ? options->force : 0;
  if (!force && file_exists(output_chd_path)) return CHDMAN_FFI_ERR_OUTPUT_EXISTS;
  if (force && file_exists(output_chd_path)) std::remove(output_chd_path);

  if (progress_permille) *progress_permille = 0;

  // Must precede compressor construction so the work queue picks up the cap.
  apply_num_processors(options ? options->num_processors : 0);

  try {
    cdrom_file::track_input_info track_info;
    cdrom_file::toc toc = {0};
    std::error_condition err = cdrom_file::parse_toc(input_path, toc, track_info);
    if (err) return CHDMAN_FFI_ERR_INVALID_INPUT;

    uint32_t totalsectors = 0;
    for (int tracknum = 0; tracknum < toc.numtrks; tracknum++) {
      cdrom_file::track_info &trackinfo = toc.tracks[tracknum];
      int padded = (trackinfo.frames + cdrom_file::TRACK_PADDING - 1) / cdrom_file::TRACK_PADDING;
      trackinfo.extraframes = padded * cdrom_file::TRACK_PADDING - trackinfo.frames;
      totalsectors += trackinfo.frames + trackinfo.extraframes;
    }

    chd_codec_type compression[4];
    parse_cd_codecs(options ? options->codecs : nullptr, compression);

    const int requested_hunk = options ? options->hunk_bytes : 0;
    const uint32_t hunk_size = (requested_hunk > 0)
                                   ? static_cast<uint32_t>(requested_hunk)
                                   : cdrom_file::FRAMES_PER_HUNK * cdrom_file::FRAME_SIZE;

    auto chd = std::make_unique<chd_cd_compressor>(toc, track_info);
    err = chd->create(output_chd_path, uint64_t(totalsectors) * cdrom_file::FRAME_SIZE, hunk_size,
                      cdrom_file::FRAME_SIZE, compression);
    if (err) return CHDMAN_FFI_ERR_OPEN_OUTPUT;

    err = cdrom_file::write_metadata(chd.get(), toc);
    if (err) return CHDMAN_FFI_ERR_CODEC;

    const int rc = run_compression(*chd, progress_permille, cancel_flag);
    // Destroy the compressor first so its worker threads stop and the output
    // file handle is released before we (possibly) delete a partial .chd.
    chd.reset();
    if (rc != CHDMAN_FFI_OK) std::remove(output_chd_path);
    return rc;
  } catch (const std::error_condition &) {
    std::remove(output_chd_path);
    return CHDMAN_FFI_ERR_INTERNAL;
  } catch (...) {
    std::remove(output_chd_path);
    return CHDMAN_FFI_ERR_INTERNAL;
  }
}

FFI_PLUGIN_EXPORT int chdman_create_cd(const char *input_path, const char *output_chd_path,
                                       int force) {
  const chdman_options options = {nullptr, 0, 0, force};
  return chdman_create_cd_ex(input_path, output_chd_path, &options, nullptr, nullptr);
}

FFI_PLUGIN_EXPORT int chdman_create_dvd_ex(const char *input_path, const char *output_chd_path,
                                           const chdman_options *options,
                                           volatile int *progress_permille,
                                           volatile int *cancel_flag) {
  if (!input_path || !output_chd_path) return CHDMAN_FFI_ERR_INVALID_INPUT;
  if (!file_exists(input_path)) return CHDMAN_FFI_ERR_OPEN_INPUT;
  const int force = options ? options->force : 0;
  if (!force && file_exists(output_chd_path)) return CHDMAN_FFI_ERR_OUTPUT_EXISTS;
  if (force && file_exists(output_chd_path)) std::remove(output_chd_path);

  if (progress_permille) *progress_permille = 0;

  // Must precede compressor construction so the work queue picks up the cap.
  apply_num_processors(options ? options->num_processors : 0);

  // A DVD CHD is a flat stream of 2048-byte logical sectors (chdman createdvd):
  // unit size is fixed at 2048 and the hunk default is two sectors.
  constexpr uint32_t kDvdSectorSize = 2048;

  // input_file is declared before the compressor so it outlives it: the
  // compressor's worker threads read through it until the compressor is
  // destroyed.
  util::core_file::ptr input_file;
  try {
    std::error_condition err = util::core_file::open(input_path, OPEN_FLAG_READ, input_file);
    if (err) return CHDMAN_FFI_ERR_OPEN_INPUT;

    uint64_t input_size = 0;
    if (input_file->length(input_size)) return CHDMAN_FFI_ERR_OPEN_INPUT;
    if (input_size == 0 || (input_size % kDvdSectorSize) != 0)
      return CHDMAN_FFI_ERR_INVALID_INPUT;

    chd_codec_type compression[4];
    parse_dvd_codecs(options ? options->codecs : nullptr, compression);

    const int requested_hunk = options ? options->hunk_bytes : 0;
    uint32_t hunk_size = (requested_hunk > 0) ? static_cast<uint32_t>(requested_hunk)
                                              : 2 * kDvdSectorSize;
    // The hunk must be a whole number of sectors; fall back to the default if not.
    if ((hunk_size % kDvdSectorSize) != 0) hunk_size = 2 * kDvdSectorSize;

    auto chd = std::make_unique<chd_rawfile_compressor>(*input_file, 0, input_size);
    err = chd->create(output_chd_path, input_size, hunk_size, kDvdSectorSize, compression);
    if (err) return CHDMAN_FFI_ERR_OPEN_OUTPUT;

    // The "DVD " tag (empty payload) is what marks the CHD as a DVD; emulators
    // key on its presence via chd_file::check_is_dvd().
    err = chd->write_metadata(DVD_METADATA_TAG, 0, std::string());
    if (err) return CHDMAN_FFI_ERR_CODEC;

    const int rc = run_compression(*chd, progress_permille, cancel_flag);
    // Destroy the compressor first so its worker threads stop (and stop touching
    // input_file) and the output handle is released before any partial cleanup.
    chd.reset();
    if (rc != CHDMAN_FFI_OK) std::remove(output_chd_path);
    return rc;
  } catch (const std::error_condition &) {
    std::remove(output_chd_path);
    return CHDMAN_FFI_ERR_INTERNAL;
  } catch (...) {
    std::remove(output_chd_path);
    return CHDMAN_FFI_ERR_INTERNAL;
  }
}

FFI_PLUGIN_EXPORT int chdman_create_dvd(const char *input_path, const char *output_chd_path,
                                        int force) {
  const chdman_options options = {nullptr, 0, 0, force};
  return chdman_create_dvd_ex(input_path, output_chd_path, &options, nullptr, nullptr);
}

FFI_PLUGIN_EXPORT int chdman_extract_cd_ex(const char *input_chd_path, const char *output_cue_path,
                                           const char *output_bin_path,
                                           const chdman_options *options,
                                           volatile int *progress_permille,
                                           volatile int *cancel_flag) {
  if (!input_chd_path || !output_cue_path || !output_bin_path)
    return CHDMAN_FFI_ERR_INVALID_INPUT;
  if (!file_exists(input_chd_path)) return CHDMAN_FFI_ERR_OPEN_INPUT;
  const int force = options ? options->force : 0;
  if (!force && (file_exists(output_cue_path) || file_exists(output_bin_path)))
    return CHDMAN_FFI_ERR_OUTPUT_EXISTS;

  if (progress_permille) *progress_permille = 0;

  std::unique_ptr<cdrom_file> cdrom;
  try {
    chd_file input_chd;
    std::error_condition err = input_chd.open(input_chd_path, false);
    if (err) return CHDMAN_FFI_ERR_OPEN_INPUT;

    cdrom = std::make_unique<cdrom_file>(&input_chd);
    const cdrom_file::toc &toc = cdrom->get_toc();

    util::core_file::ptr cue_file;
    err = util::core_file::open(output_cue_path,
                                OPEN_FLAG_WRITE | OPEN_FLAG_CREATE | OPEN_FLAG_NO_BOM, cue_file);
    if (err) return CHDMAN_FFI_ERR_OPEN_OUTPUT;

    util::core_file::ptr bin_file;
    err = util::core_file::open(output_bin_path, OPEN_FLAG_WRITE | OPEN_FLAG_CREATE, bin_file);
    if (err) return CHDMAN_FFI_ERR_OPEN_OUTPUT;

    // Bare bin filename for the cue's FILE line.
    std::string bin_name(output_bin_path);
    size_t slash = bin_name.find_last_of("/\\");
    if (slash != std::string::npos) bin_name.erase(0, slash + 1);
    cue_file->printf("FILE \"%s\" BINARY\n", bin_name.c_str());

    // Total output frames, for progress reporting.
    uint64_t total_frames = 0;
    for (int tracknum = 0; tracknum < toc.numtrks; tracknum++) {
      const cdrom_file::track_info &trackinfo = toc.tracks[tracknum];
      total_frames += trackinfo.frames - trackinfo.padframes + trackinfo.splitframes;
    }
    if (total_frames == 0) total_frames = 1;
    uint64_t frames_done = 0;

    std::vector<uint8_t> buffer;
    uint32_t frameoffs = 0;  // running disc frame offset for INDEX entries
    bool cancelled = false;
    for (int tracknum = 0; tracknum < toc.numtrks && !cancelled; tracknum++) {
      const cdrom_file::track_info &trackinfo = toc.tracks[tracknum];

      char modebuf[24];
      cue_file->printf("  TRACK %02d %s\n", tracknum + 1,
                       cue_mode_string(trackinfo, modebuf, sizeof(modebuf)));
      if (trackinfo.pregap > 0 && trackinfo.pgdatasize == 0) {
        cue_file->printf("    PREGAP %s\n", msf_string_from_frames(trackinfo.pregap).c_str());
        cue_file->printf("    INDEX 01 %s\n", msf_string_from_frames(frameoffs).c_str());
      } else if (trackinfo.pregap > 0 && trackinfo.pgdatasize > 0) {
        cue_file->printf("    INDEX 00 %s\n", msf_string_from_frames(frameoffs).c_str());
        cue_file->printf("    INDEX 01 %s\n",
                         msf_string_from_frames(frameoffs + trackinfo.pregap).c_str());
      } else {
        cue_file->printf("    INDEX 01 %s\n", msf_string_from_frames(frameoffs).c_str());
      }
      if (trackinfo.postgap > 0)
        cue_file->printf("    POSTGAP %s\n", msf_string_from_frames(trackinfo.postgap).c_str());

      const uint32_t output_frame_size = trackinfo.datasize;
      buffer.resize(output_frame_size);
      const uint32_t actualframes = trackinfo.frames - trackinfo.padframes + trackinfo.splitframes;
      for (uint32_t frame = 0; frame < actualframes; frame++) {
        if (cancel_flag && *cancel_flag) {
          cancelled = true;
          break;
        }
        int trk, frameofs;
        if (tracknum > 0 && frame < trackinfo.splitframes) {
          trk = tracknum - 1;
          frameofs = toc.tracks[trk].frames - trackinfo.splitframes + frame;
        } else {
          trk = tracknum;
          frameofs = frame - trackinfo.splitframes;
        }

        cdrom->read_data(cdrom->get_track_start_phys(trk) + frameofs, &buffer[0],
                         toc.tracks[trk].trktype, true);

        if (toc.tracks[trk].trktype == cdrom_file::CD_TRACK_AUDIO)
          for (int swapindex = 0; swapindex < toc.tracks[trk].datasize; swapindex += 2) {
            uint8_t t = buffer[swapindex];
            buffer[swapindex] = buffer[swapindex + 1];
            buffer[swapindex + 1] = t;
          }

        auto const [writerr, written] = util::write(*bin_file, &buffer[0], output_frame_size);
        if (writerr || written != output_frame_size) return CHDMAN_FFI_ERR_OPEN_OUTPUT;

        if (progress_permille && (++frames_done & 0xFFF) == 0)
          *progress_permille = static_cast<int>(frames_done * 1000 / total_frames);
      }
      frameoffs += trackinfo.frames;
    }

    if (cancelled) {
      // Release the output handles before deleting the partial .cue/.bin.
      cue_file.reset();
      bin_file.reset();
      std::remove(output_cue_path);
      std::remove(output_bin_path);
      return CHDMAN_FFI_ERR_CANCELLED;
    }

    if (progress_permille) *progress_permille = 1000;
    return CHDMAN_FFI_OK;
  } catch (const std::error_condition &) {
    return CHDMAN_FFI_ERR_INTERNAL;
  } catch (...) {
    return CHDMAN_FFI_ERR_INTERNAL;
  }
}

FFI_PLUGIN_EXPORT int chdman_extract_cd(const char *input_chd_path, const char *output_cue_path,
                                        const char *output_bin_path, int force) {
  const chdman_options options = {nullptr, 0, 0, force};
  return chdman_extract_cd_ex(input_chd_path, output_cue_path, output_bin_path, &options, nullptr,
                              nullptr);
}

#else /* !CHDMAN_AVAILABLE */

FFI_PLUGIN_EXPORT int chdman_create_cd_ex(const char *input_path, const char *output_chd_path,
                                          const chdman_options *options,
                                          volatile int *progress_permille,
                                          volatile int *cancel_flag) {
  (void)input_path;
  (void)output_chd_path;
  (void)options;
  (void)progress_permille;
  (void)cancel_flag;
  return CHDMAN_FFI_ERR_LIB_UNAVAILABLE;
}

FFI_PLUGIN_EXPORT int chdman_extract_cd_ex(const char *input_chd_path, const char *output_cue_path,
                                           const char *output_bin_path,
                                           const chdman_options *options,
                                           volatile int *progress_permille,
                                           volatile int *cancel_flag) {
  (void)input_chd_path;
  (void)output_cue_path;
  (void)output_bin_path;
  (void)options;
  (void)progress_permille;
  (void)cancel_flag;
  return CHDMAN_FFI_ERR_LIB_UNAVAILABLE;
}

FFI_PLUGIN_EXPORT int chdman_create_cd(const char *input_path,
                                       const char *output_chd_path,
                                       int force) {
  (void)input_path;
  (void)output_chd_path;
  (void)force;
  return CHDMAN_FFI_ERR_LIB_UNAVAILABLE;
}

FFI_PLUGIN_EXPORT int chdman_create_dvd_ex(const char *input_path, const char *output_chd_path,
                                           const chdman_options *options,
                                           volatile int *progress_permille,
                                           volatile int *cancel_flag) {
  (void)input_path;
  (void)output_chd_path;
  (void)options;
  (void)progress_permille;
  (void)cancel_flag;
  return CHDMAN_FFI_ERR_LIB_UNAVAILABLE;
}

FFI_PLUGIN_EXPORT int chdman_create_dvd(const char *input_path,
                                        const char *output_chd_path,
                                        int force) {
  (void)input_path;
  (void)output_chd_path;
  (void)force;
  return CHDMAN_FFI_ERR_LIB_UNAVAILABLE;
}

FFI_PLUGIN_EXPORT int chdman_extract_cd(const char *input_chd_path,
                                        const char *output_cue_path,
                                        const char *output_bin_path,
                                        int force) {
  (void)input_chd_path;
  (void)output_cue_path;
  (void)output_bin_path;
  (void)force;
  return CHDMAN_FFI_ERR_LIB_UNAVAILABLE;
}

#endif /* CHDMAN_AVAILABLE */
