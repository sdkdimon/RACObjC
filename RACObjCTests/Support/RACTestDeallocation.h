//
//  RACTestDeallocation.h
//  RACObjC
//
//  Lets specs of the Core module see when an object is deallocated without
//  -rac_deallocDisposable, which is part of the Deallocation module (it
//  swizzles -dealloc).
//

#import <Foundation/Foundation.h>

NS_ASSUME_NONNULL_BEGIN

/// Calls `block` when `object` is deallocated: an object associated with
/// `object` runs it when it's released, which happens as `object`'s
/// associated objects are released, just after its -dealloc. Don't touch
/// `object` from the block.
FOUNDATION_EXPORT void RACTestOnDeallocation(id object, void (^block)(void));

NS_ASSUME_NONNULL_END
