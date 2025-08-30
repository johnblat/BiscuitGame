#!/usr/bin/env bash
echo "Building game"
odin build  source/main_default -debug -out:build/game.bin -vet-shadowing
