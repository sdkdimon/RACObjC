//
//  RACSmokeTests.m
//  RACObjC
//
//  GNUstep smoke tests: exercises the parts of RACObjC that depend on the
//  Objective-C runtime, libdispatch, KVO and the CoreFoundation shims.
//  The real test suite (Quick/Nimble) is Apple-only.
//
//  Run from Core/RACObjC with:  gmake check
//

#import <Foundation/Foundation.h>
#import <RACObjC/RACObjC.h>
#import <objc/runtime.h>

static NSUInteger RSTPassed = 0;
static NSUInteger RSTFailed = 0;

#define CHECK(cond, name) do { \
	if (cond) { RSTPassed++; printf("  ok    %s\n", name); } \
	else { RSTFailed++; printf("  FAIL  %s  (%s:%d)\n", name, __FILE__, __LINE__); } \
} while (0)

// Spins the current run loop (which also drains the main dispatch queue on
// GNUstep) until the condition holds or the timeout expires.
static BOOL RSTWaitUntil(NSTimeInterval timeout, BOOL (^condition)(void)) {
	NSDate *deadline = [NSDate dateWithTimeIntervalSinceNow:timeout];
	while (!condition()) {
		if (deadline.timeIntervalSinceNow < 0) return NO;
		[[NSRunLoop currentRunLoop] runUntilDate:[NSDate dateWithTimeIntervalSinceNow:0.01]];
	}
	return YES;
}

#pragma mark - Test fixtures

@protocol RSTDelegate <NSObject>
@optional
- (void)thing:(id)thing didChangeValue:(NSInteger)value;
@end

@interface RSTPerson : NSObject <RSTDelegate>
@property (nonatomic, copy) NSString *name;
@property (nonatomic, assign) NSInteger age;
@property (nonatomic, copy) NSString *combined;
- (NSInteger)addInt:(NSInteger)a toInt:(NSInteger)b;
- (double)scaleDouble:(double)x by:(double)y;
- (NSString *)greet:(NSString *)name times:(NSInteger)times;
- (NSInteger)sum:(NSInteger)a :(NSInteger)b :(NSInteger)c :(NSInteger)d :(NSInteger)e :(NSInteger)f :(NSInteger)g :(NSInteger)h :(NSInteger)i :(NSInteger)j;
- (void)setFirst:(NSString *)first last:(NSString *)last;
@end

@implementation RSTPerson
- (NSInteger)addInt:(NSInteger)a toInt:(NSInteger)b { return a + b; }
- (double)scaleDouble:(double)x by:(double)y { return x * y; }
- (NSString *)greet:(NSString *)name times:(NSInteger)times {
	NSMutableString *s = [NSMutableString string];
	for (NSInteger i = 0; i < times; i++) [s appendFormat:@"hi %@;", name];
	return s;
}
- (NSInteger)sum:(NSInteger)a :(NSInteger)b :(NSInteger)c :(NSInteger)d :(NSInteger)e :(NSInteger)f :(NSInteger)g :(NSInteger)h :(NSInteger)i :(NSInteger)j {
	return a + b + c + d + e + f + g + h + i + j;
}
- (void)setFirst:(NSString *)first last:(NSString *)last {
	self.combined = [NSString stringWithFormat:@"%@ %@", first, last];
}
@end

static BOOL RSTTrackerDeallocRan = NO;
static volatile BOOL RSTThreadExited = NO;

// Implements -dealloc itself, so RAC has to wrap an existing implementation.
@interface RSTDeallocTracker : NSObject
@end

@implementation RSTDeallocTracker
- (void)dealloc {
	RSTTrackerDeallocRan = YES;
}
@end

#pragma mark - Tests

@interface RSTSuite : NSObject
@end

@implementation RSTSuite

