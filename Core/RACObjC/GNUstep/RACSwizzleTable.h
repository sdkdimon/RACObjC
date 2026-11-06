//
//  RACSwizzleTable.h
//  RACObjC
//
//  GNUstep build only, while RAC_USE_BLOCK_IMPS is 0 (see RACGNUstepPrefix.h).
//
//  On Apple platforms RACObjC swizzles -dealloc and, for
//  -rac_signalForSelector:, -forwardInvocation:, -respondsToSelector:, -class
//  and -methodSignatureForSelector:, with block IMPs that capture per-class
//  state. libobjc2 can't always provide those: it has no
//  imp_implementationWithBlock() unless it's built with its embedded blocks
//  runtime (gnustep/libobjc2#355), and it hands out only 128 (aarch64) or 256
//  (x86_64) of them per process (gnustep/libobjc2#438).
//
//  So each of those methods is one plain function instead, and the state the
//  blocks captured lives in a table, one per method:
//
//  - An entry records a swizzled class, the implementation it replaced, and
//    for -class the class to report.
//  - The function finds its entry from the receiver: the closest class in the
//    entry table, starting at the receiver's class.
//  - When the function calls the replaced implementation or super, that can
//    land in the same function for a superclass. Before calling, the function
//    pushes a frame for the receiver (and the call's distinguishing argument),
//    so the nested call starts looking above the class it handled.
//
//  Entries are only added, never removed, and readers don't take a lock.
//

#ifndef RAC_SWIZZLE_TABLE_H
#define RAC_SWIZZLE_TABLE_H

#import <Foundation/Foundation.h>
#import <objc/runtime.h>
#include <stdatomic.h>

typedef struct RACSwizzleEntry RACSwizzleEntry;

struct RACSwizzleEntry {
	Class cls;
	// The implementation that was replaced, or NULL to call super.
	_Atomic(IMP) original;
	// For -class: what the swizzled class reports itself as.
	Class statedClass;
	RACSwizzleEntry *next;
};

typedef struct {
	_Atomic(RACSwizzleEntry *) head;
} RACSwizzleTable;

typedef struct RACSwizzleFrame RACSwizzleFrame;

struct RACSwizzleFrame {
	const RACSwizzleTable *table;
	const void *receiver;
	const void *argument;
	Class next;
	RACSwizzleFrame *previous;
};

// Adds an entry; safe to call from several threads. Add the entry before
// installing the function, so it's there when the function first runs.
__attribute__((visibility("hidden")))
RACSwizzleEntry *RACSwizzleTableAdd(RACSwizzleTable *table, Class cls, IMP original, Class statedClass);

// The entry for the closest class at or above `start`.
__attribute__((visibility("hidden")))
RACSwizzleEntry *RACSwizzleTableFind(const RACSwizzleTable *table, Class start);

// The entry for the call running for `receiver`: the closest class above the
// one an enclosing call for the same receiver and argument is handling on
// this thread, or else at or above the receiver's class.
//
// The receiver is unretained: these run in -dealloc too, where retaining it
// would be wrong (and NSAutoreleasePool raises).
__attribute__((visibility("hidden")))
RACSwizzleEntry *RACSwizzleTableEntryForCall(const RACSwizzleTable *table, __unsafe_unretained id receiver, const void *argument);

// Bracket a call to the replaced implementation or super of `entry`.
__attribute__((visibility("hidden")))
void RACSwizzlePushFrame(RACSwizzleFrame *frame, const RACSwizzleTable *table, const RACSwizzleEntry *entry, __unsafe_unretained id receiver, const void *argument);

__attribute__((visibility("hidden")))
void RACSwizzlePopFrame(RACSwizzleFrame *frame);

#endif // RAC_SWIZZLE_TABLE_H
