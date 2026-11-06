//
//  Nimble.h
//  RACObjC
//
//  GNUstep only. A stand-in for the Objective-C API of Nimble 10, so the
//  specs in Core/RACObjCTests compile unchanged on GNUstep. Failures are
//  recorded on the running QuickSpec (see Quick/Quick.h).
//
//  Covers expect/expectAction with to, toNot/notTo, toEventually,
//  toEventuallyNot/toNotEventually and withTimeout, the matchers below, and
//  fail/failWithMessage. Matchers behave like Nimble's Objective-C ones,
//  including their nil handling and failure messages.
//

#import <Foundation/Foundation.h>
#import <dispatch/dispatch.h>

NS_ASSUME_NONNULL_BEGIN

@interface NMBPredicate : NSObject
@end

@interface NMBObjCBeCloseToPredicate : NMBPredicate
@property (nonatomic, readonly) NMBObjCBeCloseToPredicate *(^within)(double delta);
@end

@interface NMBExpectation : NSObject

- (instancetype)initWithActualBlock:(id _Nullable (^)(void))actualBlock file:(NSString *)file line:(NSUInteger)line;

@property (nonatomic, readonly) NMBExpectation *(^withTimeout)(NSTimeInterval timeout);
@property (nonatomic, readonly) NMBExpectation *(^to)(NMBPredicate *predicate);
@property (nonatomic, readonly) NMBExpectation *(^toWithDescription)(NMBPredicate *predicate, NSString *description);
@property (nonatomic, readonly) NMBExpectation *(^toNot)(NMBPredicate *predicate);
@property (nonatomic, readonly) NMBExpectation *(^toNotWithDescription)(NMBPredicate *predicate, NSString *description);
@property (nonatomic, readonly) NMBExpectation *(^notTo)(NMBPredicate *predicate);
@property (nonatomic, readonly) NMBExpectation *(^notToWithDescription)(NMBPredicate *predicate, NSString *description);
@property (nonatomic, readonly) void (^toEventually)(NMBPredicate *predicate);
@property (nonatomic, readonly) void (^toEventuallyWithDescription)(NMBPredicate *predicate, NSString *description);
@property (nonatomic, readonly) void (^toEventuallyNot)(NMBPredicate *predicate);
@property (nonatomic, readonly) void (^toEventuallyNotWithDescription)(NMBPredicate *predicate, NSString *description);
@property (nonatomic, readonly) void (^toNotEventually)(NMBPredicate *predicate);
@property (nonatomic, readonly) void (^toNotEventuallyWithDescription)(NMBPredicate *predicate, NSString *description);

+ (void)failWithMessage:(NSString *)message file:(NSString *)file line:(NSUInteger)line;

@end

#define NIMBLE_OVERLOADABLE __attribute__((overloadable))
#define NIMBLE_EXPORT FOUNDATION_EXPORT
// GNUstep's Foundation has no FOUNDATION_STATIC_INLINE.
#define NIMBLE_EXPORT_INLINE static inline

#define NIMBLE_VALUE_OF(VAL) ({ \
	__typeof__((VAL)) val = (VAL); \
	[NSValue valueWithBytes:&val objCType:@encode(__typeof__((VAL)))]; \
})

#ifdef NIMBLE_DISABLE_SHORT_SYNTAX
#define NIMBLE_SHORT(PROTO, ORIGINAL)
#define NIMBLE_SHORT_OVERLOADED(PROTO, ORIGINAL)
#else
#define NIMBLE_SHORT(PROTO, ORIGINAL) NIMBLE_EXPORT_INLINE PROTO { return (ORIGINAL); }
#define NIMBLE_SHORT_OVERLOADED(PROTO, ORIGINAL) NIMBLE_EXPORT_INLINE NIMBLE_OVERLOADABLE PROTO { return (ORIGINAL); }
#endif

// The overloads box scalars like Nimble does. There's no BOOL overload:
// libobjc2 defines BOOL as unsigned char on Linux and FreeBSD, which already
// has one.

