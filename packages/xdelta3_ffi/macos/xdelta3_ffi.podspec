#
# To learn more about a Podspec see http://guides.cocoapods.org/syntax/podspec.html.
# Run `pod lib lint xdelta3_ffi.podspec` to validate before publishing.
#
Pod::Spec.new do |s|
  s.name             = 'xdelta3_ffi'
  s.version          = '0.0.1'
  s.summary          = 'FFI bindings to the native xdelta3 (VCDIFF) library.'
  s.description      = <<-DESC
FFI bindings to xdelta3 (VCDIFF) for applying .xdelta ROM patches.
                       DESC
  s.homepage         = 'https://github.com/yasome'
  s.license          = { :file => '../src/xdelta/LICENSE' }
  s.author           = { 'yasome' => 'aldwalshafy@gmail.com' }
  s.source           = { :path => '.' }

  # Real xdelta3 build with the header-only DJW secondary compressor only.
  # liblzma is intentionally not built on macOS (CocoaPods can't run the CMake
  # that the other platforms use), so patches made with `-S lzma` will not
  # apply here; `-S djw` / default patches do. The wrapper unity-includes
  # ../src/xdelta/xdelta3.c, so only the wrapper is listed as a source.
  s.source_files        = '../src/xdelta3_ffi.{h,c}'
  s.public_header_files = '../src/xdelta3_ffi.h'
  s.preserve_paths      = '../src/xdelta/**/*'

  s.dependency 'FlutterMacOS'
  s.platform = :osx, '10.14'

  s.pod_target_xcconfig = {
    'DEFINES_MODULE' => 'YES',
    'HEADER_SEARCH_PATHS' => '"$(PODS_TARGET_SRCROOT)/../src"',
    'GCC_PREPROCESSOR_DEFINITIONS' =>
      '$(inherited) DART_SHARED_LIB=1 XDELTA3_AVAILABLE=1 SECONDARY_DJW=1',
  }
  s.swift_version = '5.0'
end
