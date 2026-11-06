# GNUmakefile: build RACObjC as a GNUstep library (clang + libobjc2 + libdispatch),
# e.g. on FreeBSD or Linux. Apple platforms keep using CocoaPods / Xcode.
#
#   gmake                 build obj/libRACObjC.so
#   gmake install         install the library and <RACObjC/...> headers
#                         (GNUSTEP_INSTALLATION_DOMAIN=USER installs into ~/GNUstep)
#   gmake check           build and run the GNUstep smoke tests (GNUstep/Tests)
#
# Everything GNUstep-specific lives in GNUstep/ (outside Classes/, so the
# podspec never picks it up).

include $(GNUSTEP_MAKEFILES)/common.make

LIBRARY_NAME = libRACObjC
libRACObjC_VERSION = 3.3.0

RAC_SOURCES := $(shell find Classes -name '*.m' | LC_ALL=C sort)
RAC_HEADERS := $(shell find Classes -name '*.h' | LC_ALL=C sort) RACObjC.h
RAC_PRIVATE_HEADERS := $(shell find Classes \( -name '*Private.h' -o -name 'EXTRuntimeExtensions.h' -o -name 'RACEmpty*.h' \) | LC_ALL=C sort)
RAC_PUBLIC_HEADERS := $(filter-out $(RAC_PRIVATE_HEADERS),$(RAC_HEADERS))

# Every header is symlinked flat into derived_src/include/RACObjC, so both
# #import "RACSignal.h" and #import <RACObjC/RACSignal.h> resolve like in Xcode.
RAC_INCLUDE_DIR = derived_src/include

libRACObjC_OBJC_FILES = $(RAC_SOURCES) \
	GNUstep/RACCFShims.m \
	GNUstep/RACObjCVersion.m \
	GNUstep/RACSwizzleTable.m
libRACObjC_C_FILES = GNUstep/RACObjCMsgForward.c

libRACObjC_HEADER_FILES_DIR = $(RAC_INCLUDE_DIR)/RACObjC
libRACObjC_HEADER_FILES = $(notdir $(RAC_PUBLIC_HEADERS))
libRACObjC_HEADER_FILES_INSTALL_DIR = RACObjC

libRACObjC_LIBRARIES_DEPEND_UPON += -ldispatch $(FND_LIBS) $(OBJC_LIBS)

ADDITIONAL_OBJCFLAGS += -fobjc-arc -fblocks -include GNUstep/RACGNUstepPrefix.h
ADDITIONAL_INCLUDE_DIRS += -IGNUstep -IGNUstep/shim -I$(RAC_INCLUDE_DIR) -I$(RAC_INCLUDE_DIR)/RACObjC

include $(GNUSTEP_MAKEFILES)/library.make

before-all::
	@mkdir -p $(RAC_INCLUDE_DIR)/RACObjC
	@for h in $(RAC_HEADERS); do ln -sf "$(CURDIR)/$$h" $(RAC_INCLUDE_DIR)/RACObjC/; done

after-clean::
	rm -rf $(RAC_INCLUDE_DIR)
	-rmdir derived_src 2>/dev/null
	$(MAKE) -C GNUstep/Tests clean

check:: all
	$(MAKE) -C GNUstep/Tests check
