# Tests for the GNUstep build of RACObjC.
# Run from Core/RACObjC with:  gmake check
#
#   RACSmokeTests        a tool with a few dozen checks and no dependencies
#   RACObjCSpecs.bundle  the specs in Core/RACObjCTests, run by the `xctest`
#                        tool of gnustep/tools-xctest, with the Quick/Nimble
#                        stand-in in QuickNimble/

include $(GNUSTEP_MAKEFILES)/common.make

TOOL_NAME = RACSmokeTests
RACSmokeTests_OBJC_FILES = RACSmokeTests.m
RACSmokeTests_TOOL_LIBS = -lRACObjC -ldispatch

# The specs are compiled from copies in derived_src/specs, where
# `@import Quick;` and `@import Nimble;` become #imports of QuickNimble/.
# A #line directive keeps the file names and line numbers of the originals.
RAC_SPECS_SRC = $(abspath ../../../RACObjCTests)
RAC_SPECS_DIR = derived_src/specs
# Specs that can't run on GNUstep.
RAC_SPECS_EXCLUDED =
RAC_SPECS = $(filter-out $(RAC_SPECS_EXCLUDED),$(notdir $(wildcard $(RAC_SPECS_SRC)/*.m)))

BUNDLE_NAME = RACObjCSpecs
RACObjCSpecs_OBJC_FILES = QuickNimble/Quick.m QuickNimble/Nimble.m RACSpecsSupport.m $(addprefix $(RAC_SPECS_DIR)/,$(RAC_SPECS))
RACObjCSpecs_BUNDLE_LIBS = -lXCTest -lRACObjC -ldispatch
# gnustep-make wants a relative path here.
RACObjCSpecs_RESOURCE_FILES = ../../../RACObjCTests/test-data.json
RACObjCSpecs_OBJCFLAGS = -include RACSpecsPrefix.h
# Specs import private library headers too, by their bare names.
RACObjCSpecs_INCLUDE_DIRS = -IQuickNimble -I$(RAC_SPECS_DIR) -I../shim -I../../derived_src/include/RACObjC

ADDITIONAL_OBJCFLAGS += -fobjc-arc -fblocks
# Built-but-not-installed library and its headers.
ADDITIONAL_INCLUDE_DIRS += -I../../derived_src/include
ADDITIONAL_LIB_DIRS += -L../../obj

include $(GNUSTEP_MAKEFILES)/tool.make
include $(GNUSTEP_MAKEFILES)/bundle.make

# Rewrites only files whose copy changed, so unchanged specs aren't rebuilt.
before-all::
	@mkdir -p $(RAC_SPECS_DIR)
	@for f in $(RAC_SPECS_SRC)/*.m $(RAC_SPECS_SRC)/*.h; do \
		out="$(RAC_SPECS_DIR)/$${f##*/}"; \
		{ printf '#line 1 "%s"\n' "$$f"; \
		  sed -e 's|^@import Quick;|#import <Quick/Quick.h>|' -e 's|^@import Nimble;|#import <Nimble/Nimble.h>|' "$$f"; } > "$$out.tmp"; \
		if cmp -s "$$out.tmp" "$$out"; then rm "$$out.tmp"; else mv "$$out.tmp" "$$out"; fi; \
	done

after-clean::
	rm -rf derived_src

# The specs run with a temporary HOME, so the defaults they write (see
# RACSpecsSupport.m) never reach the user's ~/GNUstep/Defaults. Specs listed
# in KnownFailures.md are expected to fail.
check:: all
	LD_LIBRARY_PATH="$(CURDIR)/../../obj:$$LD_LIBRARY_PATH" ./obj/RACSmokeTests
	@home="$$(mktemp -d)" && trap 'rm -rf "$$home"' EXIT && \
		HOME="$$home" QUICK_KNOWN_FAILURES="$(CURDIR)/KnownFailures.md" \
		LD_LIBRARY_PATH="$(CURDIR)/../../obj:$$LD_LIBRARY_PATH" xctest RACObjCSpecs.bundle