#define DEFINE_NMB_EXPECT_OVERLOAD(TYPE, EXPR) \
	NIMBLE_EXPORT_INLINE NIMBLE_OVERLOADABLE \
	NMBExpectation *NMB_expect(TYPE(^actualBlock)(void), NSString *file, NSUInteger line) { \
		return NMB_expect(^id { return EXPR; }, file, line); \
	}

NIMBLE_EXPORT NIMBLE_OVERLOADABLE
NMBExpectation *NMB_expect(id _Nullable (^actualBlock)(void), NSString *file, NSUInteger line);

DEFINE_NMB_EXPECT_OVERLOAD(void *, nil)
DEFINE_NMB_EXPECT_OVERLOAD(NSRange, NIMBLE_VALUE_OF(actualBlock()))
DEFINE_NMB_EXPECT_OVERLOAD(long, @(actualBlock()))
DEFINE_NMB_EXPECT_OVERLOAD(unsigned long, @(actualBlock()))
DEFINE_NMB_EXPECT_OVERLOAD(int, @(actualBlock()))
DEFINE_NMB_EXPECT_OVERLOAD(unsigned int, @(actualBlock()))
DEFINE_NMB_EXPECT_OVERLOAD(float, @(actualBlock()))
DEFINE_NMB_EXPECT_OVERLOAD(double, @(actualBlock()))
DEFINE_NMB_EXPECT_OVERLOAD(long long, @(actualBlock()))
DEFINE_NMB_EXPECT_OVERLOAD(unsigned long long, @(actualBlock()))
DEFINE_NMB_EXPECT_OVERLOAD(char, @(actualBlock()))
DEFINE_NMB_EXPECT_OVERLOAD(unsigned char, @(actualBlock()))
DEFINE_NMB_EXPECT_OVERLOAD(char *, @(actualBlock()))

// On Apple platforms dispatch objects are Objective-C objects. Without
// OS_OBJECT_USE_OBJC they're C pointers, so box them: NULL becomes nil.
#if !OS_OBJECT_USE_OBJC
#define NIMBLE_BOX_POINTER(PTR) ({ \
	void *pointer = (void *)(PTR); \
	pointer != NULL ? [NSValue valueWithPointer:pointer] : nil; \
})
DEFINE_NMB_EXPECT_OVERLOAD(dispatch_queue_t, NIMBLE_BOX_POINTER(actualBlock()))
DEFINE_NMB_EXPECT_OVERLOAD(dispatch_group_t, NIMBLE_BOX_POINTER(actualBlock()))
DEFINE_NMB_EXPECT_OVERLOAD(dispatch_semaphore_t, NIMBLE_BOX_POINTER(actualBlock()))
DEFINE_NMB_EXPECT_OVERLOAD(dispatch_source_t, NIMBLE_BOX_POINTER(actualBlock()))
#undef NIMBLE_BOX_POINTER
#endif

#undef DEFINE_NMB_EXPECT_OVERLOAD

NIMBLE_EXPORT NMBExpectation *NMB_expectAction(void (^actualBlock)(void), NSString *file, NSUInteger line);

