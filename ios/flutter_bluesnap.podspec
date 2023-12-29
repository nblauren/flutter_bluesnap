#
# To learn more about a Podspec see http://guides.cocoapods.org/syntax/podspec.html.
# Run `pod lib lint flutter_bluesnap.podspec' to validate before publishing.
#
Pod::Spec.new do |s|
  s.name             = 'flutter_bluesnap'
  s.version          = '0.0.1'
  s.summary          = 'Flutter Bluesnap SDK implementation'
  s.description      = <<-DESC
Flutter Bluesnap SDK implementation
                       DESC
  s.homepage         = 'https://github.com/BlidzCo/flutter_bluesnap'
  s.license          = { :file => '../LICENSE' }
  s.author           = { 'Markus Haverinen' => 'markus@blidz.com' }
  s.source           = { :path => '.' }
  s.source_files = 'Classes/**/*'
  s.dependency 'Flutter'
  s.platform = :ios, '12.0'

  # Flutter.framework does not contain a i386 slice. Only x86_64 simulators are supported.
  s.pod_target_xcconfig = { 'DEFINES_MODULE' => 'YES', 'VALID_ARCHS[sdk=iphonesimulator*]' => 'x86_64' }
  s.swift_version = '5.0'

  s.dependency 'BluesnapSDK', '~> 2.0.1'
  s.dependency 'BluesnapSDK/DataCollector', '~> 2.0.1'
end
