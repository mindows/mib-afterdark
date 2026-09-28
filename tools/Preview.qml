import QtQuick
import Quickshell
import Quickshell.Io
import "../lib"

// Run one screensaver in a normal window on the real compositor, for the
// modules the offscreen snapshot cannot draw (shaders):
//   tools/preview.sh <module-id> [options-json]
FloatingWindow {
  id: win

  readonly property string moduleId: Quickshell.env("AFTERDARK_MODULE") || "plasma"
  readonly property var overrides: {
    try { return JSON.parse(Quickshell.env("AFTERDARK_OPTIONS") || "{}") } catch (e) { return {} }
  }

  title: "afterdark-preview"
  implicitWidth: 1280
  implicitHeight: 720
  color: "black"

  property var memory: ({})

  HostApi {
    id: host
    moduleId: win.moduleId
    userName: Quickshell.env("USER") || ""
    store: QtObject {
      function moduleValue(id, key) { return win.memory[id + "/" + key] }
      function setModuleValue(id, key, value) { win.memory[id + "/" + key] = value }
    }
  }

  FileView {
    path: Qt.resolvedUrl("../screensavers/" + win.moduleId + "/module.json").toString().replace("file://", "")
    blockLoading: true
    onLoaded: win.start(JSON.parse(text()))
  }

  Loader { id: loader; anchors.fill: parent }

  Timer {
    interval: 100; repeat: true; running: loader.status === Loader.Ready
    onTriggered: host.elapsed += 0.1
  }

  function start(meta) {
    var options = {}
    var list = meta.options || []
    for (var i = 0; i < list.length; i++) options[list[i].key] = list[i]["default"]
    for (var k in overrides) options[k] = overrides[k]
    host.options = options
    loader.setSource(Qt.resolvedUrl("../screensavers/" + moduleId + "/" + (meta.entry || "Saver.qml")), { host: host })
  }
}
