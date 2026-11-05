//
//  RACCFShims.m
//  RACObjC
//
//  GNUstep build only: Foundation-based implementations of the CoreFoundation
//  subset declared in RACGNUstepPrefix.h. Compiled with ARC. All symbols are
//  hidden, so they never clash with a real CoreFoundation (e.g. gnustep-corebase).
//

#import "RACGNUstepPrefix.h"

const CFArrayCallBacks kCFTypeArrayCallBacks = { 0, NULL, NULL, NULL, NULL };

#pragma mark Retain / Release

CFTypeRef CFRetain(CFTypeRef cf) {
	if (cf == NULL) return NULL;
	return (__bridge_retained CFTypeRef)(__bridge id)cf;
}

void CFRelease(CFTypeRef cf) {
	if (cf == NULL) return;
	id object = (__bridge_transfer id)cf;
	(void)object;
}

CFStringRef CFCopyDescription(CFTypeRef cf) {
	if (cf == NULL) return NULL;
	return (__bridge_retained CFStringRef)[(__bridge id)cf description];
}

CFComparisonResult CFDateCompare(CFDateRef date1, CFDateRef date2, void *context) {
	return (CFComparisonResult)[(__bridge NSDate *)date1 compare:(__bridge NSDate *)date2];
}

#pragma mark CFArray

// Elements are always retained (like kCFTypeArrayCallBacks); callbacks are ignored.
CFMutableArrayRef CFArrayCreateMutable(CFAllocatorRef allocator, CFIndex capacity, const CFArrayCallBacks *callBacks) {
	return (__bridge_retained CFMutableArrayRef)[[NSMutableArray alloc] initWithCapacity:(NSUInteger)MAX(capacity, 0)];
}

CFIndex CFArrayGetCount(CFArrayRef array) {
	return (CFIndex)[(__bridge NSArray *)array count];
}

const void *CFArrayGetValueAtIndex(CFArrayRef array, CFIndex index) {
	return (__bridge const void *)[(__bridge NSArray *)array objectAtIndex:(NSUInteger)index];
}

void CFArrayAppendValue(CFMutableArrayRef array, const void *value) {
	[(__bridge NSMutableArray *)array addObject:(__bridge id)value];
}

void CFArrayAppendArray(CFMutableArrayRef array, CFArrayRef otherArray, CFRange range) {
	NSArray *source = (__bridge NSArray *)otherArray;
	NSRange subrange = NSMakeRange((NSUInteger)range.location, (NSUInteger)range.length);
	[(__bridge NSMutableArray *)array addObjectsFromArray:[source subarrayWithRange:subrange]];
}

void CFArrayRemoveValueAtIndex(CFMutableArrayRef array, CFIndex index) {
	[(__bridge NSMutableArray *)array removeObjectAtIndex:(NSUInteger)index];
}

void CFArrayApplyFunction(CFArrayRef array, CFRange range, CFArrayApplierFunction applier, void *context) {
	NSArray *values = (__bridge NSArray *)array;
	for (CFIndex i = range.location; i < range.location + range.length; i++) {
		applier((__bridge const void *)values[(NSUInteger)i], context);
	}
}

#pragma mark CFBinaryHeap

// A minimal priority queue: an array kept sorted by the compare callback.
// Equal elements keep insertion order. Elements are always retained.
__attribute__((visibility("hidden")))
@interface RACCFBinaryHeapShim : NSObject {
@public
	NSMutableArray *_values;
	CFComparisonResult (*_compare)(const void *, const void *, void *);
	void *_info;
}
@end

@implementation RACCFBinaryHeapShim
@end

CFBinaryHeapRef CFBinaryHeapCreate(CFAllocatorRef allocator, CFIndex capacity, const CFBinaryHeapCallBacks *callBacks, const CFBinaryHeapCompareContext *compareContext) {
	NSCParameterAssert(callBacks != NULL && callBacks->compare != NULL);

	RACCFBinaryHeapShim *heap = [[RACCFBinaryHeapShim alloc] init];
	heap->_values = [[NSMutableArray alloc] initWithCapacity:(NSUInteger)MAX(capacity, 0)];
	heap->_compare = callBacks->compare;
	heap->_info = (compareContext != NULL ? compareContext->info : NULL);

	return (__bridge_retained CFBinaryHeapRef)heap;
}

void CFBinaryHeapAddValue(CFBinaryHeapRef heapRef, const void *value) {
	RACCFBinaryHeapShim *heap = (__bridge RACCFBinaryHeapShim *)heapRef;
	NSMutableArray *values = heap->_values;

	// Binary search for the first element greater than the new value.
	NSUInteger low = 0, high = values.count;
	while (low < high) {
		NSUInteger mid = low + (high - low) / 2;
		if (heap->_compare((__bridge const void *)values[mid], value, heap->_info) == kCFCompareGreaterThan) {
			high = mid;
		} else {
			low = mid + 1;
		}
	}

	[values insertObject:(__bridge id)value atIndex:low];
}

Boolean CFBinaryHeapGetMinimumIfPresent(CFBinaryHeapRef heapRef, const void **value) {
	RACCFBinaryHeapShim *heap = (__bridge RACCFBinaryHeapShim *)heapRef;
	if (heap->_values.count == 0) return 0;

	if (value != NULL) *value = (__bridge const void *)heap->_values[0];
	return 1;
}

void CFBinaryHeapRemoveMinimumValue(CFBinaryHeapRef heapRef) {
	RACCFBinaryHeapShim *heap = (__bridge RACCFBinaryHeapShim *)heapRef;
	if (heap->_values.count > 0) [heap->_values removeObjectAtIndex:0];
}
