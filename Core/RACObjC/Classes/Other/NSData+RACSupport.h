//
//  NSData+RACSupport.h
//  ReactiveObjC
//
//  Created by Josh Abernathy on 5/11/12.
//  Copyright (c) 2012 GitHub, Inc. All rights reserved.
//

#import <Foundation/Foundation.h>

@class RACScheduler;
@class RACSignal<__covariant ValueType>;

NS_ASSUME_NONNULL_BEGIN

@interface NSData (RACSupport)

// Read the data at the URL using -[NSData initWithContentsOfURL:options:error:].
// Sends the data or the error.
//
// scheduler - cannot be nil.
#ifdef GNUSTEP
// GNUstep's Foundation has no NSDataReadingOptions; `options` is ignored there.
+ (RACSignal<NSData *> *)rac_readContentsOfURL:(nullable NSURL *)URL options:(NSUInteger)options scheduler:(RACScheduler *)scheduler;
#else
+ (RACSignal<NSData *> *)rac_readContentsOfURL:(nullable NSURL *)URL options:(NSDataReadingOptions)options scheduler:(RACScheduler *)scheduler;
#endif

@end

NS_ASSUME_NONNULL_END
