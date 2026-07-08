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

  # The supported macOS build is the Swift Package (macos/mbedtls_ffi), which
  # compiles the vendored Mbed TLS crypto and defines MBEDTLS_AVAILABLE. This
  # CocoaPods podspec is a fallback that compiles only the shared C-ABI wrapper
  # stub (MBEDTLS_AVAILABLE undefined) so calls return
  # MBEDTLS_FFI_ERR_LIB_UNAVAILABLE.
  s.source_files = '../src/mbedtls_ffi.{h,c}'
  s.public_header_files = '../src/mbedtls_ffi.h'

  s.dependency 'FlutterMacOS'
  s.platform = :osx, '10.14'

  s.pod_target_xcconfig = {
    'DEFINES_MODULE' => 'YES',
  }
  s.swift_version = '5.0'
end
