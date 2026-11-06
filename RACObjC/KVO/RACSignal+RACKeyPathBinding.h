//
//  RACSignal+RACKeyPathBinding.h
//  ReactiveObjC
//
//  Created by Justin Spahr-Summers on 2012-09-06.
//  Copyright (c) 2012 GitHub, Inc. All rights reserved.
//
//  Part of RACSignal (Operations) until RACObjC was split into modules: these
//  methods need -rac_deallocDisposable (Deallocation), so they're in KVO,
//  next to RAC(), which is built on them.
//

#import <Foundation/Foundation.h>
#import <RACObjC/RACSignal.h>

@class RACDisposable;

NS_ASSUME_NONNULL_BEGIN

@interface RACSignal (RACKeyPathBinding)

/// Invokes -setKeyPath:onObject:nilValue: with `nil` for the nil value.
///
/// WARNING: Under certain conditions, this method is known to be thread-unsafe.
///          See the description in -setKeyPath:onObject:nilValue:.
- (RACDisposable *)setKeyPath:(NSString *)keyPath onObject:(NSObject *)object;

/// Binds the receiver to an object, automatically setting the given key path on
/// every `next`. When the signal completes, the binding is automatically
/// disposed of.
///
/// WARNING: Under certain conditions, this method is known to be thread-unsafe.
///          A crash can result if `object` is deallocated concurrently on
///          another thread within a window of time between a value being sent
///          on this signal and immediately prior to the invocation of
///          -setValue:forKeyPath:, which sets the property. To prevent this,
///          ensure `object` is deallocated on the same thread the receiver
///          sends on, or ensure that the returned disposable is disposed of
///          before `object` deallocates.
///          See https://github.com/ReactiveCocoa/ReactiveCocoa/pull/1184
///
/// Sending an error on the signal is considered undefined behavior, and will
/// generate an assertion failure in Debug builds.
///
/// A given key on an object should only have one active signal bound to it at any
/// given time. Binding more than one signal to the same property is considered
/// undefined behavior.
///
/// keyPath  - The key path to update with `next`s from the receiver.
/// object   - The object that `keyPath` is relative to.
/// nilValue - The value to set at the key path whenever `nil` is sent by the
///            receiver. This may be nil when binding to object properties, but
///            an NSValue should be used for primitive properties, to avoid an
///            exception if `nil` is sent (which might occur if an intermediate
///            object is set to `nil`).
///
/// Returns a disposable which can be used to terminate the binding.
- (RACDisposable *)setKeyPath:(NSString *)keyPath onObject:(NSObject *)object nilValue:(nullable id)nilValue;

@end

NS_ASSUME_NONNULL_END
