APP_NAME := Tooki
BUILD_DIR := build
APP := $(BUILD_DIR)/$(APP_NAME).app
DMG := $(BUILD_DIR)/$(APP_NAME).dmg
# Uses an Apple Development certificate when one exists, which keeps the Accessibility
# permission across rebuilds. Otherwise signs ad hoc, so only the Command Line Tools are needed.
SIGN_ID ?= $(shell security find-identity -v -p codesigning 2>/dev/null | grep -q "Apple Development" && echo "Apple Development" || echo "-")
# Set ARCHS="arm64 x86_64" for a universal build.
ARCHS ?= $(shell uname -m)
SWIFT_BUILD := swift build -c release $(foreach arch,$(ARCHS),--arch $(arch))
VERSION ?= $(shell /usr/libexec/PlistBuddy -c 'Print :CFBundleShortVersionString' Resources/Info.plist)
# "dev" for local builds; the release workflow passes CHANNEL=release. Shown at the bottom of the sidebar.
CHANNEL ?= dev
COMMIT := $(shell git rev-parse --short HEAD 2>/dev/null)$(shell git diff --quiet HEAD 2>/dev/null || echo "-dirty")
MIN_MACOS := $(shell /usr/libexec/PlistBuddy -c 'Print :LSMinimumSystemVersion' Resources/Info.plist)
SDK_VERSION := $(shell xcrun --sdk macosx --show-sdk-version)

.PHONY: build app run install dmg info icon test clean

build:
	$(SWIFT_BUILD)

app: build
	rm -rf $(APP)
	mkdir -p $(APP)/Contents/MacOS
	mkdir -p $(APP)/Contents/Resources
	cp "$$($(SWIFT_BUILD) --show-bin-path)/$(APP_NAME)" $(APP)/Contents/MacOS/$(APP_NAME)
	cp Resources/Info.plist $(APP)/Contents/Info.plist
	/usr/libexec/PlistBuddy -c "Set :CFBundleShortVersionString $(VERSION)" $(APP)/Contents/Info.plist
	/usr/libexec/PlistBuddy -c "Set :TookiBuildChannel $(CHANNEL)" -c "Set :TookiCommit $(COMMIT)" $(APP)/Contents/Info.plist
	cp Resources/AppIcon.icns $(APP)/Contents/Resources/AppIcon.icns
	# SwiftPM records the deployment target as the SDK version, which makes macOS fall back
	# to the old look. Record the real SDK so Tooki gets the current system design.
	vtool -set-build-version macos $(MIN_MACOS) $(SDK_VERSION) -replace \
		-output $(APP)/Contents/MacOS/$(APP_NAME) $(APP)/Contents/MacOS/$(APP_NAME)
	codesign --force --sign "$(SIGN_ID)" $(APP)

run: app
	open $(APP)

install: app
	rm -rf /Applications/$(APP_NAME).app
	cp -R $(APP) /Applications/
	@echo "Installed to /Applications/$(APP_NAME).app"

dmg: app
	rm -rf $(BUILD_DIR)/dmg $(DMG)
	mkdir -p $(BUILD_DIR)/dmg
	cp -R $(APP) $(BUILD_DIR)/dmg/
	ln -s /Applications $(BUILD_DIR)/dmg/Applications
	hdiutil create -volname $(APP_NAME) -srcfolder $(BUILD_DIR)/dmg -ov -format UDZO $(DMG)
	rm -rf $(BUILD_DIR)/dmg

info: app
	@printf '\nApp: %s\n' "$(APP)"
	@du -sh "$(APP)" | awk '{ print "App size on disk: " $$1 }'
	@printf 'Executable size: %s bytes\n' "$$(stat -f %z "$(APP)/Contents/MacOS/$(APP_NAME)")"
	@printf 'Version: %s (build %s)\n' "$$(/usr/libexec/PlistBuddy -c 'Print :CFBundleShortVersionString' "$(APP)/Contents/Info.plist")" "$$(/usr/libexec/PlistBuddy -c 'Print :CFBundleVersion' "$(APP)/Contents/Info.plist")"
	@printf 'Minimum macOS: %s\n' "$$(/usr/libexec/PlistBuddy -c 'Print :LSMinimumSystemVersion' "$(APP)/Contents/Info.plist")"
	@printf 'Signed with: %s\n' "$(SIGN_ID)"
	@printf 'Architecture: %s\n' "$$(lipo -archs "$(APP)/Contents/MacOS/$(APP_NAME)")"

# Rebuilds Resources/AppIcon.icns from AppIcon.png. Every size is resampled to RGBA,
# because a palette PNG left the 16px icon garbled in System Settings and Finder lists.
icon:
	rm -rf $(BUILD_DIR)/AppIcon.iconset && mkdir -p $(BUILD_DIR)/AppIcon.iconset
	for size in 16 32 128 256 512; do \
		sips -s format png -z $$size $$size Resources/AppIcon.png --out $(BUILD_DIR)/AppIcon.iconset/icon_$${size}x$${size}.png >/dev/null; \
		sips -s format png -z $$((size * 2)) $$((size * 2)) Resources/AppIcon.png --out $(BUILD_DIR)/AppIcon.iconset/icon_$${size}x$${size}@2x.png >/dev/null; \
	done
	iconutil -c icns -o Resources/AppIcon.icns $(BUILD_DIR)/AppIcon.iconset

test:
	swift test

clean:
	rm -rf $(BUILD_DIR) .build
