//
//  Quick.m
//  RACObjC
//
//  GNUstep only. See Quick/Quick.h.
//
//  The first +testInvocations call builds every spec: QuickConfiguration
//  subclasses register their shared examples, then each QuickSpec subclass
//  runs -spec, which records example groups and examples. Each spec class
//  then gets one test method per example, named from the example's full
//  description the way Quick names them ("group, example" with characters
//  that aren't letters or digits replaced by "_"), in alphabetical order like
//  XCTest on Apple platforms.
//
//  Known failures (not a Quick feature): QUICK_KNOWN_FAILURES can name a
//  Markdown file. Each list item holding nothing but a code span is an entry:
//
//    - `SpecClass.test_method`
//
//  The test can be preceded by "skip" and by the architectures ("aarch64",
//  "x86_64") the entry is limited to. Every other line is ignored.
//
//    - A listed test runs, and its failures are logged instead of recorded.
//      If it passes, that's recorded as a failure, so the list stays current.
//    - A "skip" test doesn't run at all (for tests that crash the process).
//    - A listed test that doesn't exist fails QuickKnownFailures, on every
//      architecture.
//

#import <Quick/Quick.h>
#import <objc/runtime.h>
#include <stdlib.h>
#include <string.h>
#include <sys/utsname.h>

@interface QCKExampleGroup : NSObject

@property (nonatomic, copy, nullable) NSString *desc;
@property (nonatomic, strong, nullable) QCKExampleGroup *parent;
@property (nonatomic, assign) BOOL pending;
@property (nonatomic, strong, readonly) NSMutableArray<QCKDSLEmptyBlock> *befores;
@property (nonatomic, strong, readonly) NSMutableArray<QCKDSLEmptyBlock> *afters;

@end

@implementation QCKExampleGroup

- (instancetype)init {
	if ((self = [super init])) {
		_befores = [NSMutableArray array];
		_afters = [NSMutableArray array];
	}
	return self;
}

// Groups from the root to this one.
- (NSArray<QCKExampleGroup *> *)chain {
	NSMutableArray *chain = [NSMutableArray array];
	for (QCKExampleGroup *group = self; group != nil; group = group.parent) {
		[chain insertObject:group atIndex:0];
	}
	return chain;
}

- (NSString *)name {
	NSMutableArray *names = [NSMutableArray array];
	for (QCKExampleGroup *group in self.chain) {
		if (group.desc != nil) [names addObject:group.desc];
	}
	return [names componentsJoinedByString:@", "];
}

- (BOOL)isPending {
	for (QCKExampleGroup *group = self; group != nil; group = group.parent) {
		if (group.pending) return YES;
	}
	return NO;
}

@end

@interface QCKExample : NSObject

@property (nonatomic, strong) QCKExampleGroup *group;
@property (nonatomic, copy) NSString *desc;
@property (nonatomic, copy) NSString *file;
@property (nonatomic, assign) NSUInteger line;
@property (nonatomic, copy) QCKDSLEmptyBlock closure;
@property (nonatomic, assign) BOOL pending;
// Listed in the known failures file.
@property (nonatomic, assign) BOOL knownFailure;

@end

@implementation QCKExample

- (NSString *)name {
	NSString *groupName = self.group.name;
	return groupName.length > 0 ? [NSString stringWithFormat:@"%@, %@", groupName, self.desc] : self.desc;
}

@end

static NSMutableDictionary<NSString *, QCKDSLSharedExampleBlock> *QCKSharedExamples;
static NSMutableArray<QCKDSLEmptyBlock> *QCKBeforeSuiteClosures;
static NSMutableArray<QCKDSLEmptyBlock> *QCKAfterSuiteClosures;
static NSMutableDictionary<NSString *, NSArray<QCKExample *> *> *QCKExamplesBySpec;
// Spec class name -> test method name -> example, and the sorted names.
static NSMutableDictionary<NSString *, NSMutableDictionary<NSString *, QCKExample *> *> *QCKExamplesByTestMethod;
static NSMutableDictionary<NSString *, NSArray<NSString *> *> *QCKTestMethodNames;
static NSMutableArray<QuickSpec *> *QCKSpecInstances;

