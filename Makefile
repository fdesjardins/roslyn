SHELL = /usr/bin/env bash
OS_NAME = $(shell uname -s)
BUILD_CONFIGURATION = Debug
BINARIES_PATH = $(shell pwd)/Binaries
SCRIPTS_PATH = $(shell pwd)/build/scripts
SRC_PATH = $(shell pwd)/src
TOOLSET_SRC_PATH = $(shell pwd)/build/MSBuildToolset
TOOLSET_PATH = $(BINARIES_PATH)/toolset
RESTORE_SEMAPHORE_PATH = $(BINARIES_PATH)/restore.semaphore
BOOTSTRAP_PATH = $(BINARIES_PATH)/Bootstrap
BUILD_LOG_PATH =
HOME_DIR = $(shell cd ~ && pwd)
NUGET_VERSION = 3.5.0-beta2
NUGET_EXE = $(shell pwd)/nuget.exe

MSBUILD_ADDITIONALARGS := /fl /fileloggerparameters:Verbosity=normal /p:Configuration=$(BUILD_CONFIGURATION)

ifeq ($(OS_NAME),Linux)
	MSBUILD_ADDITIONALARGS := $(MSBUILD_ADDITIONALARGS) /p:BaseNuGetRuntimeIdentifier=ubuntu.14.04
	DOTNET_PLATFORM = ubuntu-x64
else ifeq ($(OS_NAME),Darwin)
	MSBUILD_ADDITIONALARGS := $(MSBUILD_ADDITIONALARGS) /p:BaseNuGetRuntimeIdentifier=osx.10.10
	DOTNET_PLATFORM = osx-x64
endif

ifneq ($(BUILD_LOG_PATH),)
	MSBUILD_ADDITIONALARGS := $(MSBUILD_ADDITIONALARGS) /fileloggerparameters:LogFile=$(BUILD_LOG_PATH)
endif

ifeq ($(BOOTSTRAP),true)
	MSBUILD_ARGS = $(MSBUILD_ADDITIONALARGS) /p:CscToolPath=$(BOOTSTRAP_PATH) /p:CscToolExe=csc /p:VbcToolPath=$(BOOTSTRAP_PATH) /p:VbcToolExe=vbc
else
	MSBUILD_ARGS = $(MSBUILD_ADDITIONALARGS) /p:CscToolExe=csc /p:VbcToolExe=vbc
endif

MSBUILD_CMD = $(TOOLSET_PATH)/corerun $(TOOLSET_PATH)/MSBuild.dll $(MSBUILD_ARGS)

.PHONY: all bootstrap test restore toolset nuget

all: $(RESTORE_SEMAPHORE_PATH)
	export HOME=$(HOME_DIR) ; \
	$(MSBUILD_CMD) CrossPlatform.sln

bootstrap: $(TOOLSET_PATH) $(RESTORE_SEMAPHORE_PATH)
	export HOME=$(HOME_DIR) ; \
	$(MSBUILD_CMD) src/Compilers/CSharp/CscCore/CscCore.csproj && \
	$(MSBUILD_CMD) src/Compilers/VisualBasic/VbcCore/VbcCore.csproj && \
	mkdir -p $(BOOTSTRAP_PATH) && \
	cp -f Binaries/$(BUILD_CONFIGURATION)/Exes/CscCore/* $(BOOTSTRAP_PATH) && \
	cp -f Binaries/$(BUILD_CONFIGURATION)/Exes/VbcCore/* $(BOOTSTRAP_PATH) && \
	build/scripts/crossgen.sh $(BOOTSTRAP_PATH) && \
	rm -rf Binaries/$(BUILD_CONFIGURATION)

test:
	build/scripts/tests.sh $(BUILD_CONFIGURATION)

restore: $(NUGET_EXE) $(RESTORE_SEMAPHORE_PATH)

$(RESTORE_SEMAPHORE_PATH): $(TOOLSET_PATH)
	@build/scripts/restore.sh $(TOOLSET_PATH) $(NUGET_EXE) && \
	touch $(RESTORE_SEMAPHORE_PATH)

$(NUGET_EXE):
	curl https://dist.nuget.org/win-x86-commandline/v$(NUGET_VERSION)/NuGet.exe -o $(NUGET_EXE) --create-dirs

nuget: $(NUGET_EXE)

clean:
	@rm -rf Binaries

clean_toolset:
	@rm -rf $(TOOLSET_PATH)

toolset: $(TOOLSET_PATH)

$(TOOLSET_PATH):
	pushd $(TOOLSET_SRC_PATH) ; \
	dotnet publish -o $(TOOLSET_PATH)
