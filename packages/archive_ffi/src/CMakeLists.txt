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

# The vendored libarchive sources are optional. When present
# (libarchive/libarchive/archive.h), a later stage compiles the real backend;
# otherwise the stub in archive_ffi.c is built so the host app still links and
# runs (archive operations return ARCHIVE_FFI_ERR_LIB_UNAVAILABLE at runtime).
# See libarchive/PLACEHOLDER.md.
set(LIBARCHIVE_DIR "${CMAKE_CURRENT_SOURCE_DIR}/libarchive")
if (EXISTS "${LIBARCHIVE_DIR}/libarchive/archive.h")
  message(STATUS "archive_ffi: vendored libarchive found — "
                 "the real backend is wired in a later stage.")
else()
  message(WARNING "archive_ffi: libarchive sources not found in src/libarchive — "
                  "building a stub. See src/libarchive/PLACEHOLDER.md to enable "
                  "archive support.")
endif()

if (ANDROID)
  target_link_options(archive_ffi PRIVATE "-Wl,-z,max-page-size=16384")
endif()
