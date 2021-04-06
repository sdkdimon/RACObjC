//
//  NSControl+RACTextSignalSupport.m
//  ReactiveObjC
//
//  Created by Justin Spahr-Summers on 2013-03-08.
//  Copyright (c) 2013 GitHub, Inc. All rights reserved.
//

#import "NSControl+RACTextSignalSupport.h"
#import <RACObjC/EXTScope.h>
#import <RACObjC/NSObject+RACDescription.h>
#import <RACObjC/RACDisposable.h>
#import <RACObjC/RACSignal.h>
#import <RACObjC/RACSubscriber.h>

@implementation NSControl (RACTextSignalSupport)

- (RACSignal *)rac_textSignal {
	@weakify(self);
	return [[[[RACSignal
		createSignal:^(id<RACSubscriber> subscriber) {
			@strongify(self);
			id observer = [NSNotificationCenter.defaultCenter addObserverForName:NSControlTextDidChangeNotification object:self queue:nil usingBlock:^(NSNotification *note) {
				[subscriber sendNext:note.object];
			}];

			return [RACDisposable disposableWithBlock:^{
				[NSNotificationCenter.defaultCenter removeObserver:observer];
			}];
		}]
		map:^(NSControl *control) {
			return [control.stringValue copy];
		}]
		startWith:[self.stringValue copy]]
		setNameWithFormat:@"%@ -rac_textSignal", RACDescription(self)];
}

@end
