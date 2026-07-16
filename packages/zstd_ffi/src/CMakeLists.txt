# The Flutter tooling requires that developers have CMake 3.10 or later
# installed. You should not increase this version, as doing so will cause
# the plugin to fail to compile for some customers of the plugin.
cmake_minimum_required(VERSION 3.10)

project(zstd_ffi_library VERSION 0.0.1 LANGUAGES C)

if (ANDROID)
  # Force Android 15's 16 KB page size requirement globally for any bundled libraries
  set(CMAKE_SHARED_LINKER_FLAGS "${CMAKE_SHARED_LINKER_FLAGS} -Wl,-z,max-page-size=16384")
  set(CMAKE_MODULE_LINKER_FLAGS "${CMAKE_MODULE_LINKER_FLAGS} -Wl,-z,max-page-size=16384")
endif()

add_library(zstd_ffi SHARED
  "zstd_ffi.c"
)

set_target_properties(zstd_ffi PROPERTIES
  PUBLIC_HEADER zstd_ffi.h
  OUTPUT_NAME "zstd_ffi"
  C_STANDARD 99
)

target_compile_definitions(zstd_ffi PUBLIC DART_SHARED_LIB)

# The libzstd sources are optional. When the user vendors the zstd source tree
# into ./zstd (containing lib/zstd.h and the lib/ implementation), compile the
# real implementation; without it, a stub is built so the host application
# still links and runs (compression then returns ZSTD_FFI_ERR_LIB_UNAVAILABLE
# at runtime).
if (EXISTS "${CMAKE_CURRENT_SOURCE_DIR}/zstd/lib/zstd.h")
  message(STATUS "zstd_ffi: building with vendored libzstd sources")
  target_compile_definitions(zstd_ffi PRIVATE ZSTD_AVAILABLE=1)
  target_include_directories(zstd_ffi PRIVATE "${CMAKE_CURRENT_SOURCE_DIR}/zstd/lib")

  # Build libzstd as a static library from its CMake project, then link it.
  if (EXISTS "${CMAKE_CURRENT_SOURCE_DIR}/zstd/build/cmake/CMakeLists.txt")
    set(ZSTD_BUILD_PROGRAMS OFF CACHE BOOL "" FORCE)
    set(ZSTD_BUILD_SHARED OFF CACHE BOOL "" FORCE)
    set(ZSTD_BUILD_STATIC ON CACHE BOOL "" FORCE)
    # Enable multi-threaded compression (ZSTD_c_nbWorkers). zstd's CMake
    # defaults this OFF on Android, so force it on for every platform; it links
    # pthread on UNIX/Android and uses native threads on MSVC.
    set(ZSTD_MULTITHREAD_SUPPORT ON CACHE BOOL "" FORCE)
    # The app only ever reads/writes modern zstd frames (NSZ); zstd's CMake
    # default compiles the v0.1-v0.7 legacy decoders (~1 MB) we never use, so
    # turn them off to shrink the binary and speed the build.
    set(ZSTD_LEGACY_SUPPORT OFF CACHE BOOL "" FORCE)
    add_subdirectory("${CMAKE_CURRENT_SOURCE_DIR}/zstd/build/cmake"
                     "${CMAKE_CURRENT_BINARY_DIR}/zstd" EXCLUDE_FROM_ALL)
    target_link_libraries(zstd_ffi PRIVATE libzstd_static)
  endif()
else()
  message(FATAL_ERROR "zstd_ffi: libzstd sources missing from src/zstd — "
                      "refusing to build a stub. See src/zstd/PLACEHOLDER.md "
                      "to enable Zstandard support.")
endif()

if (ANDROID)
  # Support Android 15's 16 KB page size requirement.
  target_link_options(zstd_ffi PRIVATE "-Wl,-z,max-page-size=16384")
endif()
