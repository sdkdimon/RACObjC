//
//  MKAnnotationView+RACSignalSupport.m
//  ReactiveObjC
//
//  Created by Zak Remer on 3/31/15.
//  Copyright (c) 2015 GitHub. All rights reserved.
//

#import "MKAnnotationView+RACSignalSupport.h"
#import <RACObjC/NSObject+RACDescription.h>
#import <RACObjC/NSObject+RACSelectorSignal.h>
#import <RACObjC/RACSignal+Operations.h>
#import <RACObjC/RACUnit.h>
#import <objc/runtime.h>

@implementation MKAnnotationView (RACSignalSupport)

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
