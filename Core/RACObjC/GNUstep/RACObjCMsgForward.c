//
//  RACObjCMsgForward.c
//  RACObjC
//
//  GNUstep build only.
//
//  Apple's runtime exports _objc_msgForward: an IMP that, when installed as a
//  method, routes every call into -forwardInvocation:. -rac_signalForSelector:
//  relies on it. libobjc2 has no such IMP. It asks a hook
//  (__objc_msg_forward2, set by gnustep-base) for a forwarding IMP on demand,
//  and gnustep-base builds that IMP as a temporary libffi closure that is only
//  valid while the current autorelease pool lives. So it cannot be stored in a
//  method table.
//
//  RACObjCMsgForward is a permanent IMP that does what the runtime does for an
//  unknown selector: it saves the argument registers, asks
//  __objc_msg_forward2(self, _cmd) for the forwarding IMP, restores the
//  registers and tail-calls it. Stack arguments are untouched. Struct returns
//  are not supported, same as on Apple (see RACCheckTypeEncoding).
//

#if defined(GNUSTEP)

#include <objc/runtime.h>
#include <objc/hooks.h>
#include <stdio.h>
#include <stdlib.h>

__attribute__((visibility("hidden"), used))
IMP RACObjCMsgForwardLookup(id self, SEL _cmd) {
	IMP imp = __objc_msg_forward2 != NULL ? __objc_msg_forward2(self, _cmd) : NULL;
	if (imp == NULL) {
		fprintf(stderr, "RACObjC: no forwarding IMP for -%s (is gnustep-base loaded?)\n", sel_getName(_cmd));
		abort();
	}
	return imp;
}

#if defined(__aarch64__)

// AAPCS64: x0-x7 and q0-q7 carry arguments, x8 the indirect result address.
__attribute__((naked))
void RACObjCMsgForward(void) {
	__asm__ volatile(
		"hint #34\n"                    // bti c (no-op without BTI)
		"stp x29, x30, [sp, #-224]!\n"
		"mov x29, sp\n"
		"stp x0, x1, [sp, #16]\n"
		"stp x2, x3, [sp, #32]\n"
		"stp x4, x5, [sp, #48]\n"
		"stp x6, x7, [sp, #64]\n"
		"str x8,     [sp, #80]\n"
		"stp q0, q1, [sp, #96]\n"
		"stp q2, q3, [sp, #128]\n"
		"stp q4, q5, [sp, #160]\n"
		"stp q6, q7, [sp, #192]\n"
		"bl RACObjCMsgForwardLookup\n"  // x0 = self, x1 = _cmd
		"mov x16, x0\n"
		"ldp q6, q7, [sp, #192]\n"
		"ldp q4, q5, [sp, #160]\n"
		"ldp q2, q3, [sp, #128]\n"
		"ldp q0, q1, [sp, #96]\n"
		"ldr x8,     [sp, #80]\n"
		"ldp x6, x7, [sp, #64]\n"
		"ldp x4, x5, [sp, #48]\n"
		"ldp x2, x3, [sp, #32]\n"
		"ldp x0, x1, [sp, #16]\n"
		"ldp x29, x30, [sp], #224\n"
		"br x16\n"
	);
}

#elif defined(__x86_64__)

// System V AMD64: rdi, rsi, rdx, rcx, r8, r9 and xmm0-7 carry arguments,
// al holds the vector register count for variadic calls.
__attribute__((naked))
void RACObjCMsgForward(void) {
	__asm__ volatile(
		"pushq %rbp\n"
		"movq %rsp, %rbp\n"
		"subq $208, %rsp\n"
		"movq %rdi, 0(%rsp)\n"
		"movq %rsi, 8(%rsp)\n"
		"movq %rdx, 16(%rsp)\n"
		"movq %rcx, 24(%rsp)\n"
		"movq %r8, 32(%rsp)\n"
		"movq %r9, 40(%rsp)\n"
		"movq %rax, 48(%rsp)\n"
		"movdqu %xmm0, 64(%rsp)\n"
		"movdqu %xmm1, 80(%rsp)\n"
		"movdqu %xmm2, 96(%rsp)\n"
		"movdqu %xmm3, 112(%rsp)\n"
		"movdqu %xmm4, 128(%rsp)\n"
		"movdqu %xmm5, 144(%rsp)\n"
		"movdqu %xmm6, 160(%rsp)\n"
		"movdqu %xmm7, 176(%rsp)\n"
		"call RACObjCMsgForwardLookup\n"  // rdi = self, rsi = _cmd
		"movq %rax, %r11\n"
		"movdqu 176(%rsp), %xmm7\n"
		"movdqu 160(%rsp), %xmm6\n"
		"movdqu 144(%rsp), %xmm5\n"
		"movdqu 128(%rsp), %xmm4\n"
		"movdqu 112(%rsp), %xmm3\n"
		"movdqu 96(%rsp), %xmm2\n"
		"movdqu 80(%rsp), %xmm1\n"
		"movdqu 64(%rsp), %xmm0\n"
		"movq 48(%rsp), %rax\n"
		"movq 40(%rsp), %r9\n"
		"movq 32(%rsp), %r8\n"
		"movq 24(%rsp), %rcx\n"
		"movq 16(%rsp), %rdx\n"
		"movq 8(%rsp), %rsi\n"
		"movq 0(%rsp), %rdi\n"
		"movq %rbp, %rsp\n"
		"popq %rbp\n"
		"jmp *%r11\n"
	);
}

#else
#error "RACObjCMsgForward: add a trampoline for this CPU (aarch64 and x86_64 are supported)"
#endif

#endif // GNUSTEP
