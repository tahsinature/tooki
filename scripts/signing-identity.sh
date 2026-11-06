#!/usr/bin/env bash
# Prefer a stable local certificate for dev builds, then an Apple Development identity.
set -euo pipefail

security find-identity -v -p codesigning 2>/dev/null | awk -F '"' -v channel="${1:-dev}" '
    $2 == "Tooki Dev Signing" { local_identity = $2 }
    $2 ~ /^Apple Development/ && !apple_identity { apple_identity = $2 }
    END {
        if (channel != "release" && local_identity) print local_identity
        else if (apple_identity) print apple_identity
        else print "-"
    }
'
