JULIAHOME = $(abspath .)
include $(JULIAHOME)/Make.inc

# TODO: Code bundled with Julia should be installed into a versioned directory,
# prefix/share/julia/VERSDIR, so that in the future one can have multiple
# major versions of Julia installed concurrently. Third-party code that
# is not controlled by Pkg should be installed into
# prefix/share/julia/site/VERSDIR (not prefix/share/julia/VERSDIR/site ...
# so that prefix/share/julia/VERSDIR can be overwritten without touching
# third-party code).
VERSDIR = v`cut -d. -f1-2 < VERSION`
INSTALL_F = install -pm644
INSTALL_M = install -pm755

all: default
default: release

# sort is used to remove potential duplicates
DIRS = $(sort $(BUILD)$(bindir) $(BUILD)$(libdir) $(BUILD)$(JL_PRIVATE_LIBDIR) $(BUILD)$(libexecdir) $(BUILD)$(sysconfdir)/julia $(BUILD)$(datarootdir)/julia $(BUILD)$(datarootdir)/man/man1)

$(foreach dir,$(DIRS),$(eval $(call dir_target,$(dir))))
$(foreach link,base test doc examples,$(eval $(call symlink_target,$(link),$(BUILD)$(datarootdir)/julia)))

debug release: | $(DIRS) $(BUILD)$(datarootdir)/julia/base $(BUILD)$(datarootdir)/julia/test $(BUILD)$(datarootdir)/julia/doc $(BUILD)$(datarootdir)/julia/examples $(BUILD)$(sysconfdir)/julia/juliarc.jl
	@$(MAKE) $(QUIET_MAKE) julia-$@
	@export JL_PRIVATE_LIBDIR=$(JL_PRIVATE_LIBDIR) && \
	$(MAKE) $(QUIET_MAKE) LD_LIBRARY_PATH=$(BUILD)$(libdir):$(LD_LIBRARY_PATH) JULIA_EXECUTABLE="$(JULIA_EXECUTABLE_$@)" $(BUILD)$(JL_PRIVATE_LIBDIR)/sys.$(SHLIB_EXT)

julia-debug-symlink:
	@ln -sf $(BUILD)$(bindir)/julia-debug-$(DEFAULT_REPL) julia

julia-release-symlink:
	@ln -sf $(BUILD)$(bindir)/julia-$(DEFAULT_REPL) julia

julia-debug julia-release:
	@-git submodule init --quiet
	@-git submodule update
	@$(MAKE) $(QUIET_MAKE) -C deps
	@$(MAKE) $(QUIET_MAKE) -C src lib$@
	@$(MAKE) $(QUIET_MAKE) -C base
	@$(MAKE) $(QUIET_MAKE) -C ui $@
ifneq ($(OS),WINNT)
ifndef JULIA_VAGRANT_BUILD
	@$(MAKE) $(QUIET_MAKE) $@-symlink
endif
endif

$(BUILD)$(datarootdir)/julia/helpdb.jl: doc/helpdb.jl | $(BUILD)$(datarootdir)/julia
	@cp $< $@

$(BUILD)$(datarootdir)/man/man1/julia.1: doc/man/julia.1 | $(BUILD)$(datarootdir)/julia
	@mkdir -p $(BUILD)$(datarootdir)/man/man1
	@cp $< $@

$(BUILD)$(sysconfdir)/julia/juliarc.jl: etc/juliarc.jl | $(BUILD)$(sysconfdir)/julia
	@cp $< $@
ifeq ($(OS), WINNT)
	@cat ./contrib/windows/juliarc.jl >> $(BUILD)$(sysconfdir)/julia/juliarc.jl
$(BUILD)$(sysconfdir)/julia/juliarc.jl: contrib/windows/juliarc.jl
endif

# use sys.ji if it exists, otherwise run two stages
$(BUILD)$(JL_PRIVATE_LIBDIR)/sys%ji: $(BUILD)$(JL_PRIVATE_LIBDIR)/sys%bc

