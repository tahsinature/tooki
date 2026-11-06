#!/usr/bin/env bash
# Prints an SDK that the active Swift compiler can use for Tooki's SwiftUI views.
set -euo pipefail

probe_directory="$(mktemp -d "${TMPDIR:-/tmp}/tooki-sdk.XXXXXX")"
trap 'rm -rf "$probe_directory"' EXIT

cat > "$probe_directory/Probe.swift" <<'SWIFT'
import SwiftUI

struct SDKProbe: View {
    @State private var isEnabled = false

    var body: some View {
        Toggle("Probe", isOn: $isEnabled)
    }
}
SWIFT

supports_swiftui() {
    xcrun swiftc -typecheck -sdk "$1" "$probe_directory/Probe.swift" \
        > "$probe_directory/diagnostic.log" 2>&1
}

# An explicit SDKROOT is intentional. Report its failure instead of silently overriding it.
selected_sdk="${SDKROOT:-$(xcrun --sdk macosx --show-sdk-path)}"
if supports_swiftui "$selected_sdk"; then
    printf '%s\n' "$selected_sdk"
    exit 0
fi
cp "$probe_directory/diagnostic.log" "$probe_directory/selected-sdk.log"

if [[ -z "${SDKROOT:-}" ]]; then
    sdk_directory="$(dirname "$selected_sdk")"
    for candidate in "$sdk_directory"/MacOSX[0-9]*.sdk; do
        [[ -d "$candidate" ]] || continue
        if supports_swiftui "$candidate"; then
            printf 'Using %s because the default SDK failed the SwiftUI compile check.\n' "$candidate" >&2
            printf '%s\n' "$candidate"
            exit 0
        fi
    done
fi

printf 'Cannot compile SwiftUI with SDK %s.\n' "$selected_sdk" >&2
cat "$probe_directory/selected-sdk.log" >&2
printf 'Install a compatible Apple developer toolchain, or set SDKROOT to a compatible macOS SDK.\n' >&2
exit 1