- (void)testSignalBasics {
	puts("signals");

	NSArray *mapped = [[[[RACSignal return:@1] concat:[RACSignal return:@2]] map:^(NSNumber *x) {
		return @(x.integerValue * 10);
	}] toArray];
	CHECK([mapped isEqual:(@[ @10, @20 ])], "return/concat/map/toArray");

	RACSignal *numbers = [@[ @1, @2, @3, @4, @5, @6 ].rac_sequence signal];
	NSArray *evens = [[[numbers filter:^BOOL(NSNumber *x) { return x.integerValue % 2 == 0; }] take:2] toArray];
	CHECK([evens isEqual:(@[ @2, @4 ])], "filter/take");

	NSArray *flat = [[numbers flattenMap:^(NSNumber *x) {
		return x.integerValue <= 2 ? [RACSignal return:x] : [RACSignal empty];
	}] toArray];
	CHECK([flat isEqual:(@[ @1, @2 ])], "flattenMap");

	RACSubject *a = [RACSubject subject];
	RACSubject *b = [RACSubject subject];
	NSMutableArray *combined = [NSMutableArray array];
	[[RACSignal combineLatest:@[ a, b ] reduce:^(NSString *x, NSString *y) {
		return [x stringByAppendingString:y];
	}] subscribeNext:^(NSString *x) {
		[combined addObject:x];
	}];
	[a sendNext:@"a"];
	[b sendNext:@"1"];
	[a sendNext:@"b"];
	CHECK([combined isEqual:(@[ @"a1", @"b1" ])], "combineLatest:reduce: (block trampoline)");

	NSArray *zipped = [[[RACSignal zip:@[ [@[ @1, @2 ].rac_sequence signal], [@[ @"x", @"y" ].rac_sequence signal] ]] reduceEach:^(NSNumber *n, NSString *s) {
		return [NSString stringWithFormat:@"%@%@", n, s];
	}] toArray];
	CHECK([zipped isEqual:(@[ @"1x", @"2y" ])], "zip/reduceEach");

	RACTupleUnpack(NSString *str, NSNumber *num) = RACTuplePack(@"s", @7);
	CHECK([str isEqual:@"s"] && num.integerValue == 7, "RACTuplePack/RACTupleUnpack");

	__block NSError *timeoutError = nil;
	[[[RACSignal never] timeout:0.05 onScheduler:[RACScheduler scheduler]] subscribeError:^(NSError *error) {
		timeoutError = error;
	}];
	RSTWaitUntil(2, ^{ return (BOOL)(timeoutError != nil); });
	CHECK([timeoutError.domain isEqual:RACSignalErrorDomain] && timeoutError.code == RACSignalErrorTimedOut, "timeout error (NS_ERROR_ENUM)");
}

- (void)testSubjects {
	puts("subjects");

	RACBehaviorSubject *behavior = [RACBehaviorSubject behaviorSubjectWithDefaultValue:@"start"];
	__block id first = nil;
	[behavior subscribeNext:^(id x) { if (first == nil) first = x; }];
	CHECK([first isEqual:@"start"], "RACBehaviorSubject default value");

	RACReplaySubject *replay = [RACReplaySubject replaySubjectWithCapacity:2];
	[replay sendNext:@1];
	[replay sendNext:@2];
	[replay sendNext:@3];
	[replay sendCompleted];
	CHECK([[replay toArray] isEqual:(@[ @2, @3 ])], "RACReplaySubject capacity");
}

- (void)testSequences {
	puts("sequences");

	RACSequence *seq = [@[ @1, @2, @3 ].rac_sequence map:^(NSNumber *x) { return @(x.integerValue * x.integerValue); }];
	CHECK([seq.array isEqual:(@[ @1, @4, @9 ])], "array sequence map");

	NSNumber *sum = [@[ @1, @2, @3, @4 ].rac_sequence foldLeftWithStart:@0 reduce:^(NSNumber *acc, NSNumber *x) {
		return @(acc.integerValue + x.integerValue);
	}];
	CHECK(sum.integerValue == 10, "foldLeft");

	CHECK([@"abc".rac_sequence.array isEqual:(@[ @"a", @"b", @"c" ])], "string sequence");

	// Fast enumeration over a lazy sequence (uses CFBridgingRetain/Release).
	RACSequence *lazy = [RACSequence sequenceWithHeadBlock:^{ return @0; } tailBlock:^RACSequence *{
		return [@[ @1, @2, @3, @4, @5, @6, @7, @8, @9, @10, @11, @12, @13, @14, @15, @16, @17, @18, @19 ].rac_sequence map:^(id x) { return x; }];
	}];
	NSInteger count = 0, total = 0;
	for (NSNumber *x in lazy) {
		count++;
		total += x.integerValue;
	}
	CHECK(count == 20 && total == 190, "fast enumeration over dynamic sequence");

	NSDictionary *dict = @{ @"k1": @1, @"k2": @2 };
	NSArray *keys = [dict.rac_keySequence.array sortedArrayUsingSelector:@selector(compare:)];
	CHECK([keys isEqual:(@[ @"k1", @"k2" ])], "dictionary key sequence");
}

