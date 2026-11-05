# Smoke tests for the GNUstep build of RACObjC.
# Run from Core/RACObjC with:  gmake check

include $(GNUSTEP_MAKEFILES)/common.make

TOOL_NAME = RACSmokeTests
RACSmokeTests_OBJC_FILES = RACSmokeTests.m
RACSmokeTests_TOOL_LIBS = -lRACObjC -ldispatch

ADDITIONAL_OBJCFLAGS += -fobjc-arc -fblocks
# Built-but-not-installed library and its public headers.
ADDITIONAL_INCLUDE_DIRS += -I../../derived_src/include
ADDITIONAL_LIB_DIRS += -L../../obj

include $(GNUSTEP_MAKEFILES)/tool.make

check:: all
	LD_LIBRARY_PATH="$(CURDIR)/../../obj:$$LD_LIBRARY_PATH" ./obj/RACSmokeTests