// Defines NMB_<NAME>(TYPE) for each scalar type, boxing like Nimble, plus
// the short <NAME>(TYPE) form.
#define DEFINE_NUMBER_OVERLOAD(RESULT, NAME, TYPE) \
	NIMBLE_EXPORT_INLINE NIMBLE_OVERLOADABLE \
	RESULT *NMB_##NAME(TYPE expectedValue) { \
		return NMB_##NAME((NSNumber *)@(expectedValue)); \
	} \
	NIMBLE_SHORT_OVERLOADED(RESULT *NAME(TYPE expectedValue), NMB_##NAME(expectedValue));

#define DEFINE_INTEGER_OVERLOADS(RESULT, NAME) \
	DEFINE_NUMBER_OVERLOAD(RESULT, NAME, long) \
	DEFINE_NUMBER_OVERLOAD(RESULT, NAME, unsigned long) \
	DEFINE_NUMBER_OVERLOAD(RESULT, NAME, int) \
	DEFINE_NUMBER_OVERLOAD(RESULT, NAME, unsigned int) \
	DEFINE_NUMBER_OVERLOAD(RESULT, NAME, long long) \
	DEFINE_NUMBER_OVERLOAD(RESULT, NAME, unsigned long long) \
	DEFINE_NUMBER_OVERLOAD(RESULT, NAME, char) \
	DEFINE_NUMBER_OVERLOAD(RESULT, NAME, unsigned char)

#define DEFINE_NUMERIC_OVERLOADS(RESULT, NAME) \
	DEFINE_INTEGER_OVERLOADS(RESULT, NAME) \
	DEFINE_NUMBER_OVERLOAD(RESULT, NAME, float) \
	DEFINE_NUMBER_OVERLOAD(RESULT, NAME, double)

NIMBLE_EXPORT NIMBLE_OVERLOADABLE NMBPredicate *NMB_equal(id _Nullable expectedValue);
NIMBLE_SHORT_OVERLOADED(NMBPredicate *equal(id _Nullable expectedValue), NMB_equal(expectedValue));
NIMBLE_EXPORT_INLINE NIMBLE_OVERLOADABLE NMBPredicate *NMB_equal(void *_Nullable expectedValue) {
	return NMB_equal((id)nil);
}
NIMBLE_SHORT_OVERLOADED(NMBPredicate *equal(void *_Nullable expectedValue), NMB_equal(expectedValue));
NIMBLE_EXPORT_INLINE NIMBLE_OVERLOADABLE NMBPredicate *NMB_equal(NSRange expectedValue) {
	return NMB_equal((id)NIMBLE_VALUE_OF(expectedValue));
}
NIMBLE_SHORT_OVERLOADED(NMBPredicate *equal(NSRange expectedValue), NMB_equal(expectedValue));
DEFINE_NUMERIC_OVERLOADS(NMBPredicate, equal)
NIMBLE_EXPORT_INLINE NIMBLE_OVERLOADABLE NMBPredicate *NMB_equal(char *expectedValue) {
	return NMB_equal((id)@(expectedValue));
}
NIMBLE_SHORT_OVERLOADED(NMBPredicate *equal(char *expectedValue), NMB_equal(expectedValue));

NIMBLE_EXPORT NIMBLE_OVERLOADABLE NMBPredicate *NMB_haveCount(id expectedValue);
NIMBLE_SHORT_OVERLOADED(NMBPredicate *haveCount(id expectedValue), NMB_haveCount(expectedValue));
DEFINE_INTEGER_OVERLOADS(NMBPredicate, haveCount)

NIMBLE_EXPORT NIMBLE_OVERLOADABLE NMBObjCBeCloseToPredicate *NMB_beCloseTo(NSNumber *expectedValue);
NIMBLE_SHORT_OVERLOADED(NMBObjCBeCloseToPredicate *beCloseTo(NSNumber *expectedValue), NMB_beCloseTo(expectedValue));
DEFINE_NUMERIC_OVERLOADS(NMBObjCBeCloseToPredicate, beCloseTo)

NIMBLE_EXPORT NIMBLE_OVERLOADABLE NMBPredicate *NMB_beGreaterThan(NSNumber *expectedValue);
NIMBLE_SHORT_OVERLOADED(NMBPredicate *beGreaterThan(NSNumber *expectedValue), NMB_beGreaterThan(expectedValue));
DEFINE_NUMERIC_OVERLOADS(NMBPredicate, beGreaterThan)

NIMBLE_EXPORT NIMBLE_OVERLOADABLE NMBPredicate *NMB_beGreaterThanOrEqualTo(NSNumber *expectedValue);
NIMBLE_SHORT_OVERLOADED(NMBPredicate *beGreaterThanOrEqualTo(NSNumber *expectedValue), NMB_beGreaterThanOrEqualTo(expectedValue));
DEFINE_NUMERIC_OVERLOADS(NMBPredicate, beGreaterThanOrEqualTo)

NIMBLE_EXPORT NIMBLE_OVERLOADABLE NMBPredicate *NMB_beLessThan(NSNumber *expectedValue);
NIMBLE_SHORT_OVERLOADED(NMBPredicate *beLessThan(NSNumber *expectedValue), NMB_beLessThan(expectedValue));
DEFINE_NUMERIC_OVERLOADS(NMBPredicate, beLessThan)

NIMBLE_EXPORT NIMBLE_OVERLOADABLE NMBPredicate *NMB_beLessThanOrEqualTo(NSNumber *expectedValue);
NIMBLE_SHORT_OVERLOADED(NMBPredicate *beLessThanOrEqualTo(NSNumber *expectedValue), NMB_beLessThanOrEqualTo(expectedValue));
DEFINE_NUMERIC_OVERLOADS(NMBPredicate, beLessThanOrEqualTo)

#undef DEFINE_NUMERIC_OVERLOADS
#undef DEFINE_INTEGER_OVERLOADS
#undef DEFINE_NUMBER_OVERLOAD

NIMBLE_EXPORT NMBPredicate *NMB_beAnInstanceOf(Class expectedClass);
NIMBLE_SHORT(NMBPredicate *beAnInstanceOf(Class expectedClass), NMB_beAnInstanceOf(expectedClass));

NIMBLE_EXPORT NMBPredicate *NMB_beAKindOf(Class expectedClass);
NIMBLE_SHORT(NMBPredicate *beAKindOf(Class expectedClass), NMB_beAKindOf(expectedClass));

NIMBLE_EXPORT NMBPredicate *NMB_beIdenticalTo(id _Nullable expectedInstance);
NIMBLE_SHORT(NMBPredicate *beIdenticalTo(id _Nullable expectedInstance), NMB_beIdenticalTo(expectedInstance));

NIMBLE_EXPORT NMBPredicate *NMB_be(id _Nullable expectedInstance);
NIMBLE_SHORT(NMBPredicate *be(id _Nullable expectedInstance), NMB_be(expectedInstance));

NIMBLE_EXPORT NMBPredicate *NMB_beTruthy(void);
NIMBLE_SHORT(NMBPredicate *beTruthy(void), NMB_beTruthy());

NIMBLE_EXPORT NMBPredicate *NMB_beFalsy(void);
NIMBLE_SHORT(NMBPredicate *beFalsy(void), NMB_beFalsy());

NIMBLE_EXPORT NMBPredicate *NMB_beTrue(void);
NIMBLE_SHORT(NMBPredicate *beTrue(void), NMB_beTrue());

NIMBLE_EXPORT NMBPredicate *NMB_beFalse(void);
NIMBLE_SHORT(NMBPredicate *beFalse(void), NMB_beFalse());

NIMBLE_EXPORT NMBPredicate *NMB_beNil(void);
NIMBLE_SHORT(NMBPredicate *beNil(void), NMB_beNil());

NIMBLE_EXPORT NMBPredicate *NMB_beEmpty(void);
NIMBLE_SHORT(NMBPredicate *beEmpty(void), NMB_beEmpty());

NIMBLE_EXPORT NMBPredicate *NMB_containWithNilTermination(id itemOrSubstring, ...) NS_REQUIRES_NIL_TERMINATION;
#define NMB_contain(...) NMB_containWithNilTermination(__VA_ARGS__, nil)

NIMBLE_EXPORT void NMB_failWithMessage(NSString *message, NSString *file, NSUInteger line);

#ifndef NIMBLE_DISABLE_SHORT_SYNTAX
#define contain(...) NMB_contain(__VA_ARGS__)
#define expect(...) NMB_expect(^{ return (__VA_ARGS__); }, @(__FILE__), __LINE__)
#define expectAction(BLOCK) NMB_expectAction((BLOCK), @(__FILE__), __LINE__)
#define failWithMessage(message) NMB_failWithMessage(message, @(__FILE__), __LINE__)
#define fail() failWithMessage(@"fail() always fails")
#endif

NS_ASSUME_NONNULL_END
