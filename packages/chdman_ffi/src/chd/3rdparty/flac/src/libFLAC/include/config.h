#if defined(__i386__) || defined(_M_IX86)
#define FLAC__CPU_IA32
#endif

#if defined(__x86_64__) || defined(_M_X64)
#define FLAC__CPU_X86_64
#endif

#if defined(__i386__) || defined(__x86_64__) || defined(_M_IX86) || defined(_M_X64)
#define FLAC__ALIGN_MALLOC_DATA
#define FLAC__HAS_X86INTRIN 1
#else
#define FLAC__HAS_X86INTRIN 0
#endif

#if defined(__aarch64__) || defined(_M_ARM64)
#define FLAC__CPU_ARM64
#define FLAC__HAS_NEONINTRIN 1
#define FLAC__HAS_A64NEONINTRIN 1
#else
#define FLAC__HAS_NEONINTRIN 0
#define FLAC__HAS_A64NEONINTRIN 0
#endif

#define PACKAGE_VERSION "1.4.3"

/* ---- Functional config for a no-OGG static libFLAC build on macOS. The vendored
   CMake path generates these from config.cmake.h.in; the SwiftPM build has no
   configure step, so they are set here. Values hold for macOS on arm64 and x86_64. */
#define FLAC__HAS_OGG 0
#define OGG_FOUND 0
#define CPU_IS_BIG_ENDIAN 0
#define CPU_IS_LITTLE_ENDIAN 1
#define WORDS_BIGENDIAN 0
#define ENABLE_64_BIT_WORDS 0
#define HAVE_BSWAP16 1
#define HAVE_BSWAP32 1
#define HAVE_CLOCK_GETTIME 1
#define HAVE_FSEEKO 1
#define HAVE_INTTYPES_H 1
#define HAVE_STDINT_H 1
#define HAVE_STDLIB_H 1
#define HAVE_STRING_H 1
#define HAVE_MEMORY_H 1
#define HAVE_SYS_PARAM_H 1
#define HAVE_SYS_STAT_H 1
#define HAVE_SYS_TYPES_H 1
#define HAVE_UNISTD_H 1
#define HAVE_LROUND 1
#define SIZEOF_OFF_T 8
#define SIZEOF_VOIDP 8

/* x86-only headers/intrinsics — guarded so the arm64 slice doesn't include them. */
#if defined(__x86_64__) || defined(__i386__)
#define HAVE_CPUID_H 1
#define HAVE_X86INTRIN_H 1
#endif

#ifndef _FILE_OFFSET_BITS
#define _FILE_OFFSET_BITS 64
#endif
