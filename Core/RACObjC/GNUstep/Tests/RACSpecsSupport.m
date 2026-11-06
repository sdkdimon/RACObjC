//
//  RACSpecsSupport.m
//  RACObjC
//
//  GNUstep only, linked into the spec bundle.
//
//  Adds methods gnustep-base doesn't have, each only if it's missing:
//
//  -[NSObject mutableOrderedSetValueForKey:] and ...ForKeyPath: return a
//  proxy that behaves like Apple's for a property without indexed accessors:
//  every change sends one KVO notification with its kind and indexes
//  (willChange:valuesAtIndexes:forKey:). A mutable value is changed in place;
//  otherwise a changed copy is stored through the class's own setter, which
//  KVO doesn't override (its override lives in a subclass that -class hides),
//  so there's no second, nested "setting" notification.
//
//  -[NSUserDefaults initWithSuiteName:]: gnustep-base has no suites, so this
//  is -init with the standard search list, and the name is ignored. Writes go
//  to the process's own domain; `gmake check` runs the specs with a temporary
//  HOME, so they never reach the user's defaults.
//

#import <Foundation/Foundation.h>
#import <objc/runtime.h>

@interface NSUserDefaults (RACSpecsSuites)

// Named in the init family so ARC treats it like -initWithSuiteName:.
- (instancetype)initRACSpecsWithSuiteName:(NSString *)suiteName;

@end

@implementation NSUserDefaults (RACSpecsSuites)

- (instancetype)initRACSpecsWithSuiteName:(NSString *)suiteName {
	self = [self init];
	// A GNUstep -init instance has an empty search list, so it can't read what
	// it writes. The standard one includes the process's domain.
	[self setSearchList:NSUserDefaults.standardUserDefaults.searchList];
	return self;
}

@end

@interface RACSpecsOrderedSetProxy : NSMutableOrderedSet

- (instancetype)initWithObject:(NSObject *)object key:(NSString *)key;

@end

// Plain functions rather than block IMPs, which libobjc2 has few of (see
// QuickNimble/Quick.m).
static NSMutableOrderedSet *RACSpecsMutableOrderedSetValueForKey(NSObject *self, SEL _cmd, NSString *key) {
	return [[RACSpecsOrderedSetProxy alloc] initWithObject:self key:key];
}

static NSMutableOrderedSet *RACSpecsMutableOrderedSetValueForKeyPath(NSObject *self, SEL _cmd, NSString *keyPath) {
	NSRange dot = [keyPath rangeOfString:@"."];
	if (dot.location == NSNotFound) return [self mutableOrderedSetValueForKey:keyPath];

	NSObject *next = [self valueForKey:[keyPath substringToIndex:dot.location]];
	return [next mutableOrderedSetValueForKeyPath:[keyPath substringFromIndex:NSMaxRange(dot)]];
}

@implementation RACSpecsOrderedSetProxy {
	NSObject *_object;
	NSString *_key;
}

+ (void)load {
	SEL selector = @selector(mutableOrderedSetValueForKey:);
	if (class_getInstanceMethod(NSObject.class, selector) == NULL) {
		class_addMethod(NSObject.class, selector, (IMP)RACSpecsMutableOrderedSetValueForKey, "@@:@");
	}

	selector = @selector(mutableOrderedSetValueForKeyPath:);
	if (class_getInstanceMethod(NSObject.class, selector) == NULL) {
		class_addMethod(NSObject.class, selector, (IMP)RACSpecsMutableOrderedSetValueForKeyPath, "@@:@");
	}

	selector = @selector(initWithSuiteName:);
	if (class_getInstanceMethod(NSUserDefaults.class, selector) == NULL) {
		Method method = class_getInstanceMethod(NSUserDefaults.class, @selector(initRACSpecsWithSuiteName:));
		class_addMethod(NSUserDefaults.class, selector, method_getImplementation(method), method_getTypeEncoding(method));
	}
}

- (instancetype)initWithObject:(NSObject *)object key:(NSString *)key {
	if ((self = [super init])) {
		_object = object;
		_key = [key copy];
	}
	return self;
}

// NSOrderedSet's initializers end here; the proxy stores nothing itself.
- (instancetype)initWithObjects:(const id [])objects count:(NSUInteger)count {
	return self;
}

- (NSOrderedSet *)value {
	return [_object valueForKey:_key] ?: [NSOrderedSet orderedSet];
}

- (NSUInteger)count {
	return self.value.count;
}

- (id)objectAtIndex:(NSUInteger)index {
	return [self.value objectAtIndex:index];
}

- (NSUInteger)indexOfObject:(id)object {
	return [self.value indexOfObject:object];
}

// Stores a new value without a KVO notification of its own: through the
// class's own setter if there is one, else the instance variable.
- (void)storeValue:(NSOrderedSet *)value {
	NSString *setterName = [NSString stringWithFormat:@"set%@%@:", [_key substringToIndex:1].uppercaseString, [_key substringFromIndex:1]];
	SEL setter = NSSelectorFromString(setterName);
	Class cls = [_object class];
	if ([cls instancesRespondToSelector:setter]) {
		void (*setterIMP)(id, SEL, id) = (void (*)(id, SEL, id))class_getMethodImplementation(cls, setter);
		setterIMP(_object, setter, value);
		return;
	}

	Ivar ivar = class_getInstanceVariable(cls, [@"_" stringByAppendingString:_key].UTF8String) ?: class_getInstanceVariable(cls, _key.UTF8String);
	if (ivar != NULL) {
		object_setIvar(_object, ivar, value);
		return;
	}

	[_object setValue:value forKey:_key];
}

- (void)change:(NSKeyValueChange)kind atIndexes:(NSIndexSet *)indexes with:(void (^)(NSMutableOrderedSet *set))mutation {
	[_object willChange:kind valuesAtIndexes:indexes forKey:_key];

	id value = [_object valueForKey:_key];
	if ([value isKindOfClass:NSMutableOrderedSet.class]) {
		mutation(value);
	} else {
		NSMutableOrderedSet *newValue = value != nil ? [value mutableCopy] : [NSMutableOrderedSet orderedSet];
		mutation(newValue);
		[self storeValue:newValue];
	}

	[_object didChange:kind valuesAtIndexes:indexes forKey:_key];
}

- (void)insertObject:(id)object atIndex:(NSUInteger)index {
	if ([self.value containsObject:object]) return;

	[self change:NSKeyValueChangeInsertion atIndexes:[NSIndexSet indexSetWithIndex:index] with:^(NSMutableOrderedSet *set) {
		[set insertObject:object atIndex:index];
	}];
}

- (void)removeObjectAtIndex:(NSUInteger)index {
	[self change:NSKeyValueChangeRemoval atIndexes:[NSIndexSet indexSetWithIndex:index] with:^(NSMutableOrderedSet *set) {
		[set removeObjectAtIndex:index];
	}];
}

- (void)replaceObjectAtIndex:(NSUInteger)index withObject:(id)object {
	[self change:NSKeyValueChangeReplacement atIndexes:[NSIndexSet indexSetWithIndex:index] with:^(NSMutableOrderedSet *set) {
		[set replaceObjectAtIndex:index withObject:object];
	}];
}

@end
