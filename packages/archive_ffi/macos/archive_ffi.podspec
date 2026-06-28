#
# To learn more about a Podspec see http://guides.cocoapods.org/syntax/podspec.html.
# Run `pod lib lint archive_ffi.podspec` to validate before publishing.
#
Pod::Spec.new do |s|
  s.name             = 'archive_ffi'
  s.version          = '0.0.1'
  s.summary          = 'FFI bindings to libarchive for archive compression/extraction.'
  s.description      = <<-DESC
FFI bindings to libarchive for general-purpose archive compression and
extraction (zip, 7z, gzip, zstd, tar...).
                       DESC
  s.homepage         = 'https://github.com/yasome'
  s.license          = { :file => '../LICENSE' }
  s.author           = { 'yasome' => 'aldwalshafy@gmail.com' }
  s.source           = { :path => '.' }

  # Compiles the shared C-ABI wrapper. The stub is built unless the vendored
  # libarchive sources are added: to enable the real backend on macOS, add the
  # libarchive + codec sources to source_files below and append
  # '-DARCHIVE_FFI_HAVE_LIBARCHIVE=1' to the xcconfig, then vendor the sources
  # per src/libarchive/PLACEHOLDER.md.
  s.source_files = '../src/archive_ffi.{h,c}'
  s.public_header_files = '../src/archive_ffi.h'

  s.dependency 'FlutterMacOS'
  s.platform = :osx, '10.14'

  s.pod_target_xcconfig = {
    'DEFINES_MODULE' => 'YES',
  }
  s.swift_version = '5.0'
end
