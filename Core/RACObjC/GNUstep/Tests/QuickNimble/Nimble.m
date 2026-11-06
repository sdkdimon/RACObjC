//
//  Nimble.m
//  RACObjC
//
//  GNUstep only. See Nimble/Nimble.h.
//
//  Each matcher returns a status like Nimble's PredicateStatus: matches,
//  doesNotMatch, or fail. "fail" (e.g. equal() with a nil actual value)
//  fails both to() and toNot(). Messages follow Nimble's format:
//  "expected to equal <1>, got <nil> (use beNil() to match nils)".
//

#import <Nimble/Nimble.h>
#import <Quick/Quick.h>
#import <objc/runtime.h>
#include <math.h>

typedef NS_ENUM(NSInteger, NMBStatus) {
	NMBStatusMatches,
	NMBStatusDoesNotMatch,
	NMBStatusFail,
};

@interface NMBResult : NSObject

@property (nonatomic, assign) NMBStatus status;
// What was expected, e.g. "equal <1>".
@property (nonatomic, copy) NSString *expected;
// Overrides the default "<actual>" description.
@property (nonatomic, copy, nullable) NSString *actual;
@property (nonatomic, assign) BOOL beNilHint;

@end

@implementation NMBResult
@end

static NSString *NMBStringify(id value) {
	if (value == nil) return @"nil";
	if ([value isKindOfClass:NSString.class]) return value;
	return [value description];
}

static NMBResult *NMBMakeResult(NMBStatus status, NSString *expected) {
	NMBResult *result = [[NMBResult alloc] init];
	result.status = status;
	result.expected = expected;
	return result;
}

static NMBResult *NMBMakeBoolResult(BOOL matches, NSString *expected) {
	return NMBMakeResult(matches ? NMBStatusMatches : NMBStatusDoesNotMatch, expected);
}

typedef NMBResult *_Nonnull (^NMBPredicateBlock)(id _Nullable actual);

@interface NMBPredicate ()

@property (nonatomic, copy) NMBPredicateBlock block;

- (instancetype)initWithBlock:(NMBPredicateBlock)block;

@end

@implementation NMBPredicate

- (instancetype)initWithBlock:(NMBPredicateBlock)block {
	if ((self = [super init])) {
		_block = [block copy];
	}
	return self;
}

@end

@interface NMBObjCBeCloseToPredicate ()

@property (nonatomic, strong) NSNumber *expectedValue;
@property (nonatomic, assign) double delta;

@end

@implementation NMBObjCBeCloseToPredicate

- (instancetype)initWithExpectedValue:(NSNumber *)expectedValue delta:(double)delta {
	self = [super initWithBlock:^(id actual) {
		NSString *expected = [NSString stringWithFormat:@"be close to <%@> (within %@)", NMBStringify(expectedValue), @(delta)];
		if (![actual isKindOfClass:NSNumber.class] || expectedValue == nil) return NMBMakeResult(NMBStatusFail, expected);
		return NMBMakeBoolResult(fabs([actual doubleValue] - expectedValue.doubleValue) < delta, expected);
	}];
	if (self != nil) {
		_expectedValue = expectedValue;
		_delta = delta;
	}
	return self;
}

- (NMBObjCBeCloseToPredicate *(^)(double))within {
	return ^(double delta) {
		return [[NMBObjCBeCloseToPredicate alloc] initWithExpectedValue:self.expectedValue delta:delta];
	};
}

@end

static void NMBRecordFailure(NSString *message, NSString *file, NSUInteger line) {
	QuickSpec *spec = QuickSpec.current;
	if (spec == nil) {
		[NSException raise:NSInternalInconsistencyException format:@"%@:%lu: %@ (no example is running)", file, (unsigned long)line, message];
	}
	[spec recordFailureWithDescription:message inFile:file atLine:line expected:YES];
}

@interface NMBExpectation ()

@property (nonatomic, copy) id _Nullable (^actualBlock)(void);
@property (nonatomic, copy) NSString *file;
@property (nonatomic, assign) NSUInteger line;
@property (nonatomic, assign) NSTimeInterval timeout;

@end

@implementation NMBExpectation

- (instancetype)initWithActualBlock:(id (^)(void))actualBlock file:(NSString *)file line:(NSUInteger)line {
	if ((self = [super init])) {
		_actualBlock = [actualBlock copy];
		_file = [file copy];
		_line = line;
		_timeout = 1;
	}
	return self;
}

+ (void)failWithMessage:(NSString *)message file:(NSString *)file line:(NSUInteger)line {
	NMBRecordFailure(message, file, line);
}