// The known failures file: every test it lists, and the entries for this
// architecture, "SpecClass.test_method" -> whether to skip it.
static NSString *QCKKnownFailuresPath;
static NSSet<NSString *> *QCKListedKnownFailures;
static NSDictionary<NSString *, NSNumber *> *QCKKnownFailures;
static NSMutableSet<NSString *> *QCKMatchedKnownFailures;
static NSUInteger QCKKnownFailuresFailed;
static NSUInteger QCKKnownFailuresSkipped;

// Set while a spec or shared example is being built.
static QCKExampleGroup *QCKCurrentGroup;
static NSMutableArray<QCKExample *> *QCKCurrentExamples;

// Set while an example runs, with the failures logged for a known failure.
static QuickSpec *QCKCurrentSpec;
static QCKExample *QCKCurrentExample;
static NSUInteger QCKCurrentKnownFailures;

static NSArray<Class> *QCKSubclassesOf(Class superclass) {
	int count = objc_getClassList(NULL, 0);
	Class *classes = (Class *)calloc((size_t)MAX(count, 1), sizeof(Class));
	count = objc_getClassList(classes, count);

	NSMutableArray<Class> *subclasses = [NSMutableArray array];
	for (int i = 0; i < count; i++) {
		for (Class cls = class_getSuperclass(classes[i]); cls != Nil; cls = class_getSuperclass(cls)) {
			if (cls == superclass) {
				[subclasses addObject:classes[i]];
				break;
			}
		}
	}
	free(classes);

	[subclasses sortUsingComparator:^(Class a, Class b) {
		return [NSStringFromClass(a) compare:NSStringFromClass(b)];
	}];
	return subclasses;
}

static void QCKRequireBuilding(NSString *function) {
	if (QCKCurrentGroup != nil) return;
	[NSException raise:NSInternalInconsistencyException format:@"%@ must be called inside -spec or a shared example group", function];
}

static void QCKRunAfterSuite(void) {
	for (QCKDSLEmptyBlock closure in QCKAfterSuiteClosures) closure();

	if (QCKKnownFailures != nil) {
		NSLog(@"Quick: %lu known failures failed as listed, %lu skipped (%@)", (unsigned long)QCKKnownFailuresFailed, (unsigned long)QCKKnownFailuresSkipped, QCKKnownFailuresPath);
	}
}

static void QCKLoadKnownFailures(void) {
	const char *path = getenv("QUICK_KNOWN_FAILURES");
	if (path == NULL || *path == '\0') return;

	QCKKnownFailuresPath = @(path);
	NSError *error = nil;
	NSString *contents = [NSString stringWithContentsOfFile:QCKKnownFailuresPath encoding:NSUTF8StringEncoding error:&error];
	if (contents == nil) {
		[NSException raise:NSInvalidArgumentException format:@"Can't read QUICK_KNOWN_FAILURES file %@: %@", QCKKnownFailuresPath, error];
	}

	// uname -m, with FreeBSD's names for the two CPUs mapped to Linux's.
	struct utsname name;
	uname(&name);
	NSString *architecture = @(name.machine);
	if (strcmp(name.machine, "amd64") == 0) architecture = @"x86_64";
	if (strcmp(name.machine, "arm64") == 0) architecture = @"aarch64";
	NSSet<NSString *> *architectures = [NSSet setWithObjects:@"aarch64", @"x86_64", nil];

	NSMutableSet<NSString *> *listed = [NSMutableSet set];
	NSMutableDictionary<NSString *, NSNumber *> *knownFailures = [NSMutableDictionary dictionary];
	for (NSString *rawLine in [contents componentsSeparatedByString:@"\n"]) {
		// An entry is "- `...`" (or "* `...`") with nothing else on the line.
		NSString *line = [rawLine stringByTrimmingCharactersInSet:NSCharacterSet.whitespaceAndNewlineCharacterSet];
		if (!([line hasPrefix:@"- `"] || [line hasPrefix:@"* `"]) || ![line hasSuffix:@"`"] || line.length < 5) continue;
		NSString *entry = [line substringWithRange:NSMakeRange(3, line.length - 4)];
		if ([entry rangeOfString:@"`"].location != NSNotFound) continue;

		NSMutableArray<NSString *> *words = [[entry componentsSeparatedByCharactersInSet:NSCharacterSet.whitespaceCharacterSet] mutableCopy];
		[words removeObject:@""];
		if (words.count == 0) continue;

		NSString *test = words.lastObject;
		BOOL skip = NO;
		NSMutableSet<NSString *> *limitedTo = [NSMutableSet set];
		for (NSString *word in [words subarrayWithRange:NSMakeRange(0, words.count - 1)]) {
			if ([word isEqual:@"skip"]) {
				skip = YES;
			} else if ([architectures containsObject:word]) {
				[limitedTo addObject:word];
			} else {
				test = nil;
			}
		}
		if (test == nil || [test rangeOfString:@"."].location == NSNotFound) {
			[NSException raise:NSInvalidArgumentException format:@"%@: expected \"- `[skip] [aarch64|x86_64] SpecClass.test_method`\", got \"%@\"", QCKKnownFailuresPath, rawLine];
		}

		[listed addObject:test];
		if (limitedTo.count == 0 || [limitedTo containsObject:architecture]) knownFailures[test] = @(skip);
	}

	QCKListedKnownFailures = listed;
	QCKKnownFailures = knownFailures;
	QCKMatchedKnownFailures = [NSMutableSet set];
}

