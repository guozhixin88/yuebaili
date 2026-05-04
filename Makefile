APP_NAME := 月白历
VERSION := 1.0.0

.PHONY: build run package install uninstall clean verify

build:
	./scripts/build.sh

run: build
	killall Yuebaili 2>/dev/null || true
	open -gj "build/$(APP_NAME).app"

package:
	./scripts/package-dmg.sh

install:
	./scripts/install-local.sh

uninstall:
	./scripts/uninstall-local.sh

verify: build
	codesign --verify --deep --strict --verbose=2 "build/$(APP_NAME).app"

clean:
	rm -rf build dist
