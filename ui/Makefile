JULIAHOME = $(abspath ..)
include $(JULIAHOME)/Make.inc

override CFLAGS += $(JCFLAGS)
override CXXFLAGS += $(JCXXFLAGS)

FLAGS = -Wall -Wno-strict-aliasing -fno-omit-frame-pointer \
	-I$(JULIAHOME)/src -I$(JULIAHOME)/src/support -I$(BUILD)$(includedir)

DEBUGFLAGS += $(FLAGS)
SHIPFLAGS += $(FLAGS)
JLDFLAGS += $(LDFLAGS) $(NO_WHOLE_ARCHIVE) $(call exec,$(LLVM_CONFIG) --ldflags) $(OSLIBS) $(RPATH)

ifeq ($(USE_SYSTEM_LIBM),0)
ifneq ($(UNTRUSTED_SYSTEM_LIBM),0)
JLDFLAGS += $(WHOLE_ARCHIVE) $(BUILD)$(libdir)/libopenlibm.a $(NO_WHOLE_ARCHIVE)
endif
endif

julia-release: julia-readline julia-basic
julia-debug: julia-debug-readline julia-debug-basic

release debug:
	$(MAKE) julia-$@

%.o: %.c repl.h
	@$(call PRINT_CC, $(CC) $(CPPFLAGS) $(CFLAGS) $(SHIPFLAGS) -c $< -o $@)
%.do: %.c repl.h
	@$(call PRINT_CC, $(CC) $(CPPFLAGS) $(CFLAGS) $(DEBUGFLAGS) -c $< -o $@)

ifeq ($(OS),WINNT)
$(BUILD)$(bindir)/julia.bat: ${JULIAHOME}/contrib/windows/*.bat
	cp ${JULIAHOME}/contrib/windows/*.bat ${BUILD}$(bindir)
julia-release julia-debug: $(BUILD)$(bindir)/julia.bat
julia_res.o: $(JULIAHOME)/contrib/windows/julia.rc
	JLVER=`cat ${JULIAHOME}/VERSION` && \
	JLVERi=`echo $$JLVER | perl -nle \
		'/^(\d+)\.?(\d*)\.?(\d*)/ && \
		print int $$1,",",int $$2,",0,",int $$3'` && \
	$(CROSS_COMPILE)windres $< -O coff -o $@ -DJLVER=$$JLVERi -DJLVER_STR=\\\"$$JLVER\\\"
$(BUILD)$(bindir)/julia-readline$(EXE): julia_res.o
$(BUILD)$(bindir)/julia-debug-readline$(EXE): julia_res.o
$(BUILD)$(bindir)/julia-basic$(EXE): julia_res.o
$(BUILD)$(bindir)/julia-debug-basic$(EXE): julia_res.o
JLDFLAGS += julia_res.o
endif 

julia-basic: $(BUILD)$(bindir)/julia-basic$(EXE)
julia-debug-basic: $(BUILD)$(bindir)/julia-debug-basic$(EXE)
julia-readline: $(BUILD)$(bindir)/julia-readline$(EXE)
julia-debug-readline: $(BUILD)$(bindir)/julia-debug-readline$(EXE)

$(BUILD)$(bindir)/julia-basic$(EXE): repl.o repl-basic.o
	@$(call PRINT_LINK, $(CXX) $(LINK_FLAGS) $(SHIPFLAGS) $^ -o $@ -L$(BUILD)$(JL_PRIVATE_LIBDIR) -L$(BUILD)$(libdir) -ljulia $(JLDFLAGS))
$(BUILD)$(bindir)/julia-debug-basic$(EXE): repl.do repl-basic.do
	@$(call PRINT_LINK, $(CXX) $(LINK_FLAGS) $(DEBUGFLAGS) $^ -o $@ -L$(BUILD)$(JL_PRIVATE_LIBDIR) -L$(BUILD)$(libdir) -ljulia-debug $(JLDFLAGS))

$(BUILD)$(bindir)/julia-readline$(EXE): repl.o repl-readline.o
	@$(call PRINT_LINK, $(CXX) $(LINK_FLAGS) $(SHIPFLAGS) $^ -o $@ $(READLINE) -L$(BUILD)$(JL_PRIVATE_LIBDIR) -L$(BUILD)$(libdir) -ljulia $(JLDFLAGS)) || (echo "*** Please ensure that the ncurses-devel package is installed on your OS, and try again. ***" && false)
$(BUILD)$(bindir)/julia-debug-readline$(EXE): repl.do repl-readline.do
	@$(call PRINT_LINK, $(CXX) $(LINK_FLAGS) $(DEBUGFLAGS) $^ -o $@ $(READLINE) -L$(BUILD)$(JL_PRIVATE_LIBDIR) -L$(BUILD)$(libdir) -ljulia-debug $(JLDFLAGS))

clean: | $(CLEAN_TARGETS)
	rm -f *.o *.do
	rm -f $(BUILD)$(bindir)/julia-*-basic $(BUILD)$(bindir)/julia-*-readline $(BUILD)$(bindir)/julia

.PHONY: clean release debug julia-release julia-debug

