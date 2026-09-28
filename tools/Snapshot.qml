import QtQuick
import QtQuick.Window
import "../lib"

// Headless screenshot harness for one screensaver:
//   tools/snapshot.sh <module-id> [seconds] [out.png] [width] [height] [options-json]
// Pure QtQuick, so it runs on the offscreen platform without a compositor.
// Shader-based modules need a real GPU and are checked with tools/preview.sh.
Window {
  id: win

  readonly property var args: {
    var all = Qt.application.arguments
    var at = all.indexOf("--")
    return at === -1 ? [] : all.slice(at + 1)
  }
  readonly property string moduleId: args[0] || "pong"
  readonly property real seconds: Number(args[1] || 3)
  readonly property string out: args[2] || ("/tmp/afterdark-" + moduleId + ".png")
  readonly property var overrides: {
    try { return JSON.parse(args[5] || "{}") } catch (e) { return {} }
  }

  width: Number(args[3] || 1280)
  height: Number(args[4] || 720)
  visible: true
  color: "black"

  function readModule() {
    var xhr = new XMLHttpRequest()
    xhr.open("GET", Qt.resolvedUrl("../screensavers/" + moduleId + "/module.json"), false)
    xhr.send()
    var meta = JSON.parse(xhr.responseText)
    var options = {}
    var list = meta.options || []
    for (var i = 0; i < list.length; i++) options[list[i].key] = list[i]["default"]
    for (var k in overrides) options[k] = overrides[k]
    return { meta: meta, options: options }
  }

  property var memory: ({})

  HostApi {
    id: host
    moduleId: win.moduleId
    userName: "neo"
    hostName: "omarchy"
    uptime: 90000
    store: QtObject {
      function moduleValue(id, key) { return win.memory[id + "/" + key] }
      function setModuleValue(id, key, value) { win.memory[id + "/" + key] = value }
    }
  }

  Loader {
    id: loader
    anchors.fill: parent
  }

  Timer {
    interval: 100
    repeat: true
    running: loader.status === Loader.Ready
    onTriggered: host.elapsed += 0.1
  }

  Timer {
    id: shoot
    interval: win.seconds * 1000
    onTriggered: loader.grabToImage(function(result) {
      result.saveToFile(win.out)
      console.warn("saved " + win.out)
      Qt.quit()
    })
  }

  Component.onCompleted: {
    var m = readModule()
    host.options = m.options
    // Initial properties, so the module sees its host in Component.onCompleted.
    loader.setSource(Qt.resolvedUrl("../screensavers/" + moduleId + "/" + (m.meta.entry || "Saver.qml")), { host: host })
    shoot.start()
  }
}