$(BUILD)$(JL_PRIVATE_LIBDIR)/sys%o: $(BUILD)$(JL_PRIVATE_LIBDIR)/sys%bc
	$(call spawn,$(LLVM_LLC)) -filetype=obj -relocation-model=pic -mattr=-bmi2,-avx2 -o $@ $<

$(BUILD)$(JL_PRIVATE_LIBDIR)/sys%$(SHLIB_EXT): $(BUILD)$(JL_PRIVATE_LIBDIR)/sys%o
	$(CXX) -shared -fPIC -L$(BUILD)$(JL_PRIVATE_LIBDIR) -L$(BUILD)$(libdir) -o $@ $< \
		$$([ $(OS) = Darwin ] && echo -Wl,-undefined,dynamic_lookup || echo -Wl,--unresolved-symbols,ignore-all ) \
		$$([ $(OS) = WINNT ] && echo -ljulia -lssp)

$(BUILD)$(JL_PRIVATE_LIBDIR)/sys0.bc:
	@$(QUIET_JULIA) cd base && \
	$(call spawn,$(JULIA_EXECUTABLE)) --build $(BUILD)$(JL_PRIVATE_LIBDIR)/sys0 sysimg.jl

$(BUILD)$(JL_PRIVATE_LIBDIR)/sys.bc: VERSION base/*.jl base/pkg/*.jl base/linalg/*.jl base/sparse/*.jl $(BUILD)$(datarootdir)/julia/helpdb.jl $(BUILD)$(datarootdir)/man/man1/julia.1 $(BUILD)$(JL_PRIVATE_LIBDIR)/sys0.$(SHLIB_EXT)
	@$(QUIET_JULIA) cd base && \
	$(call spawn,$(JULIA_EXECUTABLE)) --build $(BUILD)$(JL_PRIVATE_LIBDIR)/sys \
		-J$(BUILD)$(JL_PRIVATE_LIBDIR)/$$([ -e $(BUILD)$(JL_PRIVATE_LIBDIR)/sys.ji ] && echo sys.ji || echo sys0.ji) -f sysimg.jl \
		|| (echo "*** This error is usually fixed by running 'make clean'. If the error persists, try 'make cleanall'. ***" && false)

run-julia-debug run-julia-release: run-julia-%:
	$(MAKE) $(QUIET_MAKE) run-julia JULIA_EXECUTABLE="$(JULIA_EXECUTABLE_$*)"
run-julia:
	@$(call spawn,$(JULIA_EXECUTABLE))
run:
	@$(call spawn,$(cmd))

# public libraries, that are installed in $(prefix)/lib
JL_LIBS = julia julia-debug

# private libraries, that are installed in $(prefix)/lib/julia
JL_PRIVATE_LIBS = random suitesparse_wrapper grisu
ifeq ($(USE_SYSTEM_FFTW),0)
JL_PRIVATE_LIBS += fftw3 fftw3f fftw3_threads fftw3f_threads
endif
ifeq ($(USE_SYSTEM_PCRE),0)
JL_PRIVATE_LIBS += pcre
endif
ifeq ($(USE_SYSTEM_OPENLIBM),0)
ifeq ($(USE_SYSTEM_LIBM),0)
JL_PRIVATE_LIBS += openlibm
endif
endif
ifeq ($(USE_SYSTEM_OPENSPECFUN),0)
JL_PRIVATE_LIBS += openspecfun
endif
ifeq ($(USE_SYSTEM_BLAS),0)
JL_PRIVATE_LIBS += openblas
else ifeq ($(USE_SYSTEM_LAPACK),0)
JL_PRIVATE_LIBS += lapack
endif
ifeq ($(USE_SYSTEM_GMP),0)
JL_PRIVATE_LIBS += gmp
endif
ifeq ($(USE_SYSTEM_MPFR),0)
JL_PRIVATE_LIBS += mpfr
endif
ifeq ($(USE_SYSTEM_ARPACK),0)
JL_PRIVATE_LIBS += arpack
endif
ifeq ($(USE_SYSTEM_SUITESPARSE),0)
JL_PRIVATE_LIBS += amd camd ccolamd cholmod colamd umfpack spqr
endif
#ifeq ($(USE_SYSTEM_ZLIB),0)
#JL_PRIVATE_LIBS += z
#endif
ifeq ($(USE_SYSTEM_RMATH),0)
JL_PRIVATE_LIBS += Rmath
endif
ifeq ($(OS),Darwin)
ifeq ($(USE_SYSTEM_BLAS),1)
ifeq ($(USE_SYSTEM_LAPACK),0)
JL_PRIVATE_LIBS += gfortblas
endif
endif
endif

ifeq ($(OS),WINNT)
define std_dll
debug release: | $$(BUILD)/$$(libdir)/lib$(1).dll
$$(BUILD)/$$(libdir)/lib$(1).dll: | $$(BUILD)/$$(libdir)
ifeq ($$(BUILD_OS),$$(OS))
	cp $$(call pathsearch,lib$(1).dll,$$(PATH)) $$(BUILD)/$$(libdir) ;
else
	cp $$(call wine_pathsearch,lib$(1).dll,$$(STD_LIB_PATH)) $$(BUILD)/$$(libdir) ;
endif
JL_LIBS += $(1)
endef
$(eval $(call std_dll,gfortran-3))
$(eval $(call std_dll,quadmath-0))
$(eval $(call std_dll,stdc++-6))
ifeq ($(ARCH),i686)
$(eval $(call std_dll,gcc_s_sjlj-1))
else
$(eval $(call std_dll,gcc_s_seh-1))
endif
ifneq ($(BUILD_OS),WINNT)
$(eval $(call std_dll,ssp-0))
endif
endif

prefix ?= julia-$(JULIA_COMMIT)
install:
	@$(MAKE) $(QUIET_MAKE) release
	@$(MAKE) $(QUIET_MAKE) debug

	mkdir -p $(DESTDIR)$(bindir)
	mkdir -p $(DESTDIR)$(libexecdir)
	mkdir -p $(DESTDIR)$(datarootdir)/julia/site/$(VERSDIR)
	mkdir -p $(DESTDIR)$(datarootdir)/man/man1
	mkdir -p $(DESTDIR)$(includedir)/julia
	mkdir -p $(DESTDIR)$(libdir)
	mkdir -p $(DESTDIR)$(JL_PRIVATE_LIBDIR)
	mkdir -p $(DESTDIR)$(sysconfdir)

	$(INSTALL_M) $(BUILD)$(bindir)/julia* $(DESTDIR)$(bindir)/
ifeq ($(OS),WINNT)
	# $(INSTALL_F) $(BUILD)$(bindir)/llc$(EXE) $(DESTDIR)$(libexecdir) # this needs libLLVM-3.3.$(SHLIB_EXT)
	-$(INSTALL_M) $(BUILD)$(bindir)/*.dll $(BUILD)$(bindir)/*.bat $(DESTDIR)$(bindir)/
else
	-cp -a $(BUILD)$(libexecdir) $(DESTDIR)$(prefix)
	cd $(DESTDIR)$(bindir) && ln -sf julia-$(DEFAULT_REPL) julia
endif
	for suffix in $(JL_LIBS) ; do \
		$(INSTALL_M) $(BUILD)$(libdir)/lib$${suffix}*.$(SHLIB_EXT)* $(DESTDIR)$(JL_PRIVATE_LIBDIR) ; \
	done
	for suffix in $(JL_PRIVATE_LIBS) ; do \
		$(INSTALL_M) $(BUILD)$(libdir)/lib$${suffix}*.$(SHLIB_EXT)* $(DESTDIR)$(JL_PRIVATE_LIBDIR) ; \
	done
ifeq ($(USE_SYSTEM_LIBUV),0)
ifeq ($(OS),WINNT)
	$(INSTALL_M) $(BUILD)$(libdir)/libuv.a $(DESTDIR)$(JL_PRIVATE_LIBDIR)
	$(INSTALL_F) $(BUILD)$(includedir)/tree.h $(DESTDIR)$(includedir)/julia
else
	$(INSTALL_M) $(BUILD)$(libdir)/libuv.a $(DESTDIR)$(JL_PRIVATE_LIBDIR)
endif
	$(INSTALL_F) $(BUILD)$(includedir)/uv* $(DESTDIR)$(includedir)/julia
endif
	$(INSTALL_F) src/julia.h src/support/*.h $(DESTDIR)$(includedir)/julia
	# Copy system image
	$(INSTALL_F) $(BUILD)$(JL_PRIVATE_LIBDIR)/sys.ji $(DESTDIR)$(JL_PRIVATE_LIBDIR)
	$(INSTALL_M) $(BUILD)$(JL_PRIVATE_LIBDIR)/sys.$(SHLIB_EXT) $(DESTDIR)$(JL_PRIVATE_LIBDIR)
	# Copy in all .jl sources as well
	cp -R -L $(BUILD)$(datarootdir)/julia $(DESTDIR)$(datarootdir)/
ifeq ($(OS), WINNT)
	cp $(JULIAHOME)/contrib/windows/*.bat $(DESTDIR)$(prefix)
endif
	# Copy in beautiful new man page!
	$(INSTALL_F) $(BUILD)$(datarootdir)/man/man1/julia.1 $(DESTDIR)$(datarootdir)/man/man1/

	mkdir -p $(DESTDIR)$(sysconfdir)
	cp -R $(BUILD)$(sysconfdir)/julia $(DESTDIR)$(sysconfdir)/


dist:
	rm -fr julia-*.tar.gz julia-*.exe julia-$(JULIA_COMMIT)
ifeq ($(USE_SYSTEM_BLAS),0)
ifneq ($(OPENBLAS_DYNAMIC_ARCH),1)
	@echo OpenBLAS must be rebuilt with OPENBLAS_DYNAMIC_ARCH=1 to use dist target
	@false
endif
endif
ifneq ($(prefix),julia-$(JULIA_COMMIT))
	$(error prefix must not be set for make dist)
endif
	@$(MAKE) install
	cp LICENSE.md julia-$(JULIA_COMMIT)
ifeq ($(OS), Darwin)
	-./contrib/mac/fixup-libgfortran.sh $(DESTDIR)$(JL_PRIVATE_LIBDIR)
endif
	# Copy in juliarc.jl files per-platform for binary distributions as well
	# Note that we don't install to sysconfdir: we always install to $(DESTDIR)$(prefix)/etc.
	# If you want to make a distribution with a hardcoded path, you take care of installation
ifeq ($(OS), Darwin)
	-cat ./contrib/mac/juliarc.jl >> $(DESTDIR)$(prefix)/etc/julia/juliarc.jl
else ifeq ($(OS), WINNT)
	-cat ./contrib/windows/juliarc.jl >> $(DESTDIR)$(prefix)/etc/julia/juliarc.jl
endif

ifeq ($(OS), WINNT)
	[ ! -d dist-extras ] || ( cd dist-extras && \
		cp 7z.exe 7z.dll libexpat-1.dll zlib1.dll ../$(prefix)/bin && \
	    mkdir ../$(prefix)/Git && \
	    7z x PortableGit.7z -o"../$(prefix)/Git" )
	cd $(DESTDIR)$(bindir) && rm -f llvm* llc.exe lli.exe opt.exe LTO.dll bugpoint.exe macho-dump.exe
	./dist-extras/7z a -mx9 -sfx7z.sfx julia-$(JULIA_COMMIT)-$(OS)-$(ARCH).exe julia-$(JULIA_COMMIT)
else
	tar zcvf julia-$(JULIA_COMMIT)-$(OS)-$(ARCH).tar.gz julia-$(JULIA_COMMIT)
endif
	rm -fr julia-$(JULIA_COMMIT)

clean: | $(CLEAN_TARGETS)
	@$(MAKE) -C base clean
	@$(MAKE) -C src clean
	@$(MAKE) -C ui clean
	for repltype in "basic" "readline"; do \
		rm -f $(BUILD)$(bindir)/julia-debug-$${repltype}; \
		rm -f $(BUILD)$(bindir)/julia-$${repltype}; \
	done
	@rm -f julia
	@rm -f *~ *# *.tar.gz
	@rm -fr $(BUILD)$(JL_PRIVATE_LIBDIR)
# Temporarily add this line to the Makefile to remove extras
	@rm -fr $(BUILD)$(datarootdir)/julia/extras

cleanall: clean
	@$(MAKE) -C src clean-flisp clean-support
	@rm -fr $(BUILD)$(libdir)
ifeq ($(OS),WINNT)
	@rm -rf $(BUILD)/lib
endif
	@$(MAKE) -C deps clean-uv

distclean: cleanall
	@$(MAKE) -C deps distclean
	@$(MAKE) -C doc cleanall
	rm -fr $(BUILD)

.PHONY: default debug release julia-debug julia-release \
	test testall testall1 test-* clean distclean cleanall \
	run-julia run-julia-debug run-julia-release run \
	install dist

ifeq ($(VERBOSE),1)
.SILENT:
endif

test: release
	@$(MAKE) $(QUIET_MAKE) -C test default

testall: release
	@$(MAKE) $(QUIET_MAKE) -C test all

testall1: release
	@env JULIA_CPU_CORES=1 $(MAKE) $(QUIET_MAKE) -C test all

test-%: release
	@$(MAKE) $(QUIET_MAKE) -C test $*

perf: release
	@$(MAKE) $(QUIET_MAKE) -C test/perf

perf-%: release
	@$(MAKE) $(QUIET_MAKE) -C test/perf $*

# download target for some hardcoded windows dependencies
.PHONY: win-extras wine_path
win-extras:
	[ -d dist-extras ] || mkdir dist-extras
ifneq ($(BUILD_OS),WINNT)
	cp /usr/lib/p7zip/7z /usr/lib/p7zip/7z.so dist-extras
endif
ifneq (,$(filter $(ARCH), i386 i486 i586 i686))
	cd dist-extras && \
	wget -O 7z920.exe http://downloads.sourceforge.net/sevenzip/7z920.exe && \
	7z x -y 7z920.exe 7z.exe 7z.dll 7z.sfx && \
	wget -O mingw-libexpat.rpm http://download.opensuse.org/repositories/windows:/mingw:/win32/SLE_11_SP2/noarch/mingw32-libexpat-2.0.1-5.1.noarch.rpm && \
	wget -O mingw-zlib.rpm http://download.opensuse.org/repositories/windows:/mingw:/win32/SLE_11_SP2/noarch/mingw32-zlib-1.2.7-2.2.noarch.rpm
else ifeq ($(ARCH),x86_64)
	cd dist-extras && \
	wget -O 7z920-x64.msi http://downloads.sourceforge.net/sevenzip/7z920-x64.msi && \
	7z x -y 7z920-x64.msi _7z.exe _7z.dll _7z.sfx && \
	mv _7z.dll 7z.dll && \
	mv _7z.exe 7z.exe && \
	mv _7z.sfx 7z.sfx && \
	wget -O mingw-libexpat.rpm http://download.opensuse.org/repositories/windows:/mingw:/win64/SLE_11_SP2/noarch/mingw64-libexpat-2.0.1-4.1.noarch.rpm && \
	wget -O mingw-zlib.rpm http://download.opensuse.org/repositories/windows:/mingw:/win64/SLE_11_SP2/noarch/mingw64-zlib-1.2.7-2.2.noarch.rpm
else
	$(error no win-extras target for ARCH=$(ARCH))
endif
	cd dist-extras && \
	chmod a+x 7z.exe && \
	7z x -y mingw-libexpat.rpm -so > mingw-libexpat.cpio && \
	7z e -y mingw-libexpat.cpio && \
	7z x -y mingw-zlib.rpm -so > mingw-zlib.cpio && \
	7z e -y mingw-zlib.cpio && \
	wget -O PortableGit.7z http://msysgit.googlecode.com/files/PortableGit-1.8.3-preview20130601.7z