- (void)testDisposables {
	puts("disposables");

	__block NSInteger disposed = 0;
	NSMutableArray *disposables = [NSMutableArray array];
	for (int i = 0; i < 10; i++) {
		[disposables addObject:[RACDisposable disposableWithBlock:^{ disposed++; }]];
	}

	// More than the 2 inline slots: exercises the CFArray shim.
	RACCompoundDisposable *compound = [RACCompoundDisposable compoundDisposable];
	for (RACDisposable *d in disposables) [compound addDisposable:d];
	[compound removeDisposable:disposables[5]];
	[compound dispose];
	CHECK(disposed == 9 && compound.disposed, "compound add/remove/dispose");

	__block NSInteger disposed2 = 0;
	NSMutableArray *initial = [NSMutableArray array];
	for (int i = 0; i < 5; i++) [initial addObject:[RACDisposable disposableWithBlock:^{ disposed2++; }]];
	[[RACCompoundDisposable compoundDisposableWithDisposables:initial] dispose];
	CHECK(disposed2 == 5, "compoundDisposableWithDisposables (CFArrayAppendArray)");

	__block BOOL serialDisposed = NO;
	RACSerialDisposable *serial = [RACSerialDisposable serialDisposableWithDisposable:[RACDisposable disposableWithBlock:^{ serialDisposed = YES; }]];
	[serial dispose];
	CHECK(serialDisposed, "serial disposable");
}

- (void)testSchedulers {
	puts("schedulers");

	__block BOOL ranOnBackground = NO;
	__block BOOL deliveredOnMain = NO;
	[[[[RACSignal return:@1] subscribeOn:[RACScheduler scheduler]] doNext:^(id x) {
		ranOnBackground = !NSThread.isMainThread;
	}] subscribeNext:^(id x) {}];
	[[[[RACSignal return:@1] subscribeOn:[RACScheduler scheduler]] deliverOn:RACScheduler.mainThreadScheduler] subscribeNext:^(id x) {
		deliveredOnMain = NSThread.isMainThread;
	}];
	BOOL mainArrived = RSTWaitUntil(3, ^{ return deliveredOnMain; });
	CHECK(ranOnBackground, "subscribeOn background scheduler");
	CHECK(mainArrived, "deliverOn mainThreadScheduler (main queue drained by run loop)");

	NSArray *ticks = [[[RACSignal interval:0.02 onScheduler:[RACScheduler scheduler]] take:3] toArray];
	CHECK(ticks.count == 3, "interval (dispatch timer) + toArray");

	__block BOOL afterRan = NO;
	[[RACScheduler scheduler] afterDelay:0.05 schedule:^{ afterRan = YES; }];
	CHECK(RSTWaitUntil(2, ^{ return afterRan; }), "afterDelay:schedule:");

	__block RACScheduler *seen = nil;
	RACScheduler *bg = [RACScheduler schedulerWithPriority:RACSchedulerPriorityDefault name:@"rst.bg"];
	[bg schedule:^{ seen = RACScheduler.currentScheduler; }];
	CHECK(RSTWaitUntil(2, ^{ return (BOOL)(seen != nil); }) && seen == bg, "currentScheduler");

	// RACTestScheduler orders actions with the CFBinaryHeap shim.
	RACTestScheduler *test = [[RACTestScheduler alloc] init];
	NSMutableArray *order = [NSMutableArray array];
	[test after:[NSDate dateWithTimeIntervalSinceReferenceDate:100] schedule:^{ [order addObject:@"d"]; }];
	[test schedule:^{ [order addObject:@"a"]; }];
	[test schedule:^{ [order addObject:@"b"]; }];
	[test after:[NSDate dateWithTimeIntervalSinceReferenceDate:50] schedule:^{ [order addObject:@"c"]; }];
	[test step];
	BOOL firstOnly = [order isEqual:(@[ @"a" ])];
	[test stepAll];
	CHECK(firstOnly && [order isEqual:(@[ @"a", @"b", @"c", @"d" ])], "RACTestScheduler ordering");
}

