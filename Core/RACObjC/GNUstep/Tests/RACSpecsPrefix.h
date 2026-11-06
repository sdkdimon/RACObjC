//
//  RACSpecsPrefix.h
//  RACObjC
//
//  GNUstep only. Force-included into the specs (see GNUmakefile). The
//  library's CoreFoundation stand-ins are hidden inside libRACObjC, so this
//  declares the little the specs use.
//

#ifndef RAC_SPECS_PREFIX_H
#define RAC_SPECS_PREFIX_H

#ifdef __OBJC__

#import <Foundation/Foundation.h>

typedef const void *CFTypeRef;

static inline CFTypeRef CFBridgingRetain(id object) {
	return (__bridge_retained CFTypeRef)object;
}

static inline id CFBridgingRelease(CFTypeRef cf) {
	return (__bridge_transfer id)cf;
}

static inline void CFRelease(CFTypeRef cf) {
	(void)(__bridge_transfer id)cf;
}

// Missing from gnustep-base; RACSpecsSupport.m adds them.
@interface NSObject (RACSpecsKeyValueCoding)
- (NSMutableOrderedSet *)mutableOrderedSetValueForKey:(NSString *)key;
- (NSMutableOrderedSet *)mutableOrderedSetValueForKeyPath:(NSString *)keyPath;
@end

@interface NSUserDefaults (RACSpecsSuiteName)
- (instancetype)initWithSuiteName:(NSString *)suiteName;
@end

#endif // __OBJC__

#endif // RAC_SPECS_PREFIX_H
