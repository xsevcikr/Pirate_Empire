#!/usr/bin/env bash
# Import, boot smoke test, unit tests and integration scenarios. Exits non-zero on any failure.
set -euo pipefail
cd "$(dirname "$0")/.."
godot --headless --import --path . >/dev/null 2>&1 || true
godot --headless --path . --quit-after 120
godot --headless --path . -s res://tests/test_runner.gd
for scenario in tests/integration/*.gd; do
	godot --headless --path . --fixed-fps 60 -s "res://$scenario"
done