static void QCKBuildSpec(Class specClass) {
	QCKExampleGroup *root = [[QCKExampleGroup alloc] init];
	NSMutableArray<QCKExample *> *examples = [NSMutableArray array];

	QCKCurrentGroup = root;
	QCKCurrentExamples = examples;
	@try {
		QuickSpec *spec = [[specClass alloc] initWithInvocation:nil];
		// Blocks in the spec may capture it, as on Apple platforms.
		[QCKSpecInstances addObject:spec];
		[spec spec];
	}
	@catch (id exception) {
		// Report the failure as a test of its own instead of aborting the run.
		NSString *reason = [NSString stringWithFormat:@"Building the spec threw %@", exception];
		QCKExample *example = [[QCKExample alloc] init];
		example.group = root;
		example.desc = @"spec build failed";
		example.file = @"";
		example.closure = ^{
			[QCKCurrentSpec recordFailureWithDescription:reason inFile:nil atLine:0 expected:NO];
		};
		[examples addObject:example];
	}
	@finally {
		QCKCurrentGroup = nil;
		QCKCurrentExamples = nil;
	}

	QCKExamplesBySpec[NSStringFromClass(specClass)] = examples;
}

// Quick's String.c99ExtendedIdentifier: whitespace, punctuation, symbols,
// control, illegal and non-base characters each become "_".
static NSString *QCKIdentifier(NSString *name) {
	static NSCharacterSet *invalid;
	if (invalid == nil) {
		NSMutableCharacterSet *set = [[NSCharacterSet whitespaceAndNewlineCharacterSet] mutableCopy];
		[set formUnionWithCharacterSet:NSCharacterSet.illegalCharacterSet];
		[set formUnionWithCharacterSet:NSCharacterSet.controlCharacterSet];
		[set formUnionWithCharacterSet:NSCharacterSet.punctuationCharacterSet];
		[set formUnionWithCharacterSet:NSCharacterSet.nonBaseCharacterSet];
		[set formUnionWithCharacterSet:NSCharacterSet.symbolCharacterSet];
		invalid = [set copy];
	}

	NSMutableString *identifier = [NSMutableString stringWithCapacity:name.length];
	for (NSUInteger i = 0; i < name.length; i++) {
		unichar character = [name characterAtIndex:i];
		if ([invalid characterIsMember:character]) {
			[identifier appendString:@"_"];
		} else {
			[identifier appendFormat:@"%C", character];
		}
	}
	return identifier.length > 0 ? identifier : @"_";
}

static void QCKTestMethod(QuickSpec *spec, SEL _cmd);

