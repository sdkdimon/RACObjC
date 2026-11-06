//
//  NSUserDefaultsRACSupportSpec.m
//  ReactiveObjC
//
//  Created by Matt Diephouse on 12/19/13.
//  Copyright (c) 2013 GitHub, Inc. All rights reserved.
//

@import Quick;
@import Nimble;

#import "NSUserDefaults+RACSupport.h"

#import "RACCompoundDisposable.h"
#import "RACDisposable.h"
#import "RACKVOChannel.h"
#import "NSObject+RACDeallocating.h"
#import "RACSignal+Operations.h"

static NSString * const NSUserDefaultsRACSupportSpecSuiteName = @"RACObjCTests.NSUserDefaultsRACSupportSpec";

@interface TestObserver : NSObject

@property (copy, atomic) NSString *string1;
@property (copy, atomic) NSString *string2;

@property (assign, atomic) BOOL bool1;

@end

@implementation TestObserver

@end

QuickSpecBegin(NSUserDefaultsRACSupportSpec)

__block NSUserDefaults *defaults = nil;
__block NSString *stringKey = nil;
__block NSString *boolKey = nil;
__block TestObserver *observer = nil;

// A terminal writes to the defaults on a background scheduler, so a write can
// land after its test has finished. Each test uses its own keys, so a late
// write can't reach a later test, and its own defaults object, so its
// terminals complete once the test releases it.
qck_beforeEach(^{
	defaults = [[NSUserDefaults alloc] initWithSuiteName:NSUserDefaultsRACSupportSpecSuiteName];

	NSString *suffix = NSUUID.UUID.UUIDString;
	stringKey = [@"StringDefault." stringByAppendingString:suffix];
	boolKey = [@"BoolDefault." stringByAppendingString:suffix];

	observer = [TestObserver new];
});

qck_afterEach(^{
	// Also clears late writes from earlier tests.
	[defaults removePersistentDomainForName:NSUserDefaultsRACSupportSpecSuiteName];

	defaults = nil;
	observer = nil;
});

qck_it(@"should set defaults", ^{
	RACChannelTo(observer, string1) = [defaults rac_channelTerminalForKey:stringKey];
	RACChannelTo(observer, bool1, @NO) = [defaults rac_channelTerminalForKey:boolKey];
	
	observer.string1 = @"A string";
	observer.bool1 = YES;
	
	expect([defaults objectForKey:stringKey]).toEventually(equal(@"A string"));
	expect([defaults objectForKey:boolKey]).toEventually(equal(@YES));
});

qck_it(@"should read defaults", ^{
	RACChannelTo(observer, string1) = [defaults rac_channelTerminalForKey:stringKey];
	RACChannelTo(observer, bool1, @NO) = [defaults rac_channelTerminalForKey:boolKey];
	
	expect(observer.string1).to(beNil());
	expect(@(observer.bool1)).to(equal(@NO));
	
	[defaults setObject:@"Another string" forKey:stringKey];
	[defaults setBool:YES forKey:boolKey];
	
	expect(observer.string1).to(equal(@"Another string"));
	expect(@(observer.bool1)).to(equal(@YES));
});

qck_it(@"should be okay to create 2 terminals", ^{
	RACChannelTo(observer, string1) = [defaults rac_channelTerminalForKey:stringKey];
	RACChannelTo(observer, string2) = [defaults rac_channelTerminalForKey:stringKey];
	
	[defaults setObject:@"String 3" forKey:stringKey];
	
	expect(observer.string1).to(equal(@"String 3"));
	expect(observer.string2).to(equal(@"String 3"));
});

qck_it(@"should handle removed defaults", ^{
	observer.string1 = @"Some string";
	observer.bool1 = YES;
	
	RACChannelTo(observer, string1) = [defaults rac_channelTerminalForKey:stringKey];
	RACChannelTo(observer, bool1, @NO) = [defaults rac_channelTerminalForKey:boolKey];
	
	[defaults removeObjectForKey:stringKey];
	[defaults removeObjectForKey:boolKey];
	
	expect(observer.string1).to(beNil());
	expect(@(observer.bool1)).to(equal(@NO));
});

qck_it(@"shouldn't resend values", ^{
	RACChannelTerminal *terminal = [defaults rac_channelTerminalForKey:stringKey];
	
	RACChannelTo(observer, string1) = terminal;
	
	RACSignal *sentValue = [terminal replayLast];
	observer.string1 = @"Test value";
	id value = [sentValue asynchronousFirstOrDefault:nil success:NULL error:NULL];
	expect(value).to(beNil());
});

qck_it(@"should complete when the NSUserDefaults deallocates", ^{
	__block RACChannelTerminal *terminal;
	__block BOOL deallocated = NO;
	
	@autoreleasepool {
		NSUserDefaults *customDefaults __attribute__((objc_precise_lifetime)) = [NSUserDefaults new];
		[customDefaults.rac_deallocDisposable addDisposable:[RACDisposable disposableWithBlock:^{
			deallocated = YES;
		}]];
		
		terminal = [customDefaults rac_channelTerminalForKey:stringKey];
	}
	
	expect(@(deallocated)).to(beTruthy());
	expect(@([terminal asynchronouslyWaitUntilCompleted:NULL])).to(beTruthy());
});

qck_it(@"should send an initial value", ^{
	[defaults setObject:@"Initial" forKey:stringKey];
	RACChannelTerminal *terminal = [defaults rac_channelTerminalForKey:stringKey];
	expect([terminal asynchronousFirstOrDefault:nil success:NULL error:NULL]).to(equal(@"Initial"));
});

QuickSpecEnd
