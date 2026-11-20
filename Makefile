APP_NAME := MediaGrabber
BUNDLE_ID := app.mediagrabber.mac
DERIVED := build
CONFIG ?= Debug
APP := $(abspath $(DERIVED)/Build/Products/$(CONFIG)/$(APP_NAME).app)
INSTALLED := /Applications/$(APP_NAME).app
LSREGISTER := /System/Library/Frameworks/CoreServices.framework/Frameworks/LaunchServices.framework/Support/lsregister

.DEFAULT_GOAL := run
.PHONY: generate build install drop-build-app run plugin-test test lint venv tools tools-test appcast-test release-assets-test release-scripts-test e2e release release-patch release-minor release-major release-dry-run release-overwrite site-deploy

tools:
	scripts/fetch-tools.sh

tools-test:
	scripts/tests/test_fetch_tools.sh

appcast-test:
	scripts/tests/test_appcast.sh $(PY)

release-assets-test:
	scripts/tests/test_release_assets.sh

release-scripts-test:
	scripts/tests/test_publish_release.sh
	scripts/tests/test_check_feed.sh
	scripts/tests/test_check_signature.sh

e2e:
	$(MAKE) build CONFIG=Release
	app="$(abspath $(DERIVED))/Build/Products/Release/$(APP_NAME).app" ; \
		scripts/sign-app.sh "$$app" - && scripts/e2e/run.sh "$$app" ; \
		status=$$? ; \
		$(MAKE) --no-print-directory drop-build-app ; \
		exit $$status

generate:
	mise exec -- tuist generate --no-open

build: tools generate
	xcodebuild -workspace $(APP_NAME).xcworkspace -scheme $(APP_NAME) \
		-configuration $(CONFIG) \
		-destination 'platform=macOS' \
		-derivedDataPath $(DERIVED) \
		build

# make install [CONFIG=Release]; replaces the app in /Applications and removes the build copy so only one exists.
install: build
	@pids=`osascript -e 'tell application "System Events" to get unix id of (every process whose bundle identifier is "$(BUNDLE_ID)")' 2>/dev/null | tr ',' ' '` ; \
		if [ -n "$$pids" ]; then kill -9 $$pids; fi
	@killall -9 $(APP_NAME) >/dev/null 2>&1 || true
	@while pgrep -x $(APP_NAME) >/dev/null 2>&1; do sleep 0.05; done
	@test -d "$(APP)" || { echo "build product missing: $(APP)"; exit 1; }
	rm -rf "$(INSTALLED)"
	ditto "$(APP)" "$(INSTALLED)"
	$(LSREGISTER) -f "$(INSTALLED)"
	@$(MAKE) --no-print-directory drop-build-app
	open "$(INSTALLED)"

drop-build-app:
	@for config in Debug Release; do \
		app="$(abspath $(DERIVED))/Build/Products/$$config/$(APP_NAME).app" ; \
		if [ -d "$$app" ]; then $(LSREGISTER) -u "$$app" ; rm -rf "$$app" ; fi ; \
	done

run: install

PY ?= .venv/bin/python

venv:
	python3 -m venv .venv
	.venv/bin/pip install -r requirements.txt

# Runs the bundled yt-dlp plugin's tests against the yt-dlp version pinned in requirements.txt.
plugin-test:
	$(PY) -m pip install -q -r Tests/PluginTests/requirements.txt
	$(PY) -I -B -m unittest discover -s Tests/PluginTests -p 'test_*.py'

# make test [ONLY=AppUnitTests/SomeSuite]; builds into the same build/ dir as `make`, never DerivedData.
test: plugin-test tools-test appcast-test release-assets-test release-scripts-test generate
	xcodebuild -workspace $(APP_NAME).xcworkspace -scheme $(APP_NAME)-Workspace \
		-destination 'platform=macOS' \
		-derivedDataPath $(DERIVED) \
		$(if $(ONLY),-only-testing:$(ONLY)) \
		test ; \
		status=$$? ; \
		$(MAKE) --no-print-directory drop-build-app ; \
		exit $$status

lint:
	mise exec -- swiftformat --lint .
	mise exec -- swiftlint lint --strict

# --- Release ---

CURRENT_VERSION = $(shell git tag --list 'v[0-9]*' | scripts/current-version.sh)

VERSION_CHECK = test -n "$(VERSION)" || { echo "VERSION=X.Y.Z required"; exit 1; } ; echo "$(VERSION)" | grep -Eq '^[0-9]+\.[0-9]+\.[0-9]+$$' || { echo "VERSION must be N.N.N"; exit 1; }

release-patch: BUMP := patch
release-minor: BUMP := minor
release-major: BUMP := major
release-patch release-minor release-major: release

release:
	@test -n "$(BUMP)" || { echo "pick one: make release-patch | release-minor | release-major"; exit 1; }
	@git diff --quiet && git diff --cached --quiet || { echo "working tree dirty — commit first"; exit 1; }
	@test "`git rev-parse --abbrev-ref HEAD`" = main || { echo "not on main"; exit 1; }
	@git fetch --quiet origin main
	@test "`git rev-parse HEAD`" = "`git rev-parse origin/main`" || { echo "local main != origin/main — push or pull first"; exit 1; }
	@next=$$(scripts/bump-version.sh $(CURRENT_VERSION) $(BUMP)) || exit 1 ; \
		echo "$(CURRENT_VERSION)  ->  $$next" ; \
		trigger="$$(date -u +%Y-%m-%dT%H:%M:%SZ)" ; \
		gh workflow run release.yml -f version=$$next -f dry_run=true >/dev/null ; \
		id="" ; \
		for i in $$(seq 1 30); do \
			id="$$(gh run list --workflow release.yml --json databaseId,event,createdAt -q '[.[] | select(.event=="workflow_dispatch" and .createdAt > "'"$$trigger"'")] | .[0].databaseId // empty' 2>/dev/null)" ; \
			[ -n "$$id" ] && break ; \
			sleep 5 ; \
		done ; \
		[ -n "$$id" ] || { echo "no dry-run workflow found"; exit 1; } ; \
		gh run watch $$id --exit-status || { echo "dry-run release failed"; exit 1; } ; \
		cat docs/release-checklist.md ; \
		read -p "type yes to proceed: " ok ; \
		[ "$$ok" = yes ] || { echo aborted; exit 1; } ; \
		read -p "tag v$$next and push? [y/N] " confirm ; \
		[ "$$confirm" = y ] || { echo aborted; exit 1; } ; \
		git tag -a "v$$next" -m "MediaGrabber v$$next" ; \
		git push origin "v$$next" ; \
		echo "pushed v$$next — CI builds the release now"

# make release-dry-run VERSION=X.Y.Z; builds and signs without publishing.
release-dry-run:
	@$(VERSION_CHECK)
	gh workflow run release.yml -f version=$(VERSION) -f dry_run=true

# make release-overwrite VERSION=X.Y.Z; replaces an already published release.
release-overwrite:
	@$(VERSION_CHECK)
	@read -p "replace the published release v$(VERSION)? [y/N] " ok ; \
		[ "$$ok" = y ] || { echo aborted; exit 1; }
	gh workflow run release.yml -f version=$(VERSION) -f overwrite=true

site-deploy:
	gh workflow run pages.yml
