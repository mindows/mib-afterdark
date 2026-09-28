#!/bin/bash
# Render one screensaver headlessly and save a PNG after N seconds.
# Usage: tools/snapshot.sh <module-id> [seconds] [out.png] [width] [height] [options-json]
set -euo pipefail
here=$(cd "$(dirname "$0")" && pwd)
export QT_QPA_PLATFORM=offscreen QT_FORCE_STDERR_LOGGING=1 QML_XHR_ALLOW_FILE_READ=1
exec timeout 120 /usr/lib/qt6/bin/qml "$here/Snapshot.qml" -- "$@"
