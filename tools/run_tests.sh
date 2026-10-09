#!/usr/bin/env bash
# Run the GUT test suite headless.
# Uses $GODOT if set, else the first Godot binary found in tools/godot/, else `godot` on PATH.
set -euo pipefail

cd "$(dirname "$0")/.."

if [[ -z "${GODOT:-}" ]]; then
	GODOT=$(ls tools/godot/Godot_*_console.exe tools/godot/Godot_*linux* tools/godot/Godot*.app/Contents/MacOS/Godot 2>/dev/null | head -n 1 || true)
	GODOT=${GODOT:-godot}
fi

# Refresh the import cache so new class_name scripts are registered.
"$GODOT" --headless --import --path . >/dev/null 2>&1 || true

"$GODOT" --headless --path . -s addons/gut/gut_cmdln.gd -gexit "$@"
