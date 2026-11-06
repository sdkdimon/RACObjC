workspace 'RACObjC.xcworkspace'

use_frameworks!

def test_pods
  pod 'Quick'
  pod 'Nimble'
end

# One test bundle per module and platform, e.g. RACObjCKVO-macOSTests.
modules = %w[Core Deallocation KVO Command Swizzling Extras]
platforms = {
  'iOS' => [:ios, '15.0'],
  'macOS' => [:osx, '14.0'],
}

modules.each do |mod|
  platforms.each do |name, (platform_name, version)|
    target "RACObjC#{mod}-#{name}Tests" do
      project 'RACObjC.xcodeproj'
      platform platform_name, version
      test_pods
    end
  end
end

post_install do |installer|
  installer.pods_project.targets.each do |target|
    target.build_configurations.each do |config|
      config.build_settings['IPHONEOS_DEPLOYMENT_TARGET'] = '$(inherited)'
      config.build_settings['MACOSX_DEPLOYMENT_TARGET'] = '$(inherited)'
      config.build_settings['WATCHOS_DEPLOYMENT_TARGET'] = '$(inherited)'
    end
  end
end
