# Variables
# ---------

ZIG := zig
BC := $(dir $(abspath $(lastword $(MAKEFILE_LIST))))

# Infos
# -----
.PHONY: help

## Display this help screen
help:
	@printf "\e[36m%-35s %s\e[0m\n" "Command" "Usage"
	@sed -n -e '/^## /{'\
		-e 's/## //g;'\
		-e 'h;'\
		-e 'n;'\
		-e 's/:.*//g;'\
		-e 'G;'\
		-e 's/\n/ /g;'\
		-e 'p;}' Makefile | awk '{printf "\033[33m%-35s\033[0m%s\n", $$1, substr($$0,length($$1)+1)}'


# $(ZIG) commands
# ------------
.PHONY: build build-release run run-release shell test bench

## Build in debug mode
build:
	@printf "\e[36mBuilding (debug)...\e[0m\n"
	@$(ZIG) build -Dengine=v8 || (printf "\e[33mBuild ERROR\e[0m\n"; exit 1;)
	@printf "\e[33mBuild OK\e[0m\n"

build-release:
	@printf "\e[36mBuilding (release safe)...\e[0m\n"
	@$(ZIG) build -Doptimize=ReleaseSafe -Dengine=v8 || (printf "\e[33mBuild ERROR\e[0m\n"; exit 1;)
	@printf "\e[33mBuild OK\e[0m\n"

## Run the server
run: build
	@printf "\e[36mRunning...\e[0m\n"
	@./zig-out/bin/browsercore || (printf "\e[33mRun ERROR\e[0m\n"; exit 1;)

## Run a JS shell in release-safe mode
shell:
	@printf "\e[36mBuilding shell...\e[0m\n"
	@$(ZIG) build shell -Dengine=v8 || (printf "\e[33mBuild ERROR\e[0m\n"; exit 1;)

## Test
test:
	@printf "\e[36mTesting...\e[0m\n"
	@$(ZIG) build test -Dengine=v8 || (printf "\e[33mTest ERROR\e[0m\n"; exit 1;)
	@printf "\e[33mTest OK\e[0m\n"

# Install and build required dependencies commands
# ------------
.PHONY: install-submodule
.PHONY: install-lexbor install-jsruntime install-jsruntime-dev
.PHONY: install-dev install

## Install and build dependencies for release
install: install-submodule install-lexbor install-jsruntime

## Install and build dependencies for dev
install-dev: install-submodule install-lexbor install-jsruntime-dev

BC_NS := $(BC)vendor/netsurf
UNAME_S := $(shell uname -s)
ifeq ($(UNAME_S), Darwin)
	ICONV := /opt/homebrew/opt/libiconv
endif
# TODO: add Linux iconv path (I guess it depends on the distro)
# TODO: this way of linking libiconv is not ideal. We should have a more generic way
# and stick to a specif version. Maybe build from source. Anyway not now.
install-netsurf:
	@printf "\e[36mInstalling NetSurf...\e[0m\n" && \
	ls $(ICONV) 1> /dev/null || (printf "\e[33mERROR: you need to install libiconv in your system (on MacOS on with Homebrew)\e[0m\n"; exit 1;) && \
	mkdir -p vendor/netfurf/build && \
	export PREFIX=$(BC_NS) && \
	export LDFLAGS="-L$(ICONV)/lib" && \
	export CFLAGS="-I/$(ICONV)/include -I$(BC_NS)/libparserutils/include -I$(BC_NS)/libhubbub/include -I$(BC_NS)/libwapcaplet/include" && \
	printf "\e[33mInstalling libwapcaplet...\e[0m\n" && \
	cd vendor/netsurf/libwapcaplet && \
	BUILDDIR=$(BC_NS)/build/libwapcaplet make 2> /dev/null && \
	cd ../libparserutils && \
	printf "\e[33mInstalling libparserutils...\e[0m\n" && \
	BUILDDIR=$(BC_NS)/build/libparserutils make 2> /dev/null && \
	cd ../libhubbub && \
	printf "\e[33mInstalling libhubbub...\e[0m\n" && \
	BUILDDIR=$(BC_NS)/build/libhubbub make 2> /dev/null && \
	cd ../libdom && \
	printf "\e[33mInstalling libdom...\e[0m\n" && \
	BUILDDIR=$(BC_NS)/build/libdom make 2> /dev/null && \
	printf "\e[33mRunning libdom example...\e[0m\n" && \
	cd include/dom && \
	rm -f bindings || true && \
	ln -s ../../bindings bindings && \
	cd ../../examples && \
	rm -f a.out || true && \
	clang \
	-I$(ICONV)/include \
	-I$(BC_NS)/libdom/include \
	-I$(BC_NS)/libparserutils/include \
	-I$(BC_NS)/libhubbub/include \
	-I$(BC_NS)/libwapcaplet/include \
	-L$(ICONV)/lib \
	-L$(BC_NS)/build/libdom \
	-L$(BC_NS)/build/libparserutils \
	-L$(BC_NS)/build/libhubbub \
	-L$(BC_NS)/build/libwapcaplet \
	-liconv \
	-ldom \
	-lhubbub \
	-lparserutils \
	-lwapcaplet \
	dom-structure-dump.c && \
	./a.out > /dev/null && \
	printf "\e[36mDone NetSurf $(OS)\e[0m\n"


install-lexbor:
	@mkdir -p vendor/lexbor
	@cd vendor/lexbor && \
	cmake ../lexbor-src -DLEXBOR_BUILD_SHARED=OFF && \
	make

install-jsruntime-dev:
	@cd vendor/jsruntime-lib && \
	make install-dev

install-jsruntime:
	@cd vendor/jsruntime-lib && \
	make install

## Init and update git submodule
install-submodule:
	@git submodule init && \
	git submodule update