- (void)testKVO {
	puts("kvo");

	RSTPerson *person = [RSTPerson new];
	person.name = @"a";
	NSMutableArray *names = [NSMutableArray array];
	[RACObserve(person, name) subscribeNext:^(NSString *x) { [names addObject:x ?: (id)NSNull.null]; }];
	person.name = @"b";
	person.name = @"c";
	CHECK([names isEqual:(@[ @"a", @"b", @"c" ])], "RACObserve");

	RAC(person, combined) = [RACSignal combineLatest:@[ RACObserve(person, name), RACObserve(person, age) ] reduce:^(NSString *name, NSNumber *age) {
		return [NSString stringWithFormat:@"%@-%@", name, age];
	}];
	person.age = 30;
	CHECK([person.combined isEqual:@"c-30"], "RAC() binding");

	RSTPerson *left = [RSTPerson new];
	RSTPerson *right = [RSTPerson new];
	RACChannelTo(left, name) = RACChannelTo(right, name);
	left.name = @"from-left";
	BOOL leftToRight = [right.name isEqual:@"from-left"];
	right.name = @"from-right";
	CHECK(leftToRight && [left.name isEqual:@"from-right"], "RACChannelTo two-way binding");
}

- (void)testSelectorSignals {
	puts("rac_signalForSelector (forwarding trampoline)");

	RSTPerson *person = [RSTPerson new];
	NSMutableArray *calls = [NSMutableArray array];
	[[person rac_signalForSelector:@selector(addInt:toInt:)] subscribeNext:^(RACTuple *args) { [calls addObject:args]; }];
	NSInteger result = [person addInt:2 toInt:40];
	CHECK(result == 42, "integer args/return pass through");
	CHECK(calls.count == 1 && [calls[0] isEqual:RACTuplePack(@2, @40)], "integer args delivered");

	__block RACTuple *doubleArgs = nil;
	[[person rac_signalForSelector:@selector(scaleDouble:by:)] subscribeNext:^(RACTuple *args) { doubleArgs = args; }];
	double scaled = [person scaleDouble:1.5 by:4.0];
	CHECK(scaled == 6.0 && [doubleArgs.first doubleValue] == 1.5 && [doubleArgs.second doubleValue] == 4.0, "double args/return (FP registers)");

	__block RACTuple *objectArgs = nil;
	[[person rac_signalForSelector:@selector(greet:times:)] subscribeNext:^(RACTuple *args) { objectArgs = args; }];
	NSString *greeting = [person greet:@"bob" times:2];
	CHECK([greeting isEqual:@"hi bob;hi bob;"] && [objectArgs.first isEqual:@"bob"], "object args/return");

	__block RACTuple *manyArgs = nil;
	[[person rac_signalForSelector:@selector(sum::::::::::)] subscribeNext:^(RACTuple *args) { manyArgs = args; }];
	NSInteger total = [person sum:1 :2 :3 :4 :5 :6 :7 :8 :9 :10];
	CHECK(total == 55 && [manyArgs[9] integerValue] == 10, "10 args (stack arguments preserved)");

	CHECK([person class] == [RSTPerson class] && [person isKindOfClass:[RSTPerson class]], "isa-swizzled object still reports its class");

	__block RACTuple *undefinedArgs = nil;
	SEL undefinedSelector = NSSelectorFromString(@"didTapThing:");
	[[person rac_signalForSelector:undefinedSelector] subscribeNext:^(RACTuple *args) { undefinedArgs = args; }];
	CHECK([person respondsToSelector:undefinedSelector], "respondsToSelector: for added method");
#pragma clang diagnostic push
#pragma clang diagnostic ignored "-Warc-performSelector-leaks"
	[person performSelector:undefinedSelector withObject:@"tap"];
#pragma clang diagnostic pop
	CHECK([undefinedArgs.first isEqual:@"tap"], "previously undefined selector");

	RSTPerson *delegateTarget = [RSTPerson new];
	__block RACTuple *protocolArgs = nil;
	[[delegateTarget rac_signalForSelector:@selector(thing:didChangeValue:) fromProtocol:@protocol(RSTDelegate)] subscribeNext:^(RACTuple *args) { protocolArgs = args; }];
	[(id<RSTDelegate>)delegateTarget thing:@"t" didChangeValue:99];
	CHECK([protocolArgs.second integerValue] == 99, "fromProtocol: optional method");

	__block NSString *lifted = nil;
	RSTPerson *liftTarget = [RSTPerson new];
	[liftTarget rac_liftSelector:@selector(setFirst:last:) withSignals:[RACSignal return:@"Ada"], [RACSignal return:@"Lovelace"], nil];
	lifted = liftTarget.combined;
	CHECK([lifted isEqual:@"Ada Lovelace"], "rac_liftSelector:withSignals:");
}

