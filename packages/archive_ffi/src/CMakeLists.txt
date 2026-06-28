# The Flutter tooling requires that developers have CMake 3.10 or later
# installed. You should not increase this version, as doing so will cause
# the plugin to fail to compile for some customers of the plugin.
cmake_minimum_required(VERSION 3.10)

project(archive_ffi_library VERSION 0.0.1 LANGUAGES C)

if (ANDROID)
  # Force Android 15's 16 KB page size requirement globally for bundled libs.
  set(CMAKE_SHARED_LINKER_FLAGS "${CMAKE_SHARED_LINKER_FLAGS} -Wl,-z,max-page-size=16384")
  set(CMAKE_MODULE_LINKER_FLAGS "${CMAKE_MODULE_LINKER_FLAGS} -Wl,-z,max-page-size=16384")
endif()

add_library(archive_ffi SHARED
  "archive_ffi.c"
)

set_target_properties(archive_ffi PROPERTIES
  PUBLIC_HEADER archive_ffi.h
  OUTPUT_NAME "archive_ffi"
  C_STANDARD 11
)

target_compile_definitions(archive_ffi PUBLIC DART_SHARED_LIB)

# The vendored libarchive sources are optional. When present, compile the real
# backend (archive_ffi.c keys off ARCHIVE_FFI_HAVE_LIBARCHIVE); otherwise the
# stub is built so the host app still links and runs (operations return
# ARCHIVE_FFI_ERR_LIB_UNAVAILABLE). See libarchive/PLACEHOLDER.md.
set(LIBARCHIVE_DIR "${CMAKE_CURRENT_SOURCE_DIR}/libarchive")
if (EXISTS "${LIBARCHIVE_DIR}/libarchive/archive.h")
  message(STATUS "archive_ffi: building with vendored libarchive")
  target_compile_definitions(archive_ffi PRIVATE ARCHIVE_FFI_HAVE_LIBARCHIVE=1)

  # The codec static libs below are linked into a SHARED library; they must be
  # position-independent on platforms (Linux) where static libs aren't PIC by
  # default, or linking produces text relocations.
  set(CMAKE_POSITION_INDEPENDENT_CODE ON)

  # ---- Build the vendored codecs release-grade, even in Debug builds ----
  # The LZMA/zstd/zlib codecs are performance critical and their asserts dominate
  # debug runtime (measured ~13x on chdman). Build them with -O2 -DNDEBUG
  # regardless of the host build type; MSVC's /RTC1 is incompatible with /O2.
  if (MSVC)
    foreach(_flagvar CMAKE_C_FLAGS_DEBUG CMAKE_CXX_FLAGS_DEBUG)
      string(REGEX REPLACE "/RTC[1csu]+" "" ${_flagvar} "${${_flagvar}}")
      string(REPLACE "/Od" "" ${_flagvar} "${${_flagvar}}")
      string(REPLACE "/Ob0" "" ${_flagvar} "${${_flagvar}}")
      set(${_flagvar} "${${_flagvar}} /O2 /Ob2 /DNDEBUG")
    endforeach()
    add_compile_definitions(_CRT_SECURE_NO_WARNINGS)
    # Quiet expected third-party narrowing/sign/CRT-deprecation noise.
    add_compile_options(/wd4244 /wd4267 /wd4146 /wd4996)
  else()
    foreach(_flagvar CMAKE_C_FLAGS_DEBUG CMAKE_CXX_FLAGS_DEBUG)
      set(${_flagvar} "${${_flagvar}} -O2 -DNDEBUG")
    endforeach()
  endif()

  # ---- zlib (zip + gzip deflate) as a uniquely-named static lib ----
  # We do NOT add_subdirectory(zlib): the upstream CMake declares the fixed
  # target `zlibstatic`, which collides with chdman_ffi's zlib during Flutter's
  # single-pass desktop plugin aggregation. A private glob-built lib with a
  # unique name avoids that (the same reasoning chdman uses for its codecs).
  set(ARCHIVE_ZLIB_DIR "${CMAKE_CURRENT_SOURCE_DIR}/zlib")
  file(GLOB ARCHIVE_ZLIB_SOURCES "${ARCHIVE_ZLIB_DIR}/*.c")
  add_library(archive_z STATIC ${ARCHIVE_ZLIB_SOURCES})
  target_include_directories(archive_z PUBLIC "${ARCHIVE_ZLIB_DIR}")

  # ---- zstd as a uniquely-named static lib (mirrors chdman_zstd) ----
  set(ARCHIVE_ZSTD_LIB "${CMAKE_CURRENT_SOURCE_DIR}/zstd/lib")
  file(GLOB ARCHIVE_ZSTD_SOURCES
    "${ARCHIVE_ZSTD_LIB}/common/*.c"
    "${ARCHIVE_ZSTD_LIB}/compress/*.c"
    "${ARCHIVE_ZSTD_LIB}/decompress/*.c")
  add_library(archive_zstd STATIC ${ARCHIVE_ZSTD_SOURCES})
  # ZSTD_DISABLE_ASM: the x86-64 .S fast path is not vendored; use the C fallback
  # (also keeps MSVC, which can't assemble the .S, happy).
  target_compile_definitions(archive_zstd PUBLIC ZSTD_DISABLE_ASM=1 ZSTD_LEGACY_SUPPORT=0)
  target_include_directories(archive_zstd PUBLIC "${ARCHIVE_ZSTD_LIB}" "${ARCHIVE_ZSTD_LIB}/common")

  # ---- liblzma (xz) for 7z LZMA/LZMA2 read + write ----
  # xz's CMake hard-codes the target name `liblzma`, which xdelta3_ffi also
  # builds via add_subdirectory(xz). On desktop all plugins share one CMake pass,
  # so guard against re-declaring the target; on Android each plugin is
  # configured in isolation and builds its own. Whichever plugin is configured
  # first defines `liblzma`; both link it thereafter.
  set(ARCHIVE_XZ_DIR "${CMAKE_CURRENT_SOURCE_DIR}/xz")
  if (NOT TARGET liblzma)
    set(BUILD_SHARED_LIBS OFF CACHE BOOL "" FORCE)
    set(BUILD_TESTING OFF CACHE BOOL "" FORCE)
    set(HAVE_GETOPT_LONG OFF CACHE INTERNAL "archive_ffi: never build the xz CLI tools")
    set(ENABLE_THREADS OFF CACHE STRING "archive_ffi: single-threaded liblzma" FORCE)
    set(CREATE_XZ_SYMLINKS OFF CACHE BOOL "" FORCE)
    set(CREATE_LZMA_SYMLINKS OFF CACHE BOOL "" FORCE)
    add_subdirectory("${ARCHIVE_XZ_DIR}" "${CMAKE_CURRENT_BINARY_DIR}/xz" EXCLUDE_FROM_ALL)
  endif()

  # ---- Point libarchive at our vendored codecs instead of system probes ----
  # libarchive's CMake runs find_package(ZLIB|LibLZMA|zstd). Pre-populate the
  # variables those Find modules read and create the namespaced imported targets
  # they would define, so libarchive links our private static libs. NOTE: the
  # exact var/target names are libarchive-version sensitive; if the vendored
  # libarchive still probes the system here, adjust this block during the build.
  set(ZLIB_FOUND TRUE)
  set(ZLIB_INCLUDE_DIR "${ARCHIVE_ZLIB_DIR}" CACHE PATH "" FORCE)
  set(ZLIB_INCLUDE_DIRS "${ARCHIVE_ZLIB_DIR}")
  set(ZLIB_LIBRARY archive_z)
  set(ZLIB_LIBRARIES archive_z)
  if (NOT TARGET ZLIB::ZLIB)
    add_library(ZLIB::ZLIB ALIAS archive_z)
  endif()

  set(LIBLZMA_FOUND TRUE)
  set(LIBLZMA_HAS_AUTO_DECODER TRUE)
  set(LIBLZMA_HAS_EASY_ENCODER TRUE)
  set(LIBLZMA_HAS_LZMA_PRESET TRUE)
  set(LIBLZMA_INCLUDE_DIR "${ARCHIVE_XZ_DIR}/src/liblzma/api" CACHE PATH "" FORCE)
  set(LIBLZMA_INCLUDE_DIRS "${ARCHIVE_XZ_DIR}/src/liblzma/api")
  set(LIBLZMA_LIBRARY liblzma)
  set(LIBLZMA_LIBRARIES liblzma)
  if (NOT TARGET LibLZMA::LibLZMA)
    add_library(LibLZMA::LibLZMA ALIAS liblzma)
  endif()

  set(ZSTD_FOUND TRUE)
  set(ZSTD_INCLUDE_DIR "${ARCHIVE_ZSTD_LIB}" CACHE PATH "" FORCE)
  set(ZSTD_INCLUDE_DIRS "${ARCHIVE_ZSTD_LIB}")
  set(ZSTD_LIBRARY archive_zstd)
  set(ZSTD_LIBRARIES archive_zstd)
  if (NOT TARGET zstd::libzstd)
    add_library(zstd::libzstd ALIAS archive_zstd)
  endif()

  # ---- libarchive itself: build the library only, with just our codecs ----
  set(ENABLE_ZLIB ON CACHE BOOL "" FORCE)
  set(ENABLE_ZSTD ON CACHE BOOL "" FORCE)
  set(ENABLE_LZMA ON CACHE BOOL "" FORCE)
  set(ENABLE_BZip2 OFF CACHE BOOL "" FORCE)
  set(ENABLE_LZ4 OFF CACHE BOOL "" FORCE)
  set(ENABLE_LZO OFF CACHE BOOL "" FORCE)
  set(ENABLE_LIBB2 OFF CACHE BOOL "" FORCE)
  set(ENABLE_OPENSSL OFF CACHE BOOL "" FORCE)
  set(ENABLE_LIBXML2 OFF CACHE BOOL "" FORCE)
  set(ENABLE_EXPAT OFF CACHE BOOL "" FORCE)
  set(ENABLE_ICONV OFF CACHE BOOL "" FORCE)
  set(ENABLE_XATTR OFF CACHE BOOL "" FORCE)
  set(ENABLE_ACL OFF CACHE BOOL "" FORCE)
  set(ENABLE_TAR OFF CACHE BOOL "" FORCE)
  set(ENABLE_CPIO OFF CACHE BOOL "" FORCE)
  set(ENABLE_CAT OFF CACHE BOOL "" FORCE)
  set(ENABLE_UNZIP OFF CACHE BOOL "" FORCE)
  set(ENABLE_TEST OFF CACHE BOOL "" FORCE)
  set(ENABLE_INSTALL OFF CACHE BOOL "" FORCE)
  set(ENABLE_COVERAGE OFF CACHE BOOL "" FORCE)
  set(BUILD_SHARED_LIBS OFF CACHE BOOL "" FORCE)
  add_subdirectory("${LIBARCHIVE_DIR}" "${CMAKE_CURRENT_BINARY_DIR}/libarchive" EXCLUDE_FROM_ALL)

  # LIBARCHIVE_STATIC: we link libarchive statically, so its public header must
  # not mark the API __declspec(dllimport) on Windows (otherwise the linker
  # looks for __imp_archive_* import stubs a static lib doesn't provide).
  target_compile_definitions(archive_ffi PRIVATE LIBARCHIVE_STATIC)
  target_include_directories(archive_ffi PRIVATE "${LIBARCHIVE_DIR}/libarchive")
  target_link_libraries(archive_ffi PRIVATE archive_static)

  if (MSVC)
    target_compile_definitions(archive_ffi PRIVATE _CRT_SECURE_NO_WARNINGS)
  endif()
else()
  message(WARNING "archive_ffi: libarchive sources not found in src/libarchive — "
                  "building a stub. See src/libarchive/PLACEHOLDER.md to enable "
                  "archive support.")
endif()

if (ANDROID)
  target_link_options(archive_ffi PRIVATE "-Wl,-z,max-page-size=16384")
endif()
