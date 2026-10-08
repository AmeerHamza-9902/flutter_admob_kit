Pod::Spec.new do |spec|
  spec.name             = 'flutter_admob_kit'
  spec.version          = '4.0.1'
  spec.summary          = 'AdMob Kit native ad layouts for Flutter.'
  spec.description      = 'Bundled media-safe iOS native layouts for AdMob Kit.'
  spec.homepage         = 'https://github.com/AmeerHamza-9902/flutter_admob_kit'
  spec.license          = { :file => '../LICENSE' }
  spec.author           = { 'AdMob Kit' => 'AmeerHamza-9902' }
  spec.source           = { :path => '.' }
  spec.source_files     = 'flutter_admob_kit/Sources/flutter_admob_kit/**/*.{h,m}'
  spec.public_header_files = 'flutter_admob_kit/Sources/flutter_admob_kit/include/flutter_admob_kit/*.h'
  spec.dependency 'Flutter'
  spec.dependency 'google_mobile_ads'
  spec.platform = :ios, '13.0'
  spec.static_framework = true
end
