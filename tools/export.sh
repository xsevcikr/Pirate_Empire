#!/usr/bin/env bash
# Builds release exports for all presets. Requires the Godot export templates to be installed.
set -euo pipefail
cd "$(dirname "$0")/.."
mkdir -p export/windows export/linux export/macos
godot --headless --path . --export-release "Windows Desktop" export/windows/PirateEmpire.exe
godot --headless --path . --export-release "Linux" export/linux/PirateEmpire.x86_64
godot --headless --path . --export-release "macOS" export/macos/PirateEmpire.zip
