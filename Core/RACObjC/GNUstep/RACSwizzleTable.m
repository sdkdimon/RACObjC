//
//  RACSwizzleTable.m
//  RACObjC
//
//  GNUstep build only. See RACSwizzleTable.h.
//

#import "RACSwizzleTable.h"
#include <stdlib.h>

// This thread's frames, innermost first.
static _Thread_local RACSwizzleFrame *RACSwizzleFrames;

RACSwizzleEntry *RACSwizzleTableAdd(RACSwizzleTable *table, Class cls, IMP original, Class statedClass) {
	RACSwizzleEntry *entry = calloc(1, sizeof(RACSwizzleEntry));
	if (entry == NULL) {
		[NSException raise:NSMallocException format:@"Couldn't allocate a swizzle table entry for %@", cls];
	}

	entry->cls = cls;
	atomic_init(&entry->original, original);
	entry->statedClass = statedClass;

	// Publish the entry only once it's complete.
	RACSwizzleEntry *head = atomic_load_explicit(&table->head, memory_order_relaxed);
	do {
		entry->next = head;
	} while (!atomic_compare_exchange_weak_explicit(&table->head, &head, entry, memory_order_release, memory_order_relaxed));
	return entry;
}

RACSwizzleEntry *RACSwizzleTableFind(const RACSwizzleTable *table, Class start) {
	RACSwizzleEntry *head = atomic_load_explicit(&((RACSwizzleTable *)table)->head, memory_order_acquire);
	for (Class cls = start; cls != Nil; cls = class_getSuperclass(cls)) {
		for (RACSwizzleEntry *entry = head; entry != NULL; entry = entry->next) {
			if (entry->cls == cls) return entry;
		}
	}
	return NULL;
}

RACSwizzleEntry *RACSwizzleTableEntryForCall(const RACSwizzleTable *table, __unsafe_unretained id receiver, const void *argument) {
	const void *receiverPointer = (__bridge const void *)receiver;
	Class start = object_getClass(receiver);
	for (RACSwizzleFrame *frame = RACSwizzleFrames; frame != NULL; frame = frame->previous) {
		if (frame->table == table && frame->receiver == receiverPointer && frame->argument == argument) {
			start = frame->next;
			break;
		}
	}

	RACSwizzleEntry *entry = RACSwizzleTableFind(table, start);
	if (entry == NULL) {
		// The function is only installed after its entry was added, so this
		// means the table and the installed methods disagree.
		NSLog(@"RACObjC: no swizzle table entry for %@ at or above %@", object_getClass(receiver), start);
		abort();
	}
	return entry;
}

void RACSwizzlePushFrame(RACSwizzleFrame *frame, const RACSwizzleTable *table, const RACSwizzleEntry *entry, __unsafe_unretained id receiver, const void *argument) {
	frame->table = table;
	frame->receiver = (__bridge const void *)receiver;
	frame->argument = argument;
	frame->next = class_getSuperclass(entry->cls);
	frame->previous = RACSwizzleFrames;
	RACSwizzleFrames = frame;
}

void RACSwizzlePopFrame(RACSwizzleFrame *frame) {
	RACSwizzleFrames = frame->previous;
}
