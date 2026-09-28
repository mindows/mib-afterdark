#!/bin/bash
# Run one screensaver in a window on the live desktop (needed for shader
# modules, which the offscreen snapshot cannot draw). Close the window or
# Ctrl-C to stop. Usage: tools/preview.sh <module-id> [options-json] [seconds]
#
# Quickshell refuses static imports from outside its config folder, so the
# harness is loaded by file URL from a throwaway config, exactly the way
# omarchy-shell loads a plugin's entry point.
set -euo pipefail
here=$(cd "$(dirname "$0")" && pwd)
export AFTERDARK_MODULE=${1:-plasma} AFTERDARK_OPTIONS=${2:-{\}}
config=$(mktemp -d "${TMPDIR:-/tmp}/afterdark-preview.XXXXXX")
trap 'rm -rf -- "$config"' EXIT
cat >"$config/shell.qml" <<QML
import QtQuick
import Quickshell
ShellRoot {
  LazyLoader { active: true; source: "file://$here/Preview.qml" }
}
QML
if [[ -n ${3:-} ]]; then
  timeout "$3" qs -p "$config" || true
else
  qs -p "$config"
fi
