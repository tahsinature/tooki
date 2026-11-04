APP_NAME := Tooki
BUILD_DIR := build
APP := $(BUILD_DIR)/$(APP_NAME).app
# A stable signing identity keeps the Accessibility permission across rebuilds.
SIGN_ID ?= Apple Development
BIN := $(shell swift build -c release --show-bin-path)/$(APP_NAME)

.PHONY: build app run install test clean

build:
	swift build -c release

app: build
	rm -rf $(APP)
	mkdir -p $(APP)/Contents/MacOS
	cp $(BIN) $(APP)/Contents/MacOS/$(APP_NAME)
	cp Resources/Info.plist $(APP)/Contents/Info.plist
	codesign --force --sign "$(SIGN_ID)" $(APP)

run: app
	open $(APP)

install: app
	rm -rf /Applications/$(APP_NAME).app
	cp -R $(APP) /Applications/
	@echo "Installed to /Applications/$(APP_NAME).app"

test:
	swift test

clean:
	rm -rf $(BUILD_DIR) .build