// "expected to [eventually ][not ]<expected>, got <actual>[ hint][: description]"
- (void)failWithResult:(NMBResult *)result actual:(id)actual negative:(BOOL)negative eventually:(BOOL)eventually description:(NSString *)description {
	NSMutableString *message = [NSMutableString string];
	if (description.length > 0) [message appendFormat:@"%@\n", description];
	[message appendFormat:@"expected to %@%@%@, got <%@>", eventually ? @"eventually " : @"", negative ? @"not " : @"", result.expected, result.actual ?: NMBStringify(actual)];
	if (result.beNilHint && actual == nil) [message appendString:@" (use beNil() to match nils)"];
	NMBRecordFailure(message, self.file, self.line);
}

static BOOL NMBSatisfied(NMBResult *result, BOOL negative) {
	return result.status == (negative ? NMBStatusDoesNotMatch : NMBStatusMatches);
}

- (void)verify:(NMBPredicate *)predicate negative:(BOOL)negative description:(NSString *)description {
	id actual = self.actualBlock();
	NMBResult *result = predicate.block(actual);
	if (!NMBSatisfied(result, negative)) {
		[self failWithResult:result actual:actual negative:negative eventually:NO description:description];
	}
}

// Like Nimble: evaluate, and while it doesn't match, run the current run loop
// for 10 ms at a time until the timeout (1 second unless withTimeout).
- (void)verifyEventually:(NMBPredicate *)predicate negative:(BOOL)negative description:(NSString *)description {
	NSDate *deadline = [NSDate dateWithTimeIntervalSinceNow:self.timeout];
	while (YES) {
		id actual;
		NMBResult *result;
		@autoreleasepool {
			actual = self.actualBlock();
			result = predicate.block(actual);
		}
		if (NMBSatisfied(result, negative)) return;

		if (deadline.timeIntervalSinceNow <= 0) {
			[self failWithResult:result actual:actual negative:negative eventually:YES description:description];
			return;
		}

		NSDate *slice = [NSDate dateWithTimeIntervalSinceNow:MIN(0.01, MAX(0, deadline.timeIntervalSinceNow))];
		if (![NSRunLoop.currentRunLoop runMode:NSDefaultRunLoopMode beforeDate:slice]) {
			[NSThread sleepUntilDate:slice];
		}
	}
}

- (NMBExpectation *(^)(NSTimeInterval))withTimeout {
	return ^(NSTimeInterval timeout) {
		self.timeout = timeout;
		return self;
	};
}

- (NMBExpectation *(^)(NMBPredicate *))to {
	return ^(NMBPredicate *predicate) {
		[self verify:predicate negative:NO description:nil];
		return self;
	};
}

- (NMBExpectation *(^)(NMBPredicate *, NSString *))toWithDescription {
	return ^(NMBPredicate *predicate, NSString *description) {
		[self verify:predicate negative:NO description:description];
		return self;
	};
}

- (NMBExpectation *(^)(NMBPredicate *))toNot {
	return ^(NMBPredicate *predicate) {
		[self verify:predicate negative:YES description:nil];
		return self;
	};
}

- (NMBExpectation *(^)(NMBPredicate *, NSString *))toNotWithDescription {
	return ^(NMBPredicate *predicate, NSString *description) {
		[self verify:predicate negative:YES description:description];
		return self;
	};
}

- (NMBExpectation *(^)(NMBPredicate *))notTo {
	return self.toNot;
}

- (NMBExpectation *(^)(NMBPredicate *, NSString *))notToWithDescription {
	return self.toNotWithDescription;
}

- (void (^)(NMBPredicate *))toEventually {
	return ^(NMBPredicate *predicate) {
		[self verifyEventually:predicate negative:NO description:nil];
	};
}

- (void (^)(NMBPredicate *, NSString *))toEventuallyWithDescription {
	return ^(NMBPredicate *predicate, NSString *description) {
		[self verifyEventually:predicate negative:NO description:description];
	};
}

- (void (^)(NMBPredicate *))toEventuallyNot {
	return ^(NMBPredicate *predicate) {
		[self verifyEventually:predicate negative:YES description:nil];
	};
}

- (void (^)(NMBPredicate *, NSString *))toEventuallyNotWithDescription {
	return ^(NMBPredicate *predicate, NSString *description) {
		[self verifyEventually:predicate negative:YES description:description];
	};
}

- (void (^)(NMBPredicate *))toNotEventually {
	return self.toEventuallyNot;
}

- (void (^)(NMBPredicate *, NSString *))toNotEventuallyWithDescription {
	return self.toEventuallyNotWithDescription;
}

@end

NIMBLE_OVERLOADABLE NMBExpectation *NMB_expect(id (^actualBlock)(void), NSString *file, NSUInteger line) {
	return [[NMBExpectation alloc] initWithActualBlock:actualBlock file:file line:line];
}

NMBExpectation *NMB_expectAction(void (^actualBlock)(void), NSString *file, NSUInteger line) {
	return NMB_expect(^id {
		actualBlock();
		return nil;
	}, file, line);
}

