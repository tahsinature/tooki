APP_NAME := Tooki
# Prefer full Xcode for this project, while honoring an explicit toolchain selection.
ifeq ($(origin DEVELOPER_DIR),undefined)
ifneq ($(wildcard /Applications/Xcode.app/Contents/Developer),)
export DEVELOPER_DIR := /Applications/Xcode.app/Contents/Developer
endif
endif
CHANNEL ?= dev
DISPLAY_NAME := $(if $(filter release,$(CHANNEL)),Tooki,Tooki Dev)
BUNDLE_ID := us.tahsin.tooki$(if $(filter release,$(CHANNEL)),,.dev)
BUILD_DIR := build
APP := $(BUILD_DIR)/$(DISPLAY_NAME).app
DMG := $(BUILD_DIR)/$(DISPLAY_NAME).dmg
GALLERY_APP := $(BUILD_DIR)/Tooki Component Gallery.app
GALLERY_ARGS ?=
# Uses Tooki Dev Signing or Apple Development to preserve Accessibility permission across rebuilds.
# Falls back to ad hoc signing when no certificate is installed. Override with SIGN_ID if needed.
SIGN_ID ?= $(shell bash scripts/signing-identity.sh "$(CHANNEL)")
# Set ARCHS="arm64 x86_64" for a universal build.
ARCHS ?= $(shell uname -m)
CONFIGURATION ?= release
APP_ICON := $(if $(filter release,$(CHANNEL)),Resources/AppIcon.icns,$(BUILD_DIR)/DevIcon.icns)
# Only inspect SDKs for targets that compile Swift, so clean and icon work without a toolchain.
ifneq ($(filter build app dev install dmg info test gallery,$(or $(MAKECMDGOALS),build)),)
# Make's parse-time shells need the selected directory explicitly; recipe shells inherit it.
MACOS_SDK := $(shell DEVELOPER_DIR="$(DEVELOPER_DIR)" bash scripts/select-macos-sdk.sh)
ifeq ($(MACOS_SDK),)
$(error No compatible macOS SDK found. See the SDK diagnostic above)
endif
# Keep fallback-SDK artifacts separate. SwiftPM 6.4 retains incompatible prebuilts in
# an already-resolved workspace even after --disable-experimental-prebuilts is passed.
SWIFT_PACKAGE_FLAGS := $(if $(filter $(MACOS_SDK),$(shell DEVELOPER_DIR="$(DEVELOPER_DIR)" xcrun --sdk macosx --show-sdk-path)),,--scratch-path .build/compatible-sdk --disable-experimental-prebuilts)
endif
SWIFT_BUILD = swift build $(SWIFT_PACKAGE_FLAGS) -c $(CONFIGURATION) --sdk "$(MACOS_SDK)" $(foreach arch,$(ARCHS),--arch $(arch)) -Xlinker -rpath -Xlinker @executable_path/../Frameworks
VERSION ?= $(shell /usr/libexec/PlistBuddy -c 'Print :CFBundleShortVersionString' Resources/Info.plist)
BUILD_NUMBER ?= $(shell git rev-list --count HEAD)
COMMIT := $(shell git rev-parse --short HEAD 2>/dev/null)$(shell git diff --quiet HEAD 2>/dev/null || echo "-dirty")
MIN_MACOS := $(shell /usr/libexec/PlistBuddy -c 'Print :LSMinimumSystemVersion' Resources/Info.plist)
SDK_VERSION = $(shell /usr/libexec/PlistBuddy -c 'Print :Version' "$(MACOS_SDK)/SDKSettings.plist")

.PHONY: build app dev install dmg info icon test clean gallery visual-test

build:
	$(SWIFT_BUILD) --product $(APP_NAME)