// Adds one test method per example that runs, and applies the known failures.
static void QCKAddTestMethods(Class specClass) {
	NSString *className = NSStringFromClass(specClass);
	NSMutableDictionary<NSString *, QCKExample *> *examplesByName = [NSMutableDictionary dictionary];
	NSMutableSet<NSString *> *names = [NSMutableSet set];
	for (QCKExample *example in QCKExamplesBySpec[className]) {
		if (example.pending) continue;

		NSString *baseName = QCKIdentifier(example.name);
		NSString *name = baseName;
		for (NSUInteger i = 2; [names containsObject:name]; i++) {
			name = [NSString stringWithFormat:@"%@_%lu", baseName, (unsigned long)i];
		}
		[names addObject:name];

		NSString *fullName = [NSString stringWithFormat:@"%@.%@", className, name];
		if ([QCKListedKnownFailures containsObject:fullName]) [QCKMatchedKnownFailures addObject:fullName];
		NSNumber *skip = QCKKnownFailures[fullName];
		if (skip != nil) {
			if (skip.boolValue) {
				QCKKnownFailuresSkipped++;
				continue;
			}
			example.knownFailure = YES;
		}

		examplesByName[name] = example;
		class_addMethod(specClass, NSSelectorFromString(name), (IMP)QCKTestMethod, "v@:");
	}

	QCKExamplesByTestMethod[className] = examplesByName;
	QCKTestMethodNames[className] = [examplesByName.allKeys sortedArrayUsingSelector:@selector(compare:)];
}

static void QCKBuildWorldIfNeeded(void) {
	static BOOL built = NO;
	if (built) return;
	built = YES;

	QCKSharedExamples = [NSMutableDictionary dictionary];
	QCKBeforeSuiteClosures = [NSMutableArray array];
	QCKAfterSuiteClosures = [NSMutableArray array];
	QCKExamplesBySpec = [NSMutableDictionary dictionary];
	QCKExamplesByTestMethod = [NSMutableDictionary dictionary];
	QCKTestMethodNames = [NSMutableDictionary dictionary];
	QCKSpecInstances = [NSMutableArray array];
	QCKLoadKnownFailures();

	QCKConfiguration *configuration = [[QCKConfiguration alloc] init];
	for (Class cls in QCKSubclassesOf([QuickConfiguration class])) {
		[cls configure:configuration];
	}

	NSUInteger exampleCount = 0, pendingCount = 0;
	for (Class cls in QCKSubclassesOf([QuickSpec class])) {
		QCKBuildSpec(cls);
		QCKAddTestMethods(cls);
		for (QCKExample *example in QCKExamplesBySpec[NSStringFromClass(cls)]) {
			if (example.pending) pendingCount++; else exampleCount++;
		}
	}

	NSLog(@"Quick: %lu examples, %lu pending", (unsigned long)exampleCount, (unsigned long)pendingCount);
	if (QCKKnownFailures != nil) {
		NSLog(@"Quick: %@ lists %lu known failures, %lu for this architecture, %lu of them skipped", QCKKnownFailuresPath, (unsigned long)QCKListedKnownFailures.count, (unsigned long)QCKKnownFailures.count, (unsigned long)QCKKnownFailuresSkipped);
	}
	atexit(QCKRunAfterSuite);
}

static void QCKLogKnownFailure(QuickSpec *spec, NSString *description) {
	@synchronized (QuickSpec.class) {
		QCKCurrentKnownFailures++;
	}
	NSLog(@"Quick: known failure %@: %@", spec.name, description);
}

@interface QuickSpec ()

- (void)qck_recordFailureWithDescription:(NSString *)description inFile:(NSString *)file atLine:(NSUInteger)line;

@end