void NMB_failWithMessage(NSString *message, NSString *file, NSUInteger line) {
	NMBRecordFailure(message, file, line);
}

NIMBLE_OVERLOADABLE NMBPredicate *NMB_equal(id expectedValue) {
	return [[NMBPredicate alloc] initWithBlock:^(id actual) {
		NMBResult *result = NMBMakeResult(NMBStatusDoesNotMatch, [NSString stringWithFormat:@"equal <%@>", NMBStringify(expectedValue)]);
		if (actual == nil || expectedValue == nil) {
			result.status = NMBStatusFail;
			result.beNilHint = YES;
		} else if ([actual isEqual:expectedValue]) {
			result.status = NMBStatusMatches;
		}
		return result;
	}];
}

// NSArray, NSSet, NSDictionary, NSHashTable, like Nimble's NMBCollection.
static BOOL NMBIsCollection(id value) {
	return [value isKindOfClass:NSArray.class] || [value isKindOfClass:NSSet.class] || [value isKindOfClass:NSDictionary.class] || [value isKindOfClass:NSHashTable.class];
}

NIMBLE_OVERLOADABLE NMBPredicate *NMB_haveCount(id expectedValue) {
	return [[NMBPredicate alloc] initWithBlock:^(id actual) {
		NSInteger expectedCount = [expectedValue integerValue];
		if (actual == nil) {
			NMBResult *result = NMBMakeResult(NMBStatusFail, [NSString stringWithFormat:@"have a collection with count %ld", (long)expectedCount]);
			result.beNilHint = YES;
			return result;
		}
		if (!NMBIsCollection(actual)) {
			NMBResult *result = NMBMakeResult(NMBStatusFail, @"get type of NSArray, NSSet, NSDictionary, or NSHashTable");
			result.actual = NSStringFromClass([actual class]);
			return result;
		}
		NSUInteger count = [actual count];
		NMBResult *result = NMBMakeBoolResult(count == (NSUInteger)expectedCount, [NSString stringWithFormat:@"have %@ with count %ld", NMBStringify(actual), (long)expectedCount]);
		result.actual = [NSString stringWithFormat:@"%lu", (unsigned long)count];
		return result;
	}];
}

NIMBLE_OVERLOADABLE NMBObjCBeCloseToPredicate *NMB_beCloseTo(NSNumber *expectedValue) {
	return [[NMBObjCBeCloseToPredicate alloc] initWithExpectedValue:expectedValue delta:0.001];
}

static NMBPredicate *NMBComparison(NSString *verb, NSNumber *expectedValue, BOOL (^accept)(NSComparisonResult)) {
	return [[NMBPredicate alloc] initWithBlock:^(id actual) {
		NSString *expected = [NSString stringWithFormat:@"%@ <%@>", verb, NMBStringify(expectedValue)];
		if (actual == nil || expectedValue == nil || ![actual respondsToSelector:@selector(compare:)]) {
			return NMBMakeResult(NMBStatusFail, expected);
		}
		return NMBMakeBoolResult(accept([actual compare:expectedValue]), expected);
	}];
}

NIMBLE_OVERLOADABLE NMBPredicate *NMB_beGreaterThan(NSNumber *expectedValue) {
	return NMBComparison(@"be greater than", expectedValue, ^(NSComparisonResult order) { return (BOOL)(order == NSOrderedDescending); });
}

NIMBLE_OVERLOADABLE NMBPredicate *NMB_beGreaterThanOrEqualTo(NSNumber *expectedValue) {
	return NMBComparison(@"be greater than or equal to", expectedValue, ^(NSComparisonResult order) { return (BOOL)(order != NSOrderedAscending); });
}

NIMBLE_OVERLOADABLE NMBPredicate *NMB_beLessThan(NSNumber *expectedValue) {
	return NMBComparison(@"be less than", expectedValue, ^(NSComparisonResult order) { return (BOOL)(order == NSOrderedAscending); });
}

NIMBLE_OVERLOADABLE NMBPredicate *NMB_beLessThanOrEqualTo(NSNumber *expectedValue) {
	return NMBComparison(@"be less than or equal to", expectedValue, ^(NSComparisonResult order) { return (BOOL)(order != NSOrderedDescending); });
}

NMBPredicate *NMB_beAnInstanceOf(Class expectedClass) {
	return [[NMBPredicate alloc] initWithBlock:^(id actual) {
		NMBResult *result = NMBMakeBoolResult(actual != nil && object_getClass(actual) == expectedClass, [NSString stringWithFormat:@"be an instance of %@", NSStringFromClass(expectedClass)]);
		result.actual = actual != nil ? [NSString stringWithFormat:@"%@ instance", NSStringFromClass(object_getClass(actual))] : @"nil";
		return result;
	}];
}

