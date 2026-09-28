#!/bin/bash
# Compile every screensaver's .frag into the .qsb that ShaderEffect loads.
# The .qsb files are committed, so users never need the Qt shader tools;
# run this after editing a .frag.
set -euo pipefail
qsb=${QSB:-/usr/lib/qt6/bin/qsb}
root=$(cd "$(dirname "$0")/.." && pwd)
find "$root/screensavers" -name '*.frag' -print0 | while IFS= read -r -d '' frag; do
  "$qsb" --glsl "100 es,120,150" --hlsl 50 --msl 12 -o "$frag.qsb" "$frag"
  echo "built ${frag#$root/}.qsb"
done
