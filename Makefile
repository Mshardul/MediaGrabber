APP_NAME := MediaGrabber
DERIVED := build
CONFIG ?= Debug
APP := $(abspath $(DERIVED)/Build/Products/$(CONFIG)/$(APP_NAME).app)

.DEFAULT_GOAL := run
.PHONY: fix check fix-all check-all generate build install reinstall remove-copies replace-installed drop-build-app run plugin-test scripts-test test venv tools e2e release release-patch release-minor release-major release-dry-run release-overwrite site-deploy help dead-code

TOOLS_CMD := scripts/fetch-tools.sh
SCRIPT_TEST_CMD = scripts/run-script-tests.sh $(SCRIPT_TEST_ARGS)

## Fetch and install build tools
tools:
	$(TOOLS_CMD)

## Run all script tests
scripts-test:
	$(SCRIPT_TEST_CMD)

## Run end-to-end test on Release build
e2e:
	scripts/make/e2e.sh

GENERATE_CMD := mise exec -- tuist generate --no-open
XCODEBUILD = xcodebuild -workspace $(APP_NAME).xcworkspace -destination 'platform=macOS' -derivedDataPath $(DERIVED)
BUILDLOG = $(PY) -B scripts/buildlog
DROP_APP_CMD = make --no-print-directory drop-build-app DERIVED=$(DERIVED)

## Generate Xcode project
generate:
	$(GENERATE_CMD)

## Build the app [CONFIG=Debug|Release]
build:
	@$(BUILDLOG) build \
		@stage tools $(TOOLS_CMD) \
		@stage generate $(GENERATE_CMD) \
		@stage build $(XCODEBUILD) -scheme $(APP_NAME) -configuration $(CONFIG) build \
		@cleanup $(DROP_APP_CMD)

## Build and install app to /Applications [CONFIG=Debug|Release]
install: build
	@scripts/make/replace-installed.sh

## Build, remove all copies, then install [CONFIG=Debug|Release]
reinstall: build
	scripts/remove-app-copies.sh --keep "$(APP)"
	@scripts/make/replace-installed.sh

## Quit app and remove all copies; saved data and downloads stay
remove-copies:
	scripts/remove-app-copies.sh

## Replace installed app with built product
replace-installed:
	@scripts/make/replace-installed.sh

## Remove built app copies from build directory
drop-build-app:
	@scripts/make/drop-build-app.sh

## Build, install, and launch (default target)
run: install

PY ?= .venv/bin/python
PLUGIN_TEST_CMD = $(PY) -I -B -m unittest discover -s Tests/PluginTests -p 'test_*.py'

## Create or update Python virtual environment
venv:
	scripts/make/venv.sh

## Run plugin tests against bundled yt-dlp
plugin-test:
	$(PLUGIN_TEST_CMD)

## Run all tests (plugin, script, Xcode) [ONLY=AppUnitTests/SomeSuite]
test:
	@$(BUILDLOG) test \
		@tests "plugin tests" $(PLUGIN_TEST_CMD) \
		@tests "script tests" $(SCRIPT_TEST_CMD) \
		@stage generate $(GENERATE_CMD) \
		@tests "Xcode tests" $(XCODEBUILD) -scheme $(APP_NAME)-Workspace \
			-resultBundlePath $(DERIVED)/logs/tests.xcresult \
			$(if $(ONLY),-only-testing:$(ONLY)) test \
		@cleanup $(DROP_APP_CMD)

## Run checks on changed files
fix:
	.venv/bin/python scripts/checks fix $(CHECK_ARGS)

## Check changed files without editing
check:
	.venv/bin/python scripts/checks check $(CHECK_ARGS)

## Run checks on all files
fix-all:
	.venv/bin/python scripts/checks fix-all $(CHECK_ARGS)

## Check all files without editing
check-all:
	.venv/bin/python scripts/checks check-all $(CHECK_ARGS)

## Run Periphery to find dead Swift code (on demand, not part of check/definition of done)
dead-code:
	scripts/make/dead-code.sh

## Print this help message
help:
	@scripts/make/help.sh

## Bump patch version and start release
release-patch:
	@scripts/make/release.sh patch

## Bump minor version and start release
release-minor:
	@scripts/make/release.sh minor

## Bump major version and start release
release-major:
	@scripts/make/release.sh major

## Start release workflow (requires BUMP=patch|minor|major)
release:
	@scripts/make/release.sh $(BUMP)

## Build and sign release without publishing [VERSION=X.Y.Z]
release-dry-run:
	@VERSION="$(VERSION)" scripts/make/release-dispatch.sh dry-run

## Replace an already published release [VERSION=X.Y.Z]
release-overwrite:
	@VERSION="$(VERSION)" scripts/make/release-dispatch.sh overwrite

## Deploy documentation site
site-deploy:
	gh workflow run pages.yml