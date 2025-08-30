#!/usr/bin/env bash
set -eu

# This script creates an optimized release build.

OUT_DIR="build/release"
mkdir -p "$OUT_DIR"
odin build source/main_default -out:$OUT_DIR/game_release.bin -no-bounds-check -o:speed
cp -R assets $OUT_DIR
cp -R audio $OUT_DIR
echo "Release build created in $OUT_DIR"
