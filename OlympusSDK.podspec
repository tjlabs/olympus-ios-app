
Pod::Spec.new do |s|
  s.name             = 'OlympusSDK'
  s.version          = '0.2.25'
  s.summary          = 'OlympusSDK for iOS'
  s.swift_version    = '5.0'
  
  s.ios.deployment_target = '15.0'
  
  s.description      = <<-DESC
TODO: Add long description of the pod here.
                       DESC
  s.homepage         = 'https://www.tjlabscorp.com'
  s.license          = { :type => 'MIT', :file => 'LICENSE' }
  s.author           = { 'tjlabs-dev' => 'dev@tjlabscorp.com' }
  s.source           = { :git => 'https://github.com/tjlabs/olympus-ios-app.git', :tag => s.version.to_s }

  s.static_framework = true
  s.source_files = 'OlympusSDK/Classes/**/*'
  
  s.pod_target_xcconfig = { 'SWIFT_OPTIMIZATION_LEVEL' => '-Owholemodule' }
end