NMBPredicate *NMB_beAKindOf(Class expectedClass) {
	return [[NMBPredicate alloc] initWithBlock:^(id actual) {
		NSString *expected = [NSString stringWithFormat:@"be a kind of %@", NSStringFromClass(expectedClass)];
		if (actual == nil) return NMBMakeResult(NMBStatusFail, expected);
		NMBResult *result = NMBMakeBoolResult([actual isKindOfClass:expectedClass], expected);
		result.actual = [NSString stringWithFormat:@"%@ instance", NSStringFromClass([actual class])];
		return result;
	}];
}

NMBPredicate *NMB_beIdenticalTo(id expectedInstance) {
	return [[NMBPredicate alloc] initWithBlock:^(id actual) {
		NMBResult *result = NMBMakeBoolResult(actual != nil && actual == expectedInstance, [NSString stringWithFormat:@"be identical to %p", (__bridge void *)expectedInstance]);
		result.actual = [NSString stringWithFormat:@"%p", (__bridge void *)actual];
		return result;
	}];
}

NMBPredicate *NMB_be(id expectedInstance) {
	return NMB_beIdenticalTo(expectedInstance);
}

// Nimble's Objective-C logical matchers read the value as
// `(actual as? NSNumber)?.boolValue ?? false`: anything that isn't an
// NSNumber counts as false.
static BOOL NMBBoolValue(id actual) {
	return [actual isKindOfClass:NSNumber.class] && [actual boolValue];
}

NMBPredicate *NMB_beTruthy(void) {
	return [[NMBPredicate alloc] initWithBlock:^(id actual) {
		return NMBMakeBoolResult(NMBBoolValue(actual), @"be truthy");
	}];
}

NMBPredicate *NMB_beFalsy(void) {
	return [[NMBPredicate alloc] initWithBlock:^(id actual) {
		return NMBMakeBoolResult(!NMBBoolValue(actual), @"be falsy");
	}];
}

NMBPredicate *NMB_beTrue(void) {
	return [[NMBPredicate alloc] initWithBlock:^(id actual) {
		return NMBMakeBoolResult(NMBBoolValue(actual), @"be true");
	}];
}

NMBPredicate *NMB_beFalse(void) {
	return [[NMBPredicate alloc] initWithBlock:^(id actual) {
		if (actual == nil) {
			NMBResult *result = NMBMakeResult(NMBStatusFail, @"be false");
			result.beNilHint = YES;
			return result;
		}
		return NMBMakeBoolResult(!NMBBoolValue(actual), @"be false");
	}];
}

NMBPredicate *NMB_beNil(void) {
	return [[NMBPredicate alloc] initWithBlock:^(id actual) {
		return NMBMakeBoolResult(actual == nil, @"be nil");
	}];
}

NMBPredicate *NMB_beEmpty(void) {
	return [[NMBPredicate alloc] initWithBlock:^(id actual) {
		if ([actual isKindOfClass:NSString.class]) return NMBMakeBoolResult([actual length] == 0, @"be empty");
		if (NMBIsCollection(actual) || [actual isKindOfClass:NSIndexSet.class]) {
			return NMBMakeBoolResult([actual count] == 0, @"be empty");
		}
		NMBResult *result = NMBMakeResult(NMBStatusFail, @"be empty (only works for NSArrays, NSSets, NSIndexSets, NSDictionaries, NSHashTables, and NSStrings)");
		result.beNilHint = YES;
		return result;
	}];
}

NMBPredicate *NMB_containWithNilTermination(id itemOrSubstring, ...) {
	NSMutableArray *items = [NSMutableArray array];
	if (itemOrSubstring != nil) {
		[items addObject:itemOrSubstring];
		va_list args;
		va_start(args, itemOrSubstring);
		id next;
		while ((next = va_arg(args, id)) != nil) [items addObject:next];
		va_end(args);
	}

	return [[NMBPredicate alloc] initWithBlock:^(id actual) {
		NSString *expected = [NSString stringWithFormat:@"contain <%@>", [items componentsJoinedByString:@", "]];
		if ([actual isKindOfClass:NSString.class]) {
			for (id item in items) {
				if ([actual rangeOfString:[item description]].location == NSNotFound) return NMBMakeResult(NMBStatusDoesNotMatch, expected);
			}
			return NMBMakeResult(NMBStatusMatches, expected);
		}
		if ([actual isKindOfClass:NSArray.class] || [actual isKindOfClass:NSSet.class] || [actual isKindOfClass:NSHashTable.class]) {
			for (id item in items) {
				if (![actual containsObject:item]) return NMBMakeResult(NMBStatusDoesNotMatch, expected);
			}
			return NMBMakeResult(NMBStatusMatches, expected);
		}
		NMBResult *result = NMBMakeResult(NMBStatusFail, expected);
		result.beNilHint = YES;
		return result;
	}];
}