// libobjc2 hands out only 128 (aarch64) or 256 (x86_64) block IMPs, so
// swizzling with them would crash here; RACObjC uses plain functions on
// GNUstep (GNUstep/RACSwizzleTable.h).
- (void)testManySwizzledClasses {
	puts("many swizzled classes");

	const NSUInteger count = 300;
	__block NSUInteger deallocated = 0;
	__block NSUInteger forwarded = 0;
	NSUInteger returned = 0;
	for (NSUInteger i = 0; i < count; i++) {
		@autoreleasepool {
			NSString *name = [NSString stringWithFormat:@"RSTGeneratedPerson%lu", (unsigned long)i];
			Class cls = objc_allocateClassPair(RSTPerson.class, name.UTF8String, 0);
			objc_registerClassPair(cls);

			// Separate objects: one with -rac_signalForSelector: on a class
			// made at runtime isn't deallocated on GNUstep, with block IMPs
			// too (not investigated yet).
			RSTPerson *person = [cls new];
			[person.rac_willDeallocSignal subscribeCompleted:^{ deallocated++; }];

			RSTPerson *signalPerson = [cls new];
			[[signalPerson rac_signalForSelector:@selector(addInt:toInt:)] subscribeNext:^(RACTuple *args) { forwarded++; }];
			if ([signalPerson addInt:2 toInt:3] == 5 && signalPerson.class == cls) returned++;
		}
	}
	CHECK(deallocated == count, "rac_willDeallocSignal on 300 classes");
	CHECK(forwarded == count && returned == count, "rac_signalForSelector: on 300 classes");

	// A subclass and its superclass both swizzled: the subclass's -dealloc
	// has to reach the superclass's swizzled -dealloc, and that one the
	// superclass's own -dealloc.
	Class subclass = objc_allocateClassPair(RSTDeallocTracker.class, "RSTGeneratedTrackerSubclass", 0);
	objc_registerClassPair(subclass);
	@autoreleasepool {
		[[RSTDeallocTracker new] rac_willDeallocSignal];
	}
	__block BOOL subclassCompleted = NO;
	RSTTrackerDeallocRan = NO;
	@autoreleasepool {
		id tracker = [subclass new];
		[[tracker rac_willDeallocSignal] subscribeCompleted:^{ subclassCompleted = YES; }];
	}
	CHECK(subclassCompleted && RSTTrackerDeallocRan, "swizzled -dealloc on a subclass of a swizzled class");

	// On a plain NSObject, this swizzles NSObject's own -dealloc, which every
	// object then goes through, including the autorelease pools a thread
	// frees when it exits (NSAutoreleasePool raises if it's retained).
	__block BOOL objectCompleted = NO;
	@autoreleasepool {
		NSObject *object = [NSObject new];
		[object.rac_willDeallocSignal subscribeCompleted:^{ objectCompleted = YES; }];
	}
	RSTThreadExited = NO;
	[NSThread detachNewThreadSelector:@selector(runShortThread) toTarget:self withObject:nil];
	BOOL threadExited = RSTWaitUntil(5, ^{ return RSTThreadExited; });
	[NSThread sleepForTimeInterval:0.2];
	CHECK(objectCompleted && threadExited, "swizzled -[NSObject dealloc], then a thread exits");
}

- (void)runShortThread {
	@autoreleasepool {
		(void)[[NSObject new] description];
	}
	RSTThreadExited = YES;
}

