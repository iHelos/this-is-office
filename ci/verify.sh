#!/usr/bin/env bash
# Single entry point for local and CI verification.
#
# Runs the headless test suite through the Godot binary on PATH. If the GODOT
# environment variable is set, that binary is used instead (useful when the
# editor on PATH is a different version). Exits non-zero on any suite failure,
# so CI can gate a pull request on this script alone.
#
# Usage:
#   ci/verify.sh
#   GODOT=/path/to/godot ci/verify.sh
set -euo pipefail

ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
GODOT="${GODOT:-godot}"

cd "$ROOT"

echo "==> Importing resources (headless)..."
"$GODOT" --headless --import --quit >/dev/null

echo "==> Running test suite..."
"$GODOT" --headless --path . res://tests/test_runner.tscn
