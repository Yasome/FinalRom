# The Flutter tooling requires that developers have CMake 3.10 or later
# installed. You should not increase this version, as doing so will cause
# the plugin to fail to compile for some customers of the plugin.
cmake_minimum_required(VERSION 3.10)

project(mbedtls_ffi_library VERSION 0.0.1 LANGUAGES C)

if (ANDROID)
  # Force Android 15's 16 KB page size requirement globally for any bundled libraries
  set(CMAKE_SHARED_LINKER_FLAGS "${CMAKE_SHARED_LINKER_FLAGS} -Wl,-z,max-page-size=16384")
  set(CMAKE_MODULE_LINKER_FLAGS "${CMAKE_MODULE_LINKER_FLAGS} -Wl,-z,max-page-size=16384")
endif()

add_library(mbedtls_ffi SHARED
  "mbedtls_ffi.c"
)

set_target_properties(mbedtls_ffi PROPERTIES
  PUBLIC_HEADER mbedtls_ffi.h
  OUTPUT_NAME "mbedtls_ffi"
  C_STANDARD 99
)

target_compile_definitions(mbedtls_ffi PUBLIC DART_SHARED_LIB)

# The Mbed TLS sources must be vendored into ./mbedtls (the official 4.2.0
# release tree, including tf-psa-crypto/). When present, compile the real PSA
# implementation and statically link the crypto library into this shared lib.
# Without it, refuse to build (fail-loud, matching the other FFI plugins) —
# the C wrapper's stub branch exists only for build configs that deliberately
# omit the library (e.g. the iOS podspec).
if (EXISTS "${CMAKE_CURRENT_SOURCE_DIR}/mbedtls/tf-psa-crypto/CMakeLists.txt")
  message(STATUS "mbedtls_ffi: building with vendored Mbed TLS 4.2.0 sources")
  target_compile_definitions(mbedtls_ffi PRIVATE MBEDTLS_AVAILABLE=1)

  # tfpsacrypto is built as a static archive that gets linked into this shared
  # library, so it must be position-independent.
  set(CMAKE_POSITION_INDEPENDENT_CODE ON)

  # Mbed TLS 4.x moved crypto into the TF-PSA-Crypto subproject and exposes it
  # only through the PSA API. Build just that subproject (not X509/TLS) and feed
  # it our trimmed PSA config as a full replacement for its default.
  set(TF_PSA_CRYPTO_CONFIG_FILE
      "${CMAKE_CURRENT_SOURCE_DIR}/crypto_config.h" CACHE FILEPATH "" FORCE)
  set(ENABLE_PROGRAMS OFF CACHE BOOL "" FORCE)
  set(ENABLE_TESTING OFF CACHE BOOL "" FORCE)
  # Don't let -Werror on the vendored crypto sources fail our build.
  set(TF_PSA_CRYPTO_FATAL_WARNINGS OFF CACHE BOOL "" FORCE)

  add_subdirectory("${CMAKE_CURRENT_SOURCE_DIR}/mbedtls/tf-psa-crypto"
                   "${CMAKE_CURRENT_BINARY_DIR}/tf-psa-crypto" EXCLUDE_FROM_ALL)

  # The crypto target's public headers (psa/crypto.h) plus the built-in driver
  # headers the wrapper resolves through them.
  target_include_directories(mbedtls_ffi PRIVATE
    "${CMAKE_CURRENT_SOURCE_DIR}/mbedtls/tf-psa-crypto/include"
    "${CMAKE_CURRENT_SOURCE_DIR}/mbedtls/tf-psa-crypto/drivers/builtin/include")

  target_link_libraries(mbedtls_ffi PRIVATE tfpsacrypto)
else()
  message(FATAL_ERROR "mbedtls_ffi: Mbed TLS sources missing from src/mbedtls — "
                      "refusing to build a stub. See README.md to vendor "
                      "mbedtls-4.2.0.tar.bz2.")
endif()

if (ANDROID)
  # Support Android 15's 16 KB page size requirement.
  target_link_options(mbedtls_ffi PRIVATE "-Wl,-z,max-page-size=16384")
endif()
