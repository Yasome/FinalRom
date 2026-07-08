#
# To learn more about a Podspec see http://guides.cocoapods.org/syntax/podspec.html.
# Run `pod lib lint mbedtls_ffi.podspec` to validate before publishing.
#
Pod::Spec.new do |s|
  s.name             = 'mbedtls_ffi'
  s.version          = '0.0.1'
  s.summary          = 'FFI bindings to Mbed TLS (PSA) AES-CTR and hashing.'
  s.description      = <<-DESC
FFI bindings to the Mbed TLS PSA Crypto API for native AES-CTR and
MD5/SHA-1/SHA-256 hashing.
                       DESC
  s.homepage         = 'https://github.com/yasome'
  s.license          = { :file => '../LICENSE' }
  s.author           = { 'yasome' => 'aldwalshafy@gmail.com' }
  s.source           = { :path => '.' }

  # Compiles the shared C-ABI wrapper only. iOS is not a build target (repo
  # precedent), so MBEDTLS_AVAILABLE is left undefined and the wrapper's stub
  # branch is built: every call returns MBEDTLS_FFI_ERR_LIB_UNAVAILABLE. The
  # supported Apple build is the macOS Swift Package (macos/mbedtls_ffi). To
  # enable real crypto on iOS, vendor the Mbed TLS sources into an SPM/Pods
  # target, add '-DMBEDTLS_AVAILABLE=1', and wire the include paths.
  s.source_files = '../src/mbedtls_ffi.{h,c}'
  s.public_header_files = '../src/mbedtls_ffi.h'

  s.dependency 'Flutter'
  s.platform = :ios, '12.0'

  s.pod_target_xcconfig = {
    'DEFINES_MODULE' => 'YES',
    'EXCLUDED_ARCHS[sdk=iphonesimulator*]' => 'i386',
  }
  s.swift_version = '5.0'
end