static void QCKRunExample(QCKExample *example, QuickSpec *spec) {
	static BOOL suiteStarted = NO;
	if (!suiteStarted) {
		suiteStarted = YES;
		for (QCKDSLEmptyBlock closure in QCKBeforeSuiteClosures) closure();
	}

	NSArray<QCKExampleGroup *> *chain = example.group.chain;
	QCKCurrentSpec = spec;
	QCKCurrentExample = example;
	QCKCurrentKnownFailures = 0;
	@try {
		for (QCKExampleGroup *group in chain) {
			for (QCKDSLEmptyBlock closure in group.befores) closure();
		}
		example.closure();
	}
	@catch (id exception) {
		if (!example.knownFailure) @throw;
		QCKLogKnownFailure(spec, [NSString stringWithFormat:@"threw %@", exception]);
	}
	@finally {
		for (QCKExampleGroup *group in chain.reverseObjectEnumerator) {
			for (QCKDSLEmptyBlock closure in group.afters) closure();
		}
		QCKCurrentSpec = nil;
		QCKCurrentExample = nil;
	}

	if (!example.knownFailure) return;
	if (QCKCurrentKnownFailures > 0) {
		QCKKnownFailuresFailed++;
	} else {
		NSString *fullName = [NSString stringWithFormat:@"%@.%@", NSStringFromClass(spec.class), NSStringFromSelector(spec.invocation.selector)];
		[spec qck_recordFailureWithDescription:[NSString stringWithFormat:@"listed as a known failure but passed; remove %@ from %@", fullName, QCKKnownFailuresPath] inFile:example.file atLine:example.line];
	}
}

// The implementation of every generated test method. It looks the example up
// by class and selector instead of capturing it in a block IMP: libobjc2
// (through at least 2.3) can only hand out one page of block trampolines,
// 128 on aarch64 and 256 on x86_64, and crashes after that
// (https://github.com/gnustep/libobjc2/pull/438).
static void QCKTestMethod(QuickSpec *spec, SEL _cmd) {
	QCKExample *example = QCKExamplesByTestMethod[NSStringFromClass(spec.class)][NSStringFromSelector(_cmd)];
	QCKRunExample(example, spec);
}

@implementation QuickSpec

+ (QuickSpec *)current {
	return QCKCurrentSpec;
}

- (void)spec {
}

+ (NSArray *)testInvocations {
	QCKBuildWorldIfNeeded();

	NSArray<NSString *> *names = QCKTestMethodNames[NSStringFromClass(self)];
	NSMutableArray<NSInvocation *> *invocations = [NSMutableArray arrayWithCapacity:names.count];
	for (NSString *name in names) {
		SEL selector = NSSelectorFromString(name);
		NSInvocation *invocation = [NSInvocation invocationWithMethodSignature:[self instanceMethodSignatureForSelector:selector]];
		invocation.selector = selector;
		[invocations addObject:invocation];
	}
	return invocations;
}

// A known failure's failures are logged, not recorded.
- (void)recordFailureWithDescription:(NSString *)description inFile:(NSString *)filePath atLine:(NSUInteger)lineNumber expected:(BOOL)expected {
	if (self == QCKCurrentSpec && QCKCurrentExample.knownFailure) {
		QCKLogKnownFailure(self, [NSString stringWithFormat:@"%@:%lu: %@", filePath, (unsigned long)lineNumber, description]);
		return;
	}
	[super recordFailureWithDescription:description inFile:filePath atLine:lineNumber expected:expected];
}

- (void)qck_recordFailureWithDescription:(NSString *)description inFile:(NSString *)file atLine:(NSUInteger)line {
	[super recordFailureWithDescription:description inFile:file atLine:line expected:YES];
}

@end

// Fails if the known failures file lists a test that doesn't exist, e.g.
// because the spec was renamed or the test was removed.
@interface QuickKnownFailures : XCTestCase
@end

@implementation QuickKnownFailures

- (void)testEveryListedTestExists {
	QCKBuildWorldIfNeeded();
	if (QCKKnownFailures == nil) return;

	NSMutableArray<NSString *> *unmatched = [NSMutableArray array];
	for (NSString *name in QCKListedKnownFailures) {
		if (![QCKMatchedKnownFailures containsObject:name]) [unmatched addObject:name];
	}
	if (unmatched.count == 0) return;

	[unmatched sortUsingSelector:@selector(compare:)];
	[self recordFailureWithDescription:[NSString stringWithFormat:@"%@ lists tests that don't exist: %@", QCKKnownFailuresPath, [unmatched componentsJoinedByString:@", "]] inFile:QCKKnownFailuresPath atLine:0 expected:YES];
}

