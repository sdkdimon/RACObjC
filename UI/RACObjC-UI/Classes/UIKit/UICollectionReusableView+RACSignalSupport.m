//
//  UICollectionReusableView+RACSignalSupport.m
//  ReactiveObjC
//
//  Created by Kent Wong on 2013-10-04.
//  Copyright (c) 2013 GitHub, Inc. All rights reserved.
//

#import "UICollectionReusableView+RACSignalSupport.h"
#import <RACObjC/NSObject+RACDescription.h>
#import <RACObjC/NSObject+RACSelectorSignal.h>
#import <RACObjC/RACSignal+Operations.h>
#import <RACObjC/RACUnit.h>
#import <objc/runtime.h>

@implementation UICollectionReusableView (RACSignalSupport)

- (RACSignal *)rac_prepareForReuseSignal {
	RACSignal *signal = objc_getAssociatedObject(self, _cmd);
	if (signal != nil) return signal;
	
	signal = [[[self
		rac_signalForSelector:@selector(prepareForReuse)]
		mapReplace:RACUnit.defaultUnit]
		setNameWithFormat:@"%@ -rac_prepareForReuseSignal", RACDescription(self)];
	
	objc_setAssociatedObject(self, _cmd, signal, OBJC_ASSOCIATION_RETAIN_NONATOMIC);
	return signal;
}

@end
