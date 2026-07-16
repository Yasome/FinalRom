# The Flutter tooling requires that developers have CMake 3.10 or later
# installed. You should not increase this version, as doing so will cause
# the plugin to fail to compile for some customers of the plugin.
cmake_minimum_required(VERSION 3.10)

project(chdman_ffi_library VERSION 0.0.1 LANGUAGES C CXX)

if (ANDROID)
  # Force Android 15's 16 KB page size requirement globally for any bundled libraries (e.g. libz.so)
  set(CMAKE_SHARED_LINKER_FLAGS "${CMAKE_SHARED_LINKER_FLAGS} -Wl,-z,max-page-size=16384")
  set(CMAKE_MODULE_LINKER_FLAGS "${CMAKE_MODULE_LINKER_FLAGS} -Wl,-z,max-page-size=16384")
endif()

# MAME's util/osd headers (coretmpl.h, strformat.h, ...) use C++20 concepts.
set(CMAKE_CXX_STANDARD 20)
set(CMAKE_CXX_STANDARD_REQUIRED ON)
set(CMAKE_C_STANDARD 11)

add_library(chdman_ffi SHARED
  "chdman_ffi.cpp"
)

set_target_properties(chdman_ffi PROPERTIES
  PUBLIC_HEADER chdman_ffi.h
  OUTPUT_NAME "chdman_ffi"
)

target_compile_definitions(chdman_ffi PUBLIC DART_SHARED_LIB)