@end

@implementation QuickConfiguration

+ (void)configure:(QCKConfiguration *)configuration {
}

@end

@implementation QCKConfiguration
@end

void qck_beforeSuite(QCKDSLEmptyBlock closure) {
	[QCKBeforeSuiteClosures addObject:[closure copy]];
}

void qck_afterSuite(QCKDSLEmptyBlock closure) {
	[QCKAfterSuiteClosures addObject:[closure copy]];
}

void qck_sharedExamples(NSString *name, QCKDSLSharedExampleBlock closure) {
	if (QCKSharedExamples[name] != nil) {
		[NSException raise:NSInternalInconsistencyException format:@"Shared examples \"%@\" are defined more than once", name];
	}
	QCKSharedExamples[name] = [closure copy];
}

static void QCKGroup(NSString *function, NSString *description, BOOL pending, void (^body)(void)) {
	QCKRequireBuilding(function);

	QCKExampleGroup *group = [[QCKExampleGroup alloc] init];
	group.desc = description;
	group.parent = QCKCurrentGroup;
	group.pending = pending;

	QCKExampleGroup *previous = QCKCurrentGroup;
	QCKCurrentGroup = group;
	@try {
		body();
	}
	@finally {
		QCKCurrentGroup = previous;
	}
}

void qck_describe(NSString *description, QCKDSLEmptyBlock closure) {
	QCKGroup(@"describe", description, NO, closure);
}

void qck_context(NSString *description, QCKDSLEmptyBlock closure) {
	QCKGroup(@"context", description, NO, closure);
}

void qck_xdescribe(NSString *description, QCKDSLEmptyBlock closure) {
	QCKGroup(@"xdescribe", description, YES, closure);
}

void qck_xcontext(NSString *description, QCKDSLEmptyBlock closure) {
	QCKGroup(@"xcontext", description, YES, closure);
}

void qck_beforeEach(QCKDSLEmptyBlock closure) {
	QCKRequireBuilding(@"beforeEach");
	[QCKCurrentGroup.befores addObject:[closure copy]];
}

void qck_afterEach(QCKDSLEmptyBlock closure) {
	QCKRequireBuilding(@"afterEach");
	[QCKCurrentGroup.afters addObject:[closure copy]];
}

static void QCKAddExample(NSString *description, QCKDSLEmptyBlock closure, NSString *file, NSUInteger line, BOOL pending) {
	QCKRequireBuilding(@"it");

	QCKExample *example = [[QCKExample alloc] init];
	example.group = QCKCurrentGroup;
	example.desc = description;
	example.file = file;
	example.line = line;
	example.closure = closure;
	example.pending = pending || QCKCurrentGroup.isPending;
	[QCKCurrentExamples addObject:example];
}

void qck_pending(NSString *description, QCKDSLEmptyBlock closure) {
	QCKAddExample(description, closure, @"", 0, YES);
}

QCKItBlock qck_it_builder(NSString *file, NSUInteger line) {
	return ^(NSString *description, QCKDSLEmptyBlock closure) {
		QCKAddExample(description, closure, file, line, NO);
	};
}

QCKItBlock qck_xit_builder(NSString *file, NSUInteger line) {
	return ^(NSString *description, QCKDSLEmptyBlock closure) {
		QCKAddExample(description, closure, file, line, YES);
	};
}

QCKItBehavesLikeBlock qck_itBehavesLike_builder(NSString *file, NSUInteger line) {
	return ^(NSString *name, QCKDSLSharedExampleContext context) {
		QCKDSLSharedExampleBlock sharedExamples = QCKSharedExamples[name];
		if (sharedExamples == nil) {
			[NSException raise:NSInternalInconsistencyException format:@"%@:%lu: no shared examples named \"%@\"", file, (unsigned long)line, name];
		}

		// Like Quick, the context block is passed on unevaluated, so it's
		// read when the examples run, after their beforeEach blocks.
		QCKGroup(@"itBehavesLike", name, NO, ^{
			sharedExamples(context);
		});
	};
}
