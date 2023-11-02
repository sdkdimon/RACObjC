workspace 'RACObjC.xcworkspace'

use_frameworks!

def test_pods
  pod 'Quick'
  pod 'Nimble'
end

target 'RACObjC-iOSTests' do
  project 'Core/RACObjC.xcodeproj'
  platform :ios, '12.0'
  test_pods
end

target 'RACObjC-macOSTests' do
  project 'Core/RACObjC.xcodeproj'
  platform :osx, '10.15'
  test_pods
end

target 'RACObjC-tvOSTests' do
  project 'Core/RACObjC.xcodeproj'
  platform :tvos, '9.0'
  test_pods
end

post_install do |installer|
  installer.pods_project.targets.each do |target|
    target.build_configurations.each do |config|
      config.build_settings['IPHONEOS_DEPLOYMENT_TARGET'] = '$(inherited)'
      config.build_settings['MACOSX_DEPLOYMENT_TARGET'] = '$(inherited)'
      config.build_settings['TVOS_DEPLOYMENT_TARGET'] = '$(inherited)'
      config.build_settings['WATCHOS_DEPLOYMENT_TARGET'] = '$(inherited)'
    end
  end
end
