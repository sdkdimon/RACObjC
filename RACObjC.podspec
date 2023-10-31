Pod::Spec.new do |s|

  s.name         = "RACObjC"
  s.version      = "3.2.1"
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
  s.tvos.deployment_target    = "12.0"
  
  
  s.subspec 'Core' do |core|
    
    core.source_files         = "Core/RACObjC/Classes/EXTObjC/*.{h,m}",
                                "Core/RACObjC/Classes/**/*.{h,m,d}",
                                "Core/RACObjC/RACObjC.h"
                              
    core.private_header_files = "Core/RACObjC/Classes/**/*Private.h",
                                "Core/RACObjC/Classes/**/*EXTRuntimeExtensions.h",
                                "Core/RACObjC/Classes/**/RACEmpty*.h"
    

  end
  
  s.subspec 'UI' do |ui|
    
    ui.ios.deployment_target  = "12.0"
    ui.osx.deployment_target  = "10.13"
    ui.tvos.deployment_target = "12.0"
    
    ui.dependency 'RACObjC/Core'
    
    ui.source_files       = "UI/RACObjC-UI/Classes/**/*.{h,m}",
                            "UI/RACObjC-UI/RACObjCUI.h"
    
    ui.ios.exclude_files  = "UI/RACObjC-UI/Classes/**/*{AppKit,NSControl,NSText}*"

    ui.osx.exclude_files  = "UI/RACObjC-UI/Classes/**/*{UIActionSheet,UIAlertView,UIBarButtonItem,"\
                            "UIButton,UICollectionReusableView,UIControl,UIDatePicker,"\
                            "UIGestureRecognizer,UIImagePicker,UIRefreshControl,"\
                            "UISegmentedControl,UISlider,UIStepper,UISwitch,UITableViewCell,"\
                            "UITableViewHeaderFooterView,UIText,MK}*"

    ui.tvos.exclude_files  = "UI/RACObjC-UI/Classes/**/*{AppKit,NSControl,NSText,NSTable,UIActionSheet,"\
                             "UIAlertView,UIDatePicker,UIImagePicker,UIRefreshControl,UISlider,"\
                             "UIStepper,UISwitch,MK}*"
  end


  s.requires_arc = true

  s.frameworks   = "Foundation"
  
  s.prepare_command = <<-'CMD'.strip_heredoc
                         find -E . -type f -not -name 'RAC*' -regex '.*(EXT.*|metamacros)\.[hm]$' \
                                   -execdir mv '{}' RAC'{}' \;
                         find . -regex '.*\.[hm]' \
                                -exec perl -pi \
                                           -e 's@"(?:(?!RAC)(EXT.*|metamacros))\.h"@"RAC\1.h"@' '{}' \;
                         find . -regex '.*\.[hm]' \
                                -exec perl -pi \
                                           -e 's@<RACObjC/(?:(?!RAC)(EXT.*|metamacros))\.h>@<RACObjC/RAC\1.h>@' '{}' \;
                       CMD

end
