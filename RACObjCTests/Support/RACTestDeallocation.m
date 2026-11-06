//
//  RACTestDeallocation.m
//  RACObjC
//

#import "RACTestDeallocation.h"
#import <objc/runtime.h>

@interface RACTestDeallocationSentinel : NSObject

@property (nonatomic, copy) void (^block)(void);

@end

@implementation RACTestDeallocationSentinel

- (void)dealloc {
	if (_block != nil) _block();
}

@end

void RACTestOnDeallocation(id object, void (^block)(void)) {
	RACTestDeallocationSentinel *sentinel = [[RACTestDeallocationSentinel alloc] init];
	sentinel.block = block;

	// Each sentinel is its own key, so an object can have several.
	objc_setAssociatedObject(object, (__bridge const void *)sentinel, sentinel, OBJC_ASSOCIATION_RETAIN_NONATOMIC);
}
