//
//  NSData+RACSupport.m
//  ReactiveObjC
//
//  Created by Josh Abernathy on 5/11/12.
//  Copyright (c) 2012 GitHub, Inc. All rights reserved.
//

#import "NSData+RACSupport.h"
#import "RACReplaySubject.h"
#import "RACScheduler.h"

@implementation NSData (RACSupport)

#ifdef GNUSTEP
+ (RACSignal *)rac_readContentsOfURL:(NSURL *)URL options:(NSUInteger)options scheduler:(RACScheduler *)scheduler {
#else
+ (RACSignal *)rac_readContentsOfURL:(NSURL *)URL options:(NSDataReadingOptions)options scheduler:(RACScheduler *)scheduler {
#endif
	NSCParameterAssert(scheduler != nil);
	
	RACReplaySubject *subject = [RACReplaySubject subject];
	[subject setNameWithFormat:@"+rac_readContentsOfURL: %@ options: %lu scheduler: %@", URL, (unsigned long)options, scheduler];
	
	[scheduler schedule:^{
		NSError *error = nil;
#ifdef GNUSTEP
		// No -initWithContentsOfURL:options:error: on GNUstep; build the error ourselves.
		NSData *data = (URL != nil ? [[NSData alloc] initWithContentsOfURL:URL] : nil);
		if (data == nil) {
			NSMutableDictionary *userInfo = [NSMutableDictionary dictionary];
			if (URL != nil) userInfo[NSURLErrorKey] = URL;
			error = [NSError errorWithDomain:NSCocoaErrorDomain code:NSFileReadUnknownError userInfo:userInfo];
		}
#else
		NSData *data = [[NSData alloc] initWithContentsOfURL:URL options:options error:&error];
#endif
		if (data == nil) {
			[subject sendError:error];
		} else {
			[subject sendNext:data];
			[subject sendCompleted];
		}
	}];
	
	return subject;
}

@end