app: build $(APP_ICON)
	rm -rf "$(APP)"
	mkdir -p "$(APP)/Contents/MacOS" "$(APP)/Contents/Resources"
	bin_dir="$$($(SWIFT_BUILD) --show-bin-path)"; \
	cp "$$bin_dir/$(APP_NAME)" "$(APP)/Contents/MacOS/$(APP_NAME)" && \
	for bundle in "$$bin_dir"/*.bundle; do \
		if [ -d "$$bundle" ]; then cp -R "$$bundle" "$(APP)/Contents/Resources/" || exit 1; fi; \
	done
	bin_dir="$$($(SWIFT_BUILD) --show-bin-path)"; \
		bash scripts/embed-sparkle.sh "$$bin_dir/Sparkle.framework" "$(APP)" "$(SIGN_ID)"
	# Release packages get separate symbols. Debug builds retain symbols in the executable.
	if [ "$(CONFIGURATION)" = release ]; then \
		dsymutil "$(APP)/Contents/MacOS/$(APP_NAME)" -o "$(BUILD_DIR)/$(APP_NAME).dSYM" && \
		strip -x "$(APP)/Contents/MacOS/$(APP_NAME)"; \
	fi
	cp Resources/Info.plist "$(APP)/Contents/Info.plist"
	/usr/libexec/PlistBuddy -c "Set :CFBundleName $(DISPLAY_NAME)" -c "Set :CFBundleDisplayName $(DISPLAY_NAME)" -c "Set :CFBundleIdentifier $(BUNDLE_ID)" "$(APP)/Contents/Info.plist"
	/usr/libexec/PlistBuddy -c "Set :CFBundleShortVersionString $(VERSION)" "$(APP)/Contents/Info.plist"
	/usr/libexec/PlistBuddy -c "Set :CFBundleVersion $(BUILD_NUMBER)" "$(APP)/Contents/Info.plist"
	/usr/libexec/PlistBuddy -c "Set :TookiBuildChannel $(CHANNEL)" -c "Set :TookiCommit $(COMMIT)" "$(APP)/Contents/Info.plist"
	/usr/libexec/PlistBuddy -c "Add :TookiBuiltAt string $$(date -u '+%Y-%m-%dT%H:%M:%SZ')" "$(APP)/Contents/Info.plist"
	cp "$(APP_ICON)" "$(APP)/Contents/Resources/AppIcon.icns"
	cp Resources/ThirdPartyNotices.txt "$(APP)/Contents/Resources/ThirdPartyNotices.txt"
	# SwiftPM records the deployment target as the SDK version, which makes macOS fall back
	# to the old look. Record the real SDK so Tooki gets the current system design.
	vtool -set-build-version macos $(MIN_MACOS) $(SDK_VERSION) -replace \
		-output "$(APP)/Contents/MacOS/$(APP_NAME)" "$(APP)/Contents/MacOS/$(APP_NAME)"
	codesign --force --sign "$(SIGN_ID)" "$(APP)"

# Target-specific configuration also applies to the app and build prerequisites.
dev: CONFIGURATION = debug
dev: app
	open -n "$(APP)"

gallery: CONFIGURATION = debug
gallery: $(BUILD_DIR)/DevIcon.icns
	$(SWIFT_BUILD) --product ComponentGallery
	mkdir -p "$(GALLERY_APP)/Contents/MacOS" "$(GALLERY_APP)/Contents/Resources"
	cp "$$($(SWIFT_BUILD) --show-bin-path)/ComponentGallery" "$(GALLERY_APP)/Contents/MacOS/ComponentGallery"
	cp Resources/GalleryInfo.plist "$(GALLERY_APP)/Contents/Info.plist"
	cp "$(BUILD_DIR)/DevIcon.icns" "$(GALLERY_APP)/Contents/Resources/AppIcon.icns"
	codesign --force --sign "$(SIGN_ID)" "$(GALLERY_APP)"
	open -n "$(GALLERY_APP)" --args $(GALLERY_ARGS)

$(BUILD_DIR)/DevIcon.icns: Resources/AppIcon.png scripts/dev-icon.swift
	mkdir -p "$(BUILD_DIR)"
	xcrun swift scripts/dev-icon.swift Resources/AppIcon.png "$(BUILD_DIR)/DevIcon.iconset"
	iconutil -c icns -o "$@" "$(BUILD_DIR)/DevIcon.iconset"

install: app
	rm -rf "/Applications/$(DISPLAY_NAME).app"
	cp -R "$(APP)" /Applications/
	@echo "Installed to /Applications/$(DISPLAY_NAME).app"

dmg: app
	rm -rf $(BUILD_DIR)/dmg "$(DMG)"
	mkdir -p $(BUILD_DIR)/dmg
	cp -R "$(APP)" $(BUILD_DIR)/dmg/
	ln -s /Applications $(BUILD_DIR)/dmg/Applications
	# ULMO (LZMA) makes a DMG about a quarter smaller than UDZO and opens on macOS 10.15 and later.
	hdiutil create -volname "$(DISPLAY_NAME)" -srcfolder $(BUILD_DIR)/dmg -ov -format ULMO "$(DMG)"
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
# Sizes of 256px and up are then quantized with pngquant, which cuts the icon by about 70%
# without a visible change. Install it with `brew install pngquant`.
icon:
	@command -v pngquant >/dev/null || { echo "pngquant is required: brew install pngquant"; exit 1; }
	rm -rf $(BUILD_DIR)/AppIcon.iconset && mkdir -p $(BUILD_DIR)/AppIcon.iconset
	for size in 16 32 128 256 512; do \
		sips -s format png -z $$size $$size Resources/AppIcon.png --out $(BUILD_DIR)/AppIcon.iconset/icon_$${size}x$${size}.png >/dev/null; \
		sips -s format png -z $$((size * 2)) $$((size * 2)) Resources/AppIcon.png --out $(BUILD_DIR)/AppIcon.iconset/icon_$${size}x$${size}@2x.png >/dev/null; \
	done
	for file in icon_128x128@2x icon_256x256 icon_256x256@2x icon_512x512 icon_512x512@2x; do \
		pngquant --quality 85-98 --speed 1 --strip --force --output $(BUILD_DIR)/AppIcon.iconset/$$file.png $(BUILD_DIR)/AppIcon.iconset/$$file.png; \
	done
	iconutil -c icns -o Resources/AppIcon.icns $(BUILD_DIR)/AppIcon.iconset

visual-test:
	$(MAKE) test SWIFT_TEST_FLAGS="--filter 'DesignSystemTests|FeatureVisualTests'"

test:
	@test -d "$$(xcode-select -p)/Platforms/MacOSX.platform/Developer/Library/Frameworks/XCTest.framework" || { echo "Tests require full Xcode for SnapshotTesting. Set DEVELOPER_DIR to Xcode.app/Contents/Developer."; exit 1; }
	swift test $(SWIFT_PACKAGE_FLAGS) $(SWIFT_TEST_FLAGS) --sdk "$(MACOS_SDK)"

clean:
	rm -rf $(BUILD_DIR) .build