# The vendored MAME chd library is optional. When the chd sources are present
# (chd/util/chd.cpp), compile the real implementation; otherwise a stub is built
# so the host application still links and runs (CD operations then return
# CHDMAN_FFI_ERR_LIB_UNAVAILABLE at runtime). See chd/PLACEHOLDER.md.
set(CHD_DIR "${CMAKE_CURRENT_SOURCE_DIR}/chd")
if (EXISTS "${CHD_DIR}/util/chd.cpp" AND EXISTS "${CHD_DIR}/util/chd.h")
  message(STATUS "chdman_ffi: building with vendored MAME chd sources")
  target_compile_definitions(chdman_ffi PRIVATE CHDMAN_AVAILABLE=1)

  # All vendored codec libs below are linked statically into chdman_ffi, which
  # is a SHARED library; they must be position-independent on platforms (Linux)
  # where static libs aren't PIC by default, or linking produces text relocations.
  set(CMAKE_POSITION_INDEPENDENT_CODE ON)

  # Quiet the expected third-party/MAME warning spam so a real diagnostic can't
  # hide in it. These are benign narrowing (C4244/C4267/C4334), signed/unsigned
  # (C4018) and CRT-deprecation (C4996) warnings inherent to MAME, FLAC and
  # zstd. add_compile_options propagates to the codec subprojects added below;
  # target_compile_options covers the chdman_ffi target created earlier.
  # C4250 = "inherits member via dominance" from MAME's ioprocs virtual
  # inheritance; the rest are narrowing/sign/CRT-deprecation noise.
  set(CHDMAN_MSVC_QUIET /wd4244 /wd4267 /wd4334 /wd4018 /wd4996 /wd4250 /wd4146)
  if (MSVC)
    add_compile_options(${CHDMAN_MSVC_QUIET})
    add_compile_definitions(_CRT_SECURE_NO_WARNINGS)
    target_compile_options(chdman_ffi PRIVATE ${CHDMAN_MSVC_QUIET})
    target_compile_definitions(chdman_ffi PRIVATE _CRT_SECURE_NO_WARNINGS)
  endif()

  # ---- Build the CHD codec code release-grade, even in Debug builds ----
  # The LZMA/FLAC/zlib/zstd codecs and the MAME chd sources are performance
  # critical. Measured on a PSX disc create (Silent Hill, gcc): Debug -O0 = 145s,
  # Debug -O2 (asserts on) = 144s, Debug -O2 -DNDEBUG = 11s. The dominant cost is
  # asserts in the LZMA/MAME hot loops — defining NDEBUG is what makes it ~13x
  # faster; the optimization level barely matters but -O2 is kept as good
  # practice. These are stable vendored sources we never step through in a
  # debugger, so we build them release-grade regardless of the host build type.
  # We shadow the Debug flag variables as normal (non-cache) variables so the
  # change is scoped to this plugin's subtree and does not touch the host app's
  # own Debug flags. MSVC's /RTC1 is incompatible with /O2 and must be stripped.
  if (MSVC)
    foreach(_chd_flagvar CMAKE_C_FLAGS_DEBUG CMAKE_CXX_FLAGS_DEBUG)
      string(REGEX REPLACE "/RTC[1csu]+" "" ${_chd_flagvar} "${${_chd_flagvar}}")
      string(REPLACE "/Od" "" ${_chd_flagvar} "${${_chd_flagvar}}")
      string(REPLACE "/Ob0" "" ${_chd_flagvar} "${${_chd_flagvar}}")
      set(${_chd_flagvar} "${${_chd_flagvar}} /O2 /Ob2 /DNDEBUG")
    endforeach()
  else()
    foreach(_chd_flagvar CMAKE_C_FLAGS_DEBUG CMAKE_CXX_FLAGS_DEBUG)
      set(${_chd_flagvar} "${${_chd_flagvar}} -O2 -DNDEBUG")
    endforeach()
  endif()

  # ---- zlib (static, CDZL codec) ----
  # zlib bakes its install destinations into ABSOLUTE paths at configure time
  # (INSTALL_LIB_DIR = ${CMAKE_INSTALL_PREFIX}/lib), and at that point the
  # prefix is still CMake's unwritable default (C:/Program Files/<app>) because
  # Flutter aggregates plugins before redirecting the prefix to the app bundle
  # dir. The aggregated desktop INSTALL target would then try to write zlib into
  # Program Files and fail the whole build. We bundle this plugin via the
  # chdman_ffi_bundled_libraries variable, not via zlib's install rules, so skip
  # them. SKIP_INSTALL_ALL is honoured only by the zlib subdirectory below.
  #
  # zlib's example/minigzip targets default ON and compile from test/*.c, which
  # are git-ignored (**/test/**) and thus absent on a fresh CI checkout. We only
  # need the static lib, so force the examples off before configuring zlib.
  set(ZLIB_BUILD_EXAMPLES OFF CACHE BOOL "" FORCE)
  set(SKIP_INSTALL_ALL ON)
  add_subdirectory("${CHD_DIR}/3rdparty/zlib" "${CMAKE_CURRENT_BINARY_DIR}/zlib")
  unset(SKIP_INSTALL_ALL)

  # ---- FLAC (static, no ogg/programs/tests; CDFL codec) ----
  set(BUILD_SHARED_LIBS OFF CACHE BOOL "" FORCE)
  set(BUILD_PROGRAMS OFF CACHE BOOL "" FORCE)
  set(BUILD_EXAMPLES OFF CACHE BOOL "" FORCE)
  set(BUILD_TESTING OFF CACHE BOOL "" FORCE)
  set(BUILD_DOCS OFF CACHE BOOL "" FORCE)
  set(INSTALL_MANPAGES OFF CACHE BOOL "" FORCE)
  set(WITH_OGG OFF CACHE BOOL "" FORCE)
  set(BUILD_CXXLIBS OFF CACHE BOOL "" FORCE)
  # Skip FLAC's CMake package-config export/install block: its
  # export(EXPORT targets ...) fails to configure under the Android NDK CMake,
  # and we link FLAC by target name (never consume its package config).
  set(INSTALL_CMAKE_CONFIG_MODULE OFF CACHE BOOL "" FORCE)
  set(INSTALL_PKGCONFIG_MODULES OFF CACHE BOOL "" FORCE)
  if(ANDROID AND CMAKE_SYSTEM_VERSION LESS 24)
    add_compile_definitions(fseeko=fseek ftello=ftell)
  endif()
  add_subdirectory("${CHD_DIR}/3rdparty/flac" "${CMAKE_CURRENT_BINARY_DIR}/flac" EXCLUDE_FROM_ALL)

  # ---- LZMA (single-threaded subset, CDLZ codec) ----
  add_library(chdman_lzma STATIC
    "${CHD_DIR}/3rdparty/lzma/C/LzmaDec.c"
    "${CHD_DIR}/3rdparty/lzma/C/LzmaEnc.c"
    "${CHD_DIR}/3rdparty/lzma/C/LzFind.c"
    "${CHD_DIR}/3rdparty/lzma/C/Alloc.c"
    "${CHD_DIR}/3rdparty/lzma/C/CpuArch.c"
  )
  target_compile_definitions(chdman_lzma PUBLIC Z7_ST _7ZIP_ST)
  target_include_directories(chdman_lzma PUBLIC "${CHD_DIR}/3rdparty/lzma/C")

  # ---- utf8proc (static; required by util/unicode.cpp) ----
  add_library(chdman_utf8proc STATIC "${CHD_DIR}/3rdparty/utf8proc/utf8proc.c")
  target_compile_definitions(chdman_utf8proc PUBLIC UTF8PROC_STATIC)
  target_include_directories(chdman_utf8proc PUBLIC "${CHD_DIR}/3rdparty/utf8proc")

  # ---- zstd (CDZS codec) ----
  # Built as a self-contained static lib with a unique target name. We do NOT
  # reuse the sibling zstd_ffi build: on desktop Flutter aggregates every plugin
  # into a single CMake pass, so sharing zstd's CMake would create a duplicate
  # "libzstd_static" target; on Android each plugin builds in isolation so the
  # sibling target wouldn't be visible at all. A private copy avoids both.
  set(ZSTD_LIB "${CHD_DIR}/3rdparty/zstd/lib")
  file(GLOB CHDMAN_ZSTD_SOURCES
    "${ZSTD_LIB}/common/*.c"
    "${ZSTD_LIB}/compress/*.c"
    "${ZSTD_LIB}/decompress/*.c")
  add_library(chdman_zstd STATIC ${CHDMAN_ZSTD_SOURCES})
  # ZSTD_DISABLE_ASM: the x86-64 .S fast path is not vendored, use the C
  # fallback (also keeps MSVC, which can't assemble the .S, happy).
  target_compile_definitions(chdman_zstd PUBLIC ZSTD_DISABLE_ASM=1 ZSTD_LEGACY_SUPPORT=0)
  target_include_directories(chdman_zstd PUBLIC "${ZSTD_LIB}" "${ZSTD_LIB}/common")
  set(CHDMAN_ZSTD_TARGET chdman_zstd)
  set(CHDMAN_ZSTD_INCLUDE "${ZSTD_LIB}")

  # ---- MAME chd subset + osd + stdio file shim ----
  target_sources(chdman_ffi PRIVATE
    "${CHD_DIR}/osd_file_stdio.cpp"
    "${CHD_DIR}/util/chd.cpp"
    "${CHD_DIR}/util/chdcodec.cpp"
    "${CHD_DIR}/util/cdrom.cpp"
    "${CHD_DIR}/util/hashing.cpp"
    "${CHD_DIR}/util/flac.cpp"
    "${CHD_DIR}/util/huffman.cpp"
    "${CHD_DIR}/util/corefile.cpp"
    "${CHD_DIR}/util/corestr.cpp"
    "${CHD_DIR}/util/path.cpp"
    "${CHD_DIR}/util/vecstream.cpp"
    "${CHD_DIR}/util/coreutil.cpp"
    "${CHD_DIR}/util/ioprocs.cpp"
    "${CHD_DIR}/util/ioprocsfilter.cpp"
    "${CHD_DIR}/util/strformat.cpp"
    "${CHD_DIR}/util/md5.cpp"
    "${CHD_DIR}/util/unicode.cpp"
    "${CHD_DIR}/osd/osdcore.cpp"
    "${CHD_DIR}/osd/osdsync.cpp"
    "${CHD_DIR}/osd/strconv.cpp"
  )

  target_include_directories(chdman_ffi PRIVATE
    "${CHD_DIR}/util"
    "${CHD_DIR}/osd"
    "${CHD_DIR}/3rdparty"
    "${CHD_DIR}/3rdparty/zlib"
    "${CMAKE_CURRENT_BINARY_DIR}/zlib"          # generated zconf.h
    "${CHD_DIR}/3rdparty/flac/include"
    "${CHD_DIR}/3rdparty/utf8proc"
    "${CHDMAN_ZSTD_INCLUDE}"
  )

  target_compile_definitions(chdman_ffi PRIVATE
    Z7_ST _7ZIP_ST FLAC__NO_DLL CRLF=3 UTF8PROC_STATIC)

  if (WIN32)
    # MAME's osd/strconv.cpp includes <windows.h>, whose min/max macros break
    # std::min/std::max (MSVC error C2589). Suppress them and trim the header.
    target_compile_definitions(chdman_ffi PRIVATE NOMINMAX WIN32_LEAN_AND_MEAN)
  endif()

  target_link_libraries(chdman_ffi PRIVATE
    zlibstatic
    FLAC
    chdman_lzma
    chdman_utf8proc
    ${CHDMAN_ZSTD_TARGET})
else()
  message(FATAL_ERROR "chdman_ffi: MAME chd sources missing from src/chd — "
                      "refusing to build a stub. See src/chd/PLACEHOLDER.md to "
                      "enable CD CHD support.")
endif()

if (ANDROID)
  # Support Android 15's 16 KB page size requirement.
  target_link_options(chdman_ffi PRIVATE "-Wl,-z,max-page-size=16384")
endif()
