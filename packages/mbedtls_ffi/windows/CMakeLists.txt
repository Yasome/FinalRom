# The Flutter tooling requires that developers have a version of Visual Studio
# installed that includes CMake 3.14 or later. You should not increase this
# version, as doing so will cause the plugin to fail to compile for some
# customers of the plugin.
cmake_minimum_required(VERSION 3.14)

# Project-level configuration.
set(PROJECT_NAME "mbedtls_ffi")
project(${PROJECT_NAME} LANGUAGES C)

# Invoke the build for native code shared with the other target platforms.
add_subdirectory("${CMAKE_CURRENT_SOURCE_DIR}/../src" "${CMAKE_CURRENT_BINARY_DIR}/shared")

# Our crypto_config.h enables no asymmetric PSA mechanisms, so
# MBEDTLS_PK_MAX_PUBKEY_RAW_LEN collapses to 0 and mbedtls_pk_context's
# pub_raw member becomes a zero-sized array (mbedtls/pk.h). GCC/Clang accept
# that as an extension (macOS/Linux/Android build fine), but MSVC rejects it
# with C2229. The PK and OID modules are never called by mbedtls_ffi.c (PSA
# cipher/hash only), so drop their object files from the vendored
# extras/utilities targets instead of patching the vendored header.
if (TARGET extras)
  get_target_property(mbedtls_ffi_extras_sources extras SOURCES)
  list(FILTER mbedtls_ffi_extras_sources EXCLUDE REGEX "(^|/)pk[^/]*\\.c$")
  set_property(TARGET extras PROPERTY SOURCES ${mbedtls_ffi_extras_sources})
endif()
if (TARGET utilities)
  get_target_property(mbedtls_ffi_utilities_sources utilities SOURCES)
  list(FILTER mbedtls_ffi_utilities_sources EXCLUDE REGEX "(^|/)oid\\.c$")
  set_property(TARGET utilities PROPERTY SOURCES ${mbedtls_ffi_utilities_sources})
endif()

# List of absolute paths to libraries that should be bundled with the plugin.
set(mbedtls_ffi_bundled_libraries
  $<TARGET_FILE:mbedtls_ffi>
  PARENT_SCOPE
)
