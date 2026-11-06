//
//  RACSignalKVOSpec.m
//  ReactiveObjC
//
//  Created by Josh Abernathy on 3/2/12.
//  Copyright (c) 2012 GitHub, Inc. All rights reserved.
//
//  The RACObserve() and -setKeyPath:onObject: parts of RACSignalSpec, which
//  belong to the KVO module.
//

@import Quick;
@import Nimble;

#import "RACPropertySignalExamples.h"
#import "RACTestObject.h"

#import "EXTKeyPathCoding.h"
#import "NSObject+RACDeallocating.h"
#import "NSObject+RACPropertySubscribing.h"
#import "RACCompoundDisposable.h"
#import "RACDisposable.h"
#import "RACScheduler.h"
#import "RACSignal+Operations.h"
#import "RACSignal+RACKeyPathBinding.h"
#import "RACSubject.h"

// Quick 7 runs specs in +spec, so self, passed as the observer (e.g. by RACObserve()), is the spec class.
#pragma clang diagnostic ignored "-Wincompatible-pointer-types"

QuickSpecBegin(RACSignalKVOSpec)

qck_describe(@"RACObserve", ^{
	__block RACTestObject *testObject;

	qck_beforeEach(^{
		testObject = [[RACTestObject alloc] init];
	});

	qck_it(@"should work with object properties", ^{
		NSArray *expected = @[ @"hello", @"world" ];
		testObject.objectValue = expected[0];

		NSMutableArray *valuesReceived = [NSMutableArray array];
		[RACObserve(testObject, objectValue) subscribeNext:^(id x) {
			[valuesReceived addObject:x];
		}];

		testObject.objectValue = expected[1];

		expect(valuesReceived).to(equal(expected));
	});

	qck_it(@"should work with non-object properties", ^{
		NSArray *expected = @[ @42, @43 ];
		testObject.integerValue = [expected[0] integerValue];

		NSMutableArray *valuesReceived = [NSMutableArray array];
		[RACObserve(testObject, integerValue) subscribeNext:^(id x) {
			[valuesReceived addObject:x];
		}];

		testObject.integerValue = [expected[1] integerValue];

		expect(valuesReceived).to(equal(expected));
	});

	qck_it(@"should read the initial value upon subscription", ^{
		testObject.objectValue = @"foo";

		RACSignal *signal = RACObserve(testObject, objectValue);
		testObject.objectValue = @"bar";

		expect([signal first]).to(equal(@"bar"));
	});
});

qck_describe(@"-setKeyPath:onObject:", ^{
	id setupBlock = ^(RACTestObject *testObject, NSString *keyPath, id nilValue, RACSignal *signal) {
		[signal setKeyPath:keyPath onObject:testObject nilValue:nilValue];
	};

	qck_itBehavesLike(RACPropertySignalExamples, ^{
		return @{ RACPropertySignalExamplesSetupBlock: setupBlock };
	});

	qck_it(@"shouldn't send values to dealloc'd objects", ^{
		RACSubject *subject = [RACSubject subject];
		@autoreleasepool {
			RACTestObject *testObject __attribute__((objc_precise_lifetime)) = [[RACTestObject alloc] init];
			[subject setKeyPath:@keypath(testObject.objectValue) onObject:testObject];
			expect(testObject.objectValue).to(beNil());

			[subject sendNext:@1];
			expect(testObject.objectValue).to(equal(@1));

			[subject sendNext:@2];
			expect(testObject.objectValue).to(equal(@2));
		}

		// This shouldn't do anything.
		[subject sendNext:@3];
	});

	qck_it(@"should allow a new derivation after the signal's completed", ^{
		RACSubject *subject1 = [RACSubject subject];
		RACTestObject *testObject = [[RACTestObject alloc] init];
		[subject1 setKeyPath:@keypath(testObject.objectValue) onObject:testObject];
		[subject1 sendCompleted];

		RACSubject *subject2 = [RACSubject subject];
		// This will assert if the previous completion didn't dispose of the
		// subscription.
		[subject2 setKeyPath:@keypath(testObject.objectValue) onObject:testObject];
	});

	qck_it(@"should set the given value when nil is received", ^{
		RACSubject *subject = [RACSubject subject];
		RACTestObject *testObject = [[RACTestObject alloc] init];
		[subject setKeyPath:@keypath(testObject.integerValue) onObject:testObject nilValue:@5];

		[subject sendNext:@1];
		expect(@(testObject.integerValue)).to(equal(@1));

		[subject sendNext:nil];
		expect(@(testObject.integerValue)).to(equal(@5));

		[subject sendCompleted];
		expect(@(testObject.integerValue)).to(equal(@5));
	});

	qck_it(@"should keep object alive over -sendNext:", ^{
		RACSubject *subject = [RACSubject subject];
		__block RACTestObject *testObject = [[RACTestObject alloc] init];
		__block id deallocValue;

		__unsafe_unretained RACTestObject *unsafeTestObject = testObject;
		[testObject.rac_deallocDisposable addDisposable:[RACDisposable disposableWithBlock:^{
			deallocValue = unsafeTestObject.hookedObjectValue;
		}]];

		[subject setKeyPath:@keypath(testObject.hookedObjectValue) onObject:testObject];
		expect(testObject.hookedObjectValue).to(beNil());

		// Inside the setter, release the last outside reference on another
		// thread, so only the binding's own reference is left while it sets the
		// value.
		testObject.willSetHookedObjectValue = ^{
			dispatch_semaphore_t released = dispatch_semaphore_create(0);
			[[RACScheduler scheduler] schedule:^{
				testObject = nil;
				dispatch_semaphore_signal(released);
			}];
			dispatch_semaphore_wait(released, DISPATCH_TIME_FOREVER);
		};

		expect(deallocValue).to(beNil());
		[subject sendNext:@1];
		expect(deallocValue).to(equal(@1));
	});
});

QuickSpecEnd
