JULIAHOME = $(abspath ..)
include $(JULIAHOME)/Make.inc

override CFLAGS += $(JCFLAGS)
override CXXFLAGS += $(JCXXFLAGS)

FLAGS = -Wall -Wno-strict-aliasing -fno-omit-frame-pointer \
	-I$(JULIAHOME)/src -I$(JULIAHOME)/src/support -I$(BUILD)$(INCLUDEDIR)

DEBUGFLAGS += $(FLAGS)
SHIPFLAGS += $(FLAGS)
JLDFLAGS += $(LDFLAGS) $(NO_WHOLE_ARCHIVE) $(call exec,$(LLVM_CONFIG) --ldflags) $(OSLIBS) $(RPATH)

ifeq ($(USE_SYSTEM_LIBM),0)
ifneq ($(UNTRUSTED_SYSTEM_LIBM),0)
JLDFLAGS += $(WHOLE_ARCHIVE) $(BUILD)$(JL_LIBDIR)/libopenlibm.a $(NO_WHOLE_ARCHIVE)
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
$(BUILD)$(BINDIR)/julia.bat: ${JULIAHOME}/contrib/windows/*.bat
	cp ${JULIAHOME}/contrib/windows/*.bat ${BUILD}$(BINDIR)
julia-release julia-debug: $(BUILD)$(BINDIR)/julia.bat
julia_res.o: $(JULIAHOME)/contrib/windows/julia.rc
	JLVER=`cat ${JULIAHOME}/VERSION` && \
	JLVERi=`echo $$JLVER | perl -nle \
		'/^(\d+)\.?(\d*)\.?(\d*)/ && \
		print int $$1,",",int $$2,",0,",int $$3'` && \
	$(CROSS_COMPILE)windres $< -O coff -o $@ -DJLVER=$$JLVERi -DJLVER_STR=\\\"$$JLVER\\\"
$(BUILD)$(BINDIR)/julia-readline$(EXE): julia_res.o
$(BUILD)$(BINDIR)/julia-debug-readline$(EXE): julia_res.o
$(BUILD)$(BINDIR)/julia-basic$(EXE): julia_res.o
$(BUILD)$(BINDIR)/julia-debug-basic$(EXE): julia_res.o
JLDFLAGS += julia_res.o
endif 

julia-basic: $(BUILD)$(BINDIR)/julia-basic$(EXE)
julia-debug-basic: $(BUILD)$(BINDIR)/julia-debug-basic$(EXE)
julia-readline: $(BUILD)$(BINDIR)/julia-readline$(EXE)
julia-debug-readline: $(BUILD)$(BINDIR)/julia-debug-readline$(EXE)

$(BUILD)$(BINDIR)/julia-basic$(EXE): repl.o repl-basic.o
	@$(call PRINT_LINK, $(CXX) $(LINK_FLAGS) $(SHIPFLAGS) $^ -o $@ -L$(BUILD)$(JL_PRIVATE_LIBDIR) -L$(BUILD)$(JL_LIBDIR) -ljulia $(JLDFLAGS))
$(BUILD)$(BINDIR)/julia-debug-basic$(EXE): repl.do repl-basic.do
	@$(call PRINT_LINK, $(CXX) $(LINK_FLAGS) $(DEBUGFLAGS) $^ -o $@ -L$(BUILD)$(JL_PRIVATE_LIBDIR) -L$(BUILD)$(JL_LIBDIR) -ljulia-debug $(JLDFLAGS))

$(BUILD)$(BINDIR)/julia-readline$(EXE): repl.o repl-readline.o
	@$(call PRINT_LINK, $(CXX) $(LINK_FLAGS) $(SHIPFLAGS) $^ -o $@ $(READLINE) -L$(BUILD)$(JL_PRIVATE_LIBDIR) -L$(BUILD)$(JL_LIBDIR) -ljulia $(JLDFLAGS)) || (echo "*** Please ensure that the ncurses-devel package is installed on your OS, and try again. ***" && false)
$(BUILD)$(BINDIR)/julia-debug-readline$(EXE): repl.do repl-readline.do
	@$(call PRINT_LINK, $(CXX) $(LINK_FLAGS) $(DEBUGFLAGS) $^ -o $@ $(READLINE) -L$(BUILD)$(JL_PRIVATE_LIBDIR) -L$(BUILD)$(JL_LIBDIR) -ljulia-debug $(JLDFLAGS))

clean: | $(CLEAN_TARGETS)
	rm -f *.o *.do
	rm -f $(BUILD)$(BINDIR)/julia-*-basic $(BUILD)$(BINDIR)/julia-*-readline $(BUILD)$(BINDIR)/julia

.PHONY: clean release debug julia-release julia-debug

