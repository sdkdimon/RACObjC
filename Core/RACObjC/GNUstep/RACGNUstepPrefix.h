//
//  RACGNUstepPrefix.h
//  RACObjC
//
//  GNUstep build only. Force-included (-include) into every RACObjC source
//  file by GNUmakefile. On Apple platforms CoreFoundation provides all of
//  this; GNUstep's Foundation does not ship CoreFoundation, so this declares
//  the small CF subset RACObjC uses. The functions are implemented on top of
//  Foundation in RACCFShims.m and are hidden inside the library.
//

#ifndef RAC_GNUSTEP_PREFIX_H
#define RAC_GNUSTEP_PREFIX_H

// libobjc2 has no imp_implementationWithBlock() unless it's built with its
// embedded blocks runtime (gnustep/libobjc2#355), and it hands out only 128
// (aarch64) or 256 (x86_64) block IMPs per process (gnustep/libobjc2#438).
// Until both are fixed, the methods RACObjC swizzles are plain functions on
// GNUstep (RACSwizzleTable.h). Build with -DRAC_USE_BLOCK_IMPS=1 to use block
// IMPs, as on Apple platforms.
#ifndef RAC_USE_BLOCK_IMPS
#define RAC_USE_BLOCK_IMPS 0
#endif

#ifdef __OBJC__

#import <Foundation/Foundation.h>

#define RAC_CF_SHIM __attribute__((visibility("hidden")))

typedef const void *CFTypeRef;
typedef const void *CFAllocatorRef;
typedef const void *CFStringRef;
typedef const void *CFDateRef;
typedef long CFIndex;
typedef unsigned char Boolean;

typedef struct {
	CFIndex location;
	CFIndex length;
} CFRange;

static inline CFRange CFRangeMake(CFIndex location, CFIndex length) {
	CFRange range = { location, length };
	return range;
}

typedef enum {
	kCFCompareLessThan = -1,
	kCFCompareEqualTo = 0,
	kCFCompareGreaterThan = 1
} CFComparisonResult;

// Retain / release / ARC bridging

#if __has_feature(objc_arc)
static inline CFTypeRef CFBridgingRetain(id object) {
	return (__bridge_retained CFTypeRef)object;
}

static inline id CFBridgingRelease(CFTypeRef cf) {
	return (__bridge_transfer id)cf;
}
#endif

RAC_CF_SHIM CFTypeRef CFRetain(CFTypeRef cf);
RAC_CF_SHIM void CFRelease(CFTypeRef cf);
RAC_CF_SHIM CFStringRef CFCopyDescription(CFTypeRef cf);
RAC_CF_SHIM CFComparisonResult CFDateCompare(CFDateRef date1, CFDateRef date2, void *context);

// CFArray (RACCompoundDisposable)

typedef const void *CFArrayRef;
typedef void *CFMutableArrayRef;

typedef const void *(*CFArrayRetainCallBack)(CFAllocatorRef allocator, const void *value);
typedef void (*CFArrayReleaseCallBack)(CFAllocatorRef allocator, const void *value);
typedef CFStringRef (*CFArrayCopyDescriptionCallBack)(const void *value);
typedef Boolean (*CFArrayEqualCallBack)(const void *value1, const void *value2);

typedef struct {
	CFIndex version;
	CFArrayRetainCallBack retain;
	CFArrayReleaseCallBack release;
	CFArrayCopyDescriptionCallBack copyDescription;
	CFArrayEqualCallBack equal;
} CFArrayCallBacks;

// The shim always retains its elements, like kCFTypeArrayCallBacks.
RAC_CF_SHIM extern const CFArrayCallBacks kCFTypeArrayCallBacks;

typedef void (*CFArrayApplierFunction)(const void *value, void *context);

RAC_CF_SHIM CFMutableArrayRef CFArrayCreateMutable(CFAllocatorRef allocator, CFIndex capacity, const CFArrayCallBacks *callBacks);
RAC_CF_SHIM CFIndex CFArrayGetCount(CFArrayRef array);
RAC_CF_SHIM const void *CFArrayGetValueAtIndex(CFArrayRef array, CFIndex index);
RAC_CF_SHIM void CFArrayAppendValue(CFMutableArrayRef array, const void *value);
RAC_CF_SHIM void CFArrayAppendArray(CFMutableArrayRef array, CFArrayRef otherArray, CFRange range);
RAC_CF_SHIM void CFArrayRemoveValueAtIndex(CFMutableArrayRef array, CFIndex index);
RAC_CF_SHIM void CFArrayApplyFunction(CFArrayRef array, CFRange range, CFArrayApplierFunction applier, void *context);

// CFBinaryHeap (RACTestScheduler)

typedef void *CFBinaryHeapRef;

typedef struct {
	CFIndex version;
	const void *(*retain)(CFAllocatorRef allocator, const void *ptr);
	void (*release)(CFAllocatorRef allocator, const void *ptr);
	CFStringRef (*copyDescription)(const void *ptr);
	CFComparisonResult (*compare)(const void *ptr1, const void *ptr2, void *context);
} CFBinaryHeapCallBacks;

typedef struct {
	CFIndex version;
	void *info;
	const void *(*retain)(const void *info);
	void (*release)(const void *info);
	CFStringRef (*copyDescription)(const void *info);
} CFBinaryHeapCompareContext;

RAC_CF_SHIM CFBinaryHeapRef CFBinaryHeapCreate(CFAllocatorRef allocator, CFIndex capacity, const CFBinaryHeapCallBacks *callBacks, const CFBinaryHeapCompareContext *compareContext);
RAC_CF_SHIM void CFBinaryHeapAddValue(CFBinaryHeapRef heap, const void *value);
RAC_CF_SHIM Boolean CFBinaryHeapGetMinimumIfPresent(CFBinaryHeapRef heap, const void **value);
RAC_CF_SHIM void CFBinaryHeapRemoveMinimumValue(CFBinaryHeapRef heap);

#endif // __OBJC__

#endif // RAC_GNUSTEP_PREFIX_H
