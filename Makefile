.DEFAULT_GOAL := help
.PHONY: help dev clean app dmg test install clean-builds size test-clipboard-native test-detective-native test-hyper-native test-preview-native test-instance-guard-native test-snippets-native test-toast-native

help: ## Show available commands
	@awk 'BEGIN {FS = ":.*## "} /^[a-zA-Z_-]+:.*## / {printf "  %-24s %s\n", $$1, $$2}' $(MAKEFILE_LIST)

dev: clean ## Launch the primary Tauri app with live reload
	bun run desktop

clean: ## Stop development processes without deleting build caches
	@bun scripts/stop-dev.ts

app: ## Build and sign build/Tooki.app (CONFIGURATION=debug for development)
	@bash scripts/package-macos.sh app

dmg: ## Build build/Tooki.dmg (TAURI_TARGET=universal-apple-darwin for both Macs)
	@bash scripts/package-macos.sh dmg

test: ## Check the frontend and test the Rust and TypeScript features
	bun run check
	bun test
	cargo test --locked --manifest-path src-tauri/Cargo.toml --bin tooki
	cargo test --locked --manifest-path src-tauri/crates/hyper-key/Cargo.toml
	cargo test --locked --manifest-path src-tauri/crates/shortcut-detective/Cargo.toml

install: app ## Install the local build into Applications
	ditto "build/$(if $(filter debug,$(CONFIGURATION)),Tooki Dev,Tooki).app" "/Applications/$(if $(filter debug,$(CONFIGURATION)),Tooki Dev,Tooki).app"

size: ## Show existing build sizes without rebuilding
	@bun scripts/size.ts

clean-builds: ## Remove build caches and bundles (stop dev/builds first; next build is slower)
	rm -rf src-tauri/target src-tauri/crates/*/target dist build

test-clipboard-native: ## Verify clipboard capture with an isolated pasteboard
	@sh scripts/test-clipboard-native.sh

.PHONY: test-drop-content-native
test-drop-content-native: ## Verify drop content using an isolated pasteboard
	@sh scripts/test-drop-content-native.sh

test-detective-native: ## Verify macOS shortcut callback handling
	@sh scripts/test-detective-native.sh

test-hyper-native: ## Verify macOS Hyper Key mapping parsing
	@sh scripts/test-hyper-native.sh

test-preview-native: ## Verify native Quick Look ownership and navigation
	@sh scripts/test-preview-native.sh

test-instance-guard-native: ## Verify local dev/production session exclusion
	@sh scripts/test-instance-guard-native.sh

test-snippets-native: ## Verify snippet replacement events without typing into apps
	@sh scripts/test-snippets-native.sh

test-toast-native: ## Verify native toast layout and nonactivation
	@sh scripts/test-toast-native.sh

.PHONY: test-windows-native
test-windows-native: ## Verify independent native window dismissal
	@sh scripts/test-windows-native.sh
