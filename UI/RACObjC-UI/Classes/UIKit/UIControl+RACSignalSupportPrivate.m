//
//  UIControl+RACSignalSupportPrivate.m
//  ReactiveObjC
//
//  Created by Uri Baghin on 06/08/2013.
//  Copyright (c) 2013 GitHub, Inc. All rights reserved.
//

#import "UIControl+RACSignalSupportPrivate.h"
#import <RACObjC/NSObject+RACDeallocating.h> 
#import <RACObjC/NSObject+RACLifting.h>
#import <RACObjC/RACChannel.h>
#import <RACObjC/RACCompoundDisposable.h>
#import <RACObjC/RACDisposable.h>
#import <RACObjC/RACSignal+Operations.h>
#import "UIControl+RACSignalSupport.h"

@implementation UIControl (RACSignalSupportPrivate)

- (RACChannelTerminal *)rac_channelForControlEvents:(UIControlEvents)controlEvents key:(NSString *)key nilValue:(id)nilValue {
	NSCParameterAssert(key.length > 0);
	key = [key copy];
	RACChannel *channel = [[RACChannel alloc] init];

	[self.rac_deallocDisposable addDisposable:[RACDisposable disposableWithBlock:^{
		[channel.followingTerminal sendCompleted];
	}]];

	RACSignal *eventSignal = [[[self
		rac_signalForControlEvents:controlEvents]
		mapReplace:key]
		takeUntil:[[channel.followingTerminal
			ignoreValues]
			catchTo:RACSignal.empty]];
	[[self
		rac_liftSelector:@selector(valueForKey:) withSignals:eventSignal, nil]
		subscribe:channel.followingTerminal];

	RACSignal *valuesSignal = [channel.followingTerminal
		map:^(id value) {
			return value ?: nilValue;
		}];
	[self rac_liftSelector:@selector(setValue:forKey:) withSignals:valuesSignal, [RACSignal return:key], nil];

	return channel.leadingTerminal;
}

@end
