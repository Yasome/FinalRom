# The Flutter tooling requires that developers have CMake 3.10 or later
# installed. You should not increase this version, as doing so will cause
# the plugin to fail to compile for some customers of the plugin.
cmake_minimum_required(VERSION 3.10)

project(xdelta3_ffi_library VERSION 0.0.1 LANGUAGES C)

if (ANDROID)
  # Force Android 15's 16 KB page size requirement globally for any bundled libraries
  set(CMAKE_SHARED_LINKER_FLAGS "${CMAKE_SHARED_LINKER_FLAGS} -Wl,-z,max-page-size=16384")
  set(CMAKE_MODULE_LINKER_FLAGS "${CMAKE_MODULE_LINKER_FLAGS} -Wl,-z,max-page-size=16384")
endif()

add_library(xdelta3_ffi SHARED
  "xdelta3_ffi.c"
)

set_target_properties(xdelta3_ffi PROPERTIES
  PUBLIC_HEADER xdelta3_ffi.h
  OUTPUT_NAME "xdelta3_ffi"
  C_STANDARD 99
)

target_compile_definitions(xdelta3_ffi PUBLIC DART_SHARED_LIB)

# The upstream xdelta3 single-file library is optional. When the user vendors
# xdelta3.h + xdelta3.c into ./xdelta, compile the real implementation; without
# them, a stub is built so the host application still links and runs (xdelta
# patching then returns XDELTA3_FFI_ERR_LIB_UNAVAILABLE at runtime).
if (EXISTS "${CMAKE_CURRENT_SOURCE_DIR}/xdelta/xdelta3.c"
    AND EXISTS "${CMAKE_CURRENT_SOURCE_DIR}/xdelta/xdelta3.h")
  message(STATUS "xdelta3_ffi: building with bundled xdelta3 sources")
  target_compile_definitions(xdelta3_ffi PRIVATE XDELTA3_AVAILABLE=1)
  target_include_directories(xdelta3_ffi PRIVATE "${CMAKE_CURRENT_SOURCE_DIR}")

  # ---- liblzma (xz) for xdelta3's "-S lzma" secondary compression ----
  # xdelta3-lzma.h references both the liblzma encoder and decoder entrypoints
  # (xd3_lzma_init calls lzma_stream_encoder/decoder unconditionally), so we
  # build the full static liblzma from the vendored xz tree and link it in.
  # The xz CMake otherwise builds the xz/xzdec CLI executables on non-MSVC
  # toolchains (e.g. Android); both add_executable() calls are gated on
  # HAVE_GETOPT_LONG, so we pre-seed it OFF in the cache to suppress them
  # everywhere. ENABLE_THREADS=OFF keeps liblzma single-threaded (decode is a
  # one-shot call) and avoids a Threads:: dependency. EXCLUDE_FROM_ALL plus
  # static linkage means only our DLL ships; liblzma is built only because we
  # link it.
  set(BUILD_SHARED_LIBS OFF CACHE BOOL "" FORCE)
  set(BUILD_TESTING OFF CACHE BOOL "" FORCE)
  set(HAVE_GETOPT_LONG OFF CACHE INTERNAL "xdelta3_ffi: never build the xz CLI tools")
  set(ENABLE_THREADS OFF CACHE STRING "xdelta3_ffi: single-threaded liblzma" FORCE)
  set(CREATE_XZ_SYMLINKS OFF CACHE BOOL "" FORCE)
  set(CREATE_LZMA_SYMLINKS OFF CACHE BOOL "" FORCE)
  # Static liblzma is linked into the shared plugin, so it must be built -fPIC
  # or the link fails with a text-relocation error on Linux.
  set(CMAKE_POSITION_INDEPENDENT_CODE ON)
  add_subdirectory("${CMAKE_CURRENT_SOURCE_DIR}/xz"
                   "${CMAKE_CURRENT_BINARY_DIR}/xz" EXCLUDE_FROM_ALL)

  # LZMA_API_STATIC: we link liblzma statically, so its public headers must not
  # mark the entrypoints __declspec(dllimport) on Windows (otherwise the linker
  # looks for __imp_lzma_* import-stubs that a static lib doesn't provide).
  target_compile_definitions(xdelta3_ffi PRIVATE SECONDARY_DJW=1 HAVE_LZMA_H LZMA_API_STATIC)
  target_include_directories(xdelta3_ffi PRIVATE
    "${CMAKE_CURRENT_SOURCE_DIR}/xz/src/liblzma/api")
  target_link_libraries(xdelta3_ffi PRIVATE liblzma)

  if (MSVC)
    # Quiet the expected third-party narrowing/sign/CRT-deprecation warnings in
    # xdelta3 and liblzma so a real diagnostic can't hide in the noise.
    target_compile_options(xdelta3_ffi PRIVATE /wd4244 /wd4267 /wd4146 /wd4996)
    target_compile_definitions(xdelta3_ffi PRIVATE _CRT_SECURE_NO_WARNINGS)
  endif()
else()
  message(WARNING "xdelta3_ffi: xdelta3 sources not found in src/xdelta — "
                  "building a stub. Drop xdelta3.h and xdelta3.c there to "
                  "enable xdelta patching.")
endif()

if (ANDROID)
  # Support Android 15's 16 KB page size requirement.
  target_link_options(xdelta3_ffi PRIVATE "-Wl,-z,max-page-size=16384")
endif()
