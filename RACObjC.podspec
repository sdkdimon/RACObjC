Pod::Spec.new do |s|

  s.name         = "RACObjC"
  s.version      = "3.3.0"
  s.summary      = "The 2.x ReactiveCocoa Objective-C API: Streams of values over time"

  s.description  = <<-DESC.strip_heredoc
                     ReactiveObjC (formally ReactiveCocoa or RAC) is an Objective-C
                     framework inspired by [Functional Reactive Programming](
                     http://en.wikipedia.org/wiki/Functional_reactive_programming).
                     It provides APIs for composing and **transforming streams of values**.
                   DESC

  s.homepage     = "https://github.com/sdkdimon/RACObjC"
  s.license      = { type: "MIT", file: "LICENSE" }

  s.documentation_url  = "https://github.com/sdkdimon/RACObjC/tree/master/Documentation#readme"

  s.author             = "Dmitry Lizin"
 
  s.source = { git: "https://github.com/sdkdimon/RACObjC.git", tag: s.version }
  
  s.ios.deployment_target     = "12.0"
  s.osx.deployment_target     = "10.13"
  s.watchos.deployment_target = "2.0"

  s.module_map = "RACObjC/RACObjC.modulemap"

  s.resource_bundles = { "RACObjC_Privacy" => ["RACObjC/PrivacyInfo.xcprivacy"] }

  # One subspec per module (RACObjC/<Module>). The default is all
  # of them, as before the split; pick fewer with e.g. pod 'RACObjC/KVO'.
  s.default_subspecs = "Core", "Deallocation", "KVO", "Command", "Swizzling", "Extras"

  # Signals and their operators, subjects, subscribers, disposables,
  # schedulers, sequences and tuples. No KVO and no swizzling.
  s.subspec "Core" do |ss|
    ss.source_files         = "RACObjC/RACObjC.h",
                              "RACObjC/Core/**/*.{h,m,d}"
    ss.private_header_files = "RACObjC/Core/**/*Private.h",
                              "RACObjC/Core/**/*EXTRuntimeExtensions.h",
                              "RACObjC/Core/**/RACEmpty*.h"
  end

  # -rac_willDeallocSignal and -rac_deallocDisposable (swizzle -dealloc).
  s.subspec "Deallocation" do |ss|
    ss.dependency "RACObjC/Core"
    ss.source_files = "RACObjC/Deallocation/**/*.{h,m}"
  end

  # RACObserve(), RACChannelTo(), RAC() and -setKeyPath:onObject:.
  s.subspec "KVO" do |ss|
    ss.dependency "RACObjC/Deallocation"
    ss.source_files = "RACObjC/KVO/**/*.{h,m}"
  end

  # RACCommand.
  s.subspec "Command" do |ss|
    ss.dependency "RACObjC/Deallocation"
    ss.source_files = "RACObjC/Command/**/*.{h,m}"
  end

  # -rac_signalForSelector:, RACDelegateProxy, -rac_liftSelector:withSignals:.
  s.subspec "Swizzling" do |ss|
    ss.dependency "RACObjC/Deallocation"
    ss.source_files = "RACObjC/Swizzling/**/*.{h,m}"
  end

  # Foundation additions: -rac_sequence for collections, strings and
  # enumerators; signals for NSNotificationCenter, NSData, NSString,
  # NSFileHandle and NSUserDefaults; RACValueTransformer.
  s.subspec "Extras" do |ss|
    ss.dependency "RACObjC/Deallocation"
    ss.source_files = "RACObjC/Extras/**/*.{h,m}"
  end

  s.requires_arc = true

  s.frameworks   = "Foundation"
  
  s.prepare_command = <<-'CMD'.strip_heredoc
                         /usr/bin/find -E . -type f -not -name 'RAC*' -regex '.*(EXT.*|metamacros)\.[hm]$' \
                                   -execdir mv '{}' RAC'{}' \;
                         /usr/bin/find . -regex '.*\.[hm]' \
                                -exec perl -pi \
                                           -e 's@"(?:(?!RAC)(EXT.*|metamacros))\.h"@"RAC\1.h"@' '{}' \;
                         /usr/bin/find . -regex '.*\.[hm]' \
                                -exec perl -pi \
                                           -e 's@<RACObjC/(?:(?!RAC)(EXT.*|metamacros))\.h>@<RACObjC/RAC\1.h>@' '{}' \;
                       CMD

end
