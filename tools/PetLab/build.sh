#!/bin/zsh
# Builds PetLab: a macOS command-line renderer for pet contact sheets and filmstrips.
# Usage: tools/PetLab/build.sh && /tmp/petlab <command> <out.png>
set -e
cd "$(dirname "$0")/../.."
OUT=${PETLAB_BIN:-/tmp/petlab}
swiftc -parse-as-library -O -DPETLAB \
  PipCore/Models/Pet.swift PipCore/Models/Mood.swift \
  $(ls PipCore/Pet/*.swift | grep -v PetPresence) PipCore/Pet/Species/*.swift \
  tools/PetLab/*.swift -o "$OUT"
