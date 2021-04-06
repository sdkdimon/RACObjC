//
//  NSText+RACSignalSupport.m
//  ReactiveObjC
//
//  Created by Justin Spahr-Summers on 2013-03-08.
//  Copyright (c) 2013 GitHub, Inc. All rights reserved.
//

#import "NSText+RACSignalSupport.h"

#import <RACObjC/NSObject+RACDescription.h>
#import <RACObjC/RACDisposable.h>
#import <RACObjC/RACSignal.h>
#import <RACObjC/RACSubscriber.h>
#import <RACObjC/EXTScope.h>

@implementation NSText (RACSignalSupport)

- (RACSignal *)rac_textSignal {
	@unsafeify(self);
	return [[[[RACSignal
		createSignal:^(id<RACSubscriber> subscriber) {
			@strongify(self);
			id observer = [NSNotificationCenter.defaultCenter addObserverForName:NSTextDidChangeNotification object:self queue:nil usingBlock:^(NSNotification *note) {
				[subscriber sendNext:note.object];
			}];

			return [RACDisposable disposableWithBlock:^{
				[NSNotificationCenter.defaultCenter removeObserver:observer];
			}];
		}]
		map:^(NSText *text) {
			return [text.string copy];
		}]
		startWith:[self.string copy]]
		setNameWithFormat:@"%@ -rac_textSignal", RACDescription(self)];
}

@end
