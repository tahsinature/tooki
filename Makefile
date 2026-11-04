APP_NAME := Tooki
BUILD_DIR := build
APP := $(BUILD_DIR)/$(APP_NAME).app
# A stable signing identity keeps the Accessibility permission across rebuilds.
SIGN_ID ?= Apple Development
BIN := $(shell swift build -c release --show-bin-path)/$(APP_NAME)

.PHONY: build app run install info test clean

build:
	swift build -c release

app: build
	rm -rf $(APP)
	mkdir -p $(APP)/Contents/MacOS
	mkdir -p $(APP)/Contents/Resources
	cp $(BIN) $(APP)/Contents/MacOS/$(APP_NAME)
	cp Resources/Info.plist $(APP)/Contents/Info.plist
	cp Resources/AppIcon.icns $(APP)/Contents/Resources/AppIcon.icns
	codesign --force --sign "$(SIGN_ID)" $(APP)

run: app
	open $(APP)

install: app
	rm -rf /Applications/$(APP_NAME).app
	cp -R $(APP) /Applications/
	@echo "Installed to /Applications/$(APP_NAME).app"

info: app
	@printf '\nApp: %s\n' "$(APP)"
	@du -sh "$(APP)" | awk '{ print "App size on disk: " $$1 }'
	@printf 'Executable size: %s bytes\n' "$$(stat -f %z "$(APP)/Contents/MacOS/$(APP_NAME)")"
	@printf 'Version: %s (build %s)\n' "$$(/usr/libexec/PlistBuddy -c 'Print :CFBundleShortVersionString' "$(APP)/Contents/Info.plist")" "$$(/usr/libexec/PlistBuddy -c 'Print :CFBundleVersion' "$(APP)/Contents/Info.plist")"
	@printf 'Minimum macOS: %s\n' "$$(/usr/libexec/PlistBuddy -c 'Print :LSMinimumSystemVersion' "$(APP)/Contents/Info.plist")"
	@printf 'Architecture: %s\n' "$$(lipo -archs "$(APP)/Contents/MacOS/$(APP_NAME)")"

test:
	swift test

clean:
	rm -rf $(BUILD_DIR) .build