- (void)testDeallocation {
	puts("deallocation");

	__block BOOL completed = NO;
	@autoreleasepool {
		RSTPerson *person = [RSTPerson new];
		[person.rac_willDeallocSignal subscribeCompleted:^{ completed = YES; }];
	}
	CHECK(completed, "rac_willDeallocSignal (inherited -dealloc, super call)");

	__block BOOL trackerCompleted = NO;
	RSTTrackerDeallocRan = NO;
	@autoreleasepool {
		RSTDeallocTracker *tracker = [RSTDeallocTracker new];
		[tracker.rac_willDeallocSignal subscribeCompleted:^{ trackerCompleted = YES; }];
	}
	CHECK(trackerCompleted && RSTTrackerDeallocRan, "rac_willDeallocSignal (own -dealloc still runs)");

	__block BOOL swizzledCompleted = NO;
	@autoreleasepool {
		RSTPerson *person = [RSTPerson new];
		[[person rac_signalForSelector:@selector(addInt:toInt:)] subscribeCompleted:^{ swizzledCompleted = YES; }];
		[person addInt:1 toInt:1];
	}
	CHECK(swizzledCompleted, "selector signal completes on dealloc");

	__block BOOL strongWasNil = NO;
	void (^block)(void);
	@autoreleasepool {
		RSTPerson *temporary = [RSTPerson new];
		@weakify(temporary);
		block = ^{
			@strongify(temporary);
			strongWasNil = (temporary == nil);
		};
	}
	block();
	CHECK(strongWasNil, "@weakify/@strongify");
}

- (void)testCommandsAndFoundation {
	puts("commands & foundation");

	RACCommand *command = [[RACCommand alloc] initWithSignalBlock:^(NSNumber *input) {
		return [RACSignal return:@(input.integerValue * 2)];
	}];
	__block id commandResult = nil;
	[[command execute:@21] subscribeNext:^(id x) { commandResult = x; }];
	CHECK(RSTWaitUntil(3, ^{ return (BOOL)(commandResult != nil); }) && [commandResult isEqual:@42], "RACCommand execute:");

	NSMutableArray *notes = [NSMutableArray array];
	RACDisposable *noteSub = [[[NSNotificationCenter defaultCenter] rac_addObserverForName:@"RSTNote" object:nil] subscribeNext:^(NSNotification *n) {
		[notes addObject:n.object];
	}];
	[[NSNotificationCenter defaultCenter] postNotificationName:@"RSTNote" object:@"one"];
	[noteSub dispose];
	[[NSNotificationCenter defaultCenter] postNotificationName:@"RSTNote" object:@"two"];
	CHECK([notes isEqual:(@[ @"one" ])], "NSNotificationCenter signal + dispose");

	NSString *path = [NSTemporaryDirectory() stringByAppendingPathComponent:@"rac-smoke.txt"];
	[@"payload" writeToFile:path atomically:YES encoding:NSUTF8StringEncoding error:NULL];
	NSData *read = [[NSData rac_readContentsOfURL:[NSURL fileURLWithPath:path] options:0 scheduler:[RACScheduler immediateScheduler]] first];
	CHECK([[[NSString alloc] initWithData:read encoding:NSUTF8StringEncoding] isEqual:@"payload"], "NSData rac_readContentsOfURL");

	__block NSError *readError = nil;
	[[NSData rac_readContentsOfURL:[NSURL fileURLWithPath:@"/nonexistent/rac"] options:0 scheduler:[RACScheduler immediateScheduler]] subscribeError:^(NSError *e) { readError = e; }];
	CHECK(readError != nil, "NSData rac_readContentsOfURL missing file -> error");
}

- (void)run {
	SEL tests[] = {
		@selector(testSignalBasics), @selector(testSubjects), @selector(testSequences),
		@selector(testDisposables), @selector(testSchedulers), @selector(testKVO),
		@selector(testSelectorSignals), @selector(testDeallocation), @selector(testManySwizzledClasses),
		@selector(testCommandsAndFoundation),
	};
	for (size_t i = 0; i < sizeof(tests) / sizeof(tests[0]); i++) {
		@try {
			@autoreleasepool {
				((void (*)(id, SEL))[self methodForSelector:tests[i]])(self, tests[i]);
			}
		} @catch (NSException *exception) {
			RSTFailed++;
			printf("  FAIL  %s threw %s: %s\n", sel_getName(tests[i]), exception.name.UTF8String, exception.reason.UTF8String);
		}
	}
}

@end

int main(int argc, const char *argv[]) {
	@autoreleasepool {
		[[RSTSuite new] run];
		printf("\n%lu passed, %lu failed\n", (unsigned long)RSTPassed, (unsigned long)RSTFailed);
	}
	return RSTFailed == 0 ? 0 : 1;
}
