//
//  Quick.h
//  RACObjC
//
//  GNUstep only. A stand-in for the Objective-C API of Quick 5, so the
//  specs in Core/RACObjCTests compile unchanged on GNUstep. Specs are
//  XCTestCase subclasses and run on gnustep/tools-xctest.
//
//  Covers what the specs use: QuickSpecBegin/End, QuickConfigurationBegin/End,
//  describe/context, it, beforeEach/afterEach, beforeSuite/afterSuite,
//  sharedExamples/itBehavesLike, and pending/xdescribe/xcontext/xit.
//
//  Adds a list of known failures, read from the Markdown file
//  QUICK_KNOWN_FAILURES names (see Quick.m).
//

#import <Foundation/Foundation.h>
#import <XCTest/XCTest.h>

NS_ASSUME_NONNULL_BEGIN

@class QCKConfiguration;

// Subclasses define their examples in -spec. One test method is generated
// per example, named like Quick does it on Apple platforms.
@interface QuickSpec : XCTestCase

- (void)spec;

// The spec whose example is running, or nil.
@property (class, nonatomic, readonly, nullable) QuickSpec *current;

@end

// Subclasses override +configure: to define shared examples. Every subclass
// is configured before the first spec is built.
@interface QuickConfiguration : NSObject

+ (void)configure:(QCKConfiguration *)configuration;

@end

// Quick's configuration options aren't supported; this only exists so that
// +configure: has the same signature as on Apple platforms.
@interface QCKConfiguration : NSObject
@end

#define QuickConfigurationBegin(name) \
	@interface name : QuickConfiguration; @end \
	@implementation name \

#define QuickConfigurationEnd \
	@end \

#define QuickSpecBegin(name) \
	@interface name : QuickSpec; @end \
	@implementation name \
	- (void)spec { \

#define QuickSpecEnd \
	} \
	@end \

typedef NSDictionary *_Nonnull (^QCKDSLSharedExampleContext)(void);
typedef void (^QCKDSLSharedExampleBlock)(QCKDSLSharedExampleContext);
typedef void (^QCKDSLEmptyBlock)(void);

#define QUICK_EXPORT FOUNDATION_EXPORT

QUICK_EXPORT void qck_beforeSuite(QCKDSLEmptyBlock closure);
QUICK_EXPORT void qck_afterSuite(QCKDSLEmptyBlock closure);
QUICK_EXPORT void qck_sharedExamples(NSString *name, QCKDSLSharedExampleBlock closure);
QUICK_EXPORT void qck_describe(NSString *description, QCKDSLEmptyBlock closure);
QUICK_EXPORT void qck_context(NSString *description, QCKDSLEmptyBlock closure);
QUICK_EXPORT void qck_beforeEach(QCKDSLEmptyBlock closure);
QUICK_EXPORT void qck_afterEach(QCKDSLEmptyBlock closure);
QUICK_EXPORT void qck_pending(NSString *description, QCKDSLEmptyBlock closure);
QUICK_EXPORT void qck_xdescribe(NSString *description, QCKDSLEmptyBlock closure);
QUICK_EXPORT void qck_xcontext(NSString *description, QCKDSLEmptyBlock closure);

#define qck_it qck_it_builder(@(__FILE__), __LINE__)
#define qck_xit qck_xit_builder(@(__FILE__), __LINE__)
#define qck_itBehavesLike qck_itBehavesLike_builder(@(__FILE__), __LINE__)

typedef void (^QCKItBlock)(NSString *description, QCKDSLEmptyBlock closure);
typedef void (^QCKItBehavesLikeBlock)(NSString *name, QCKDSLSharedExampleContext context);

QUICK_EXPORT QCKItBlock qck_it_builder(NSString *file, NSUInteger line);
QUICK_EXPORT QCKItBlock qck_xit_builder(NSString *file, NSUInteger line);
QUICK_EXPORT QCKItBehavesLikeBlock qck_itBehavesLike_builder(NSString *file, NSUInteger line);

#ifndef QUICK_DISABLE_SHORT_SYNTAX

static inline void beforeSuite(QCKDSLEmptyBlock closure) { qck_beforeSuite(closure); }
static inline void afterSuite(QCKDSLEmptyBlock closure) { qck_afterSuite(closure); }
static inline void sharedExamples(NSString *name, QCKDSLSharedExampleBlock closure) { qck_sharedExamples(name, closure); }
static inline void describe(NSString *description, QCKDSLEmptyBlock closure) { qck_describe(description, closure); }
static inline void context(NSString *description, QCKDSLEmptyBlock closure) { qck_context(description, closure); }
static inline void beforeEach(QCKDSLEmptyBlock closure) { qck_beforeEach(closure); }
static inline void afterEach(QCKDSLEmptyBlock closure) { qck_afterEach(closure); }
static inline void pending(NSString *description, QCKDSLEmptyBlock closure) { qck_pending(description, closure); }
static inline void xdescribe(NSString *description, QCKDSLEmptyBlock closure) { qck_xdescribe(description, closure); }
static inline void xcontext(NSString *description, QCKDSLEmptyBlock closure) { qck_xcontext(description, closure); }

#define it qck_it
#define xit qck_xit
#define itBehavesLike qck_itBehavesLike

#endif

NS_ASSUME_NONNULL_END
