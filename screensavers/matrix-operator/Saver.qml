import QtQuick
import "../../lib/Util.js" as Util

// Matrix Operator: the computer as an enormous command-and-control system.
// Four views share one feed: the live one from After Dark when live system
// data is on, otherwise a simulation that says so on screen.
Item {
  id: root

  property var host: null
  property bool running: true

  readonly property string viewOption: host ? host.option("view", "cycle") : "cycle"
  readonly property string glyphs: host ? host.option("glyphs", "katakana") : "katakana"
  readonly property var feed: host && host.system ? host.system : synthetic
  readonly property real unit: Math.max(0.5, height / 1080)
  readonly property var views: ["operator", "rain", "intrusion", "trace"]

  property string view: "operator"
  property real viewClock: 0
  property bool waking: false

  function chooseView() {
    if (root.viewOption !== "cycle") return root.viewOption
    var others = root.views.filter(function(v) { return v !== root.view })
    return Util.pick(others)
  }

  function maybeWake() {
    // Very occasionally, somebody is trying to reach you.
    if (root.host && !root.host.preview && root.host.rare(40)) root.waking = true
  }

  Synthetic {
    id: synthetic
    active: root.running && !(root.host && root.host.system)
  }

  Rain {
    anchors.fill: parent
    visible: root.view === "rain" && !root.waking
    active: visible && root.running
    feed: root.feed
    glyphs: root.glyphs
    unit: root.unit
  }

  Operator {
    anchors.fill: parent
    visible: root.view === "operator" && !root.waking
    active: visible && root.running
    feed: root.feed
    host: root.host
    unit: root.unit
  }

  Intrusion {
    anchors.fill: parent
    visible: root.view === "intrusion" && !root.waking
    active: visible && root.running
    feed: root.feed
    host: root.host
    unit: root.unit
  }

  Trace {
    anchors.fill: parent
    visible: root.view === "trace" && !root.waking
    active: visible && root.running
    feed: root.feed
    host: root.host
    unit: root.unit
  }

  WakeUp {
    anchors.fill: parent
    visible: root.waking
    active: root.waking && root.running
    userName: root.host ? root.host.userName : ""
    onFinished: {
      root.waking = false
      root.view = "rain"
      root.viewClock = 0
    }
  }

  Timer {
    interval: 1000
    repeat: true
    running: root.running && root.viewOption === "cycle" && !root.waking
    onTriggered: {
      root.viewClock += 1
      if (root.viewClock < 40) return
      root.viewClock = 0
      root.view = root.chooseView()
      maybeWake()
    }
  }

  onViewOptionChanged: view = viewOption === "cycle" ? Util.pick(views) : viewOption
  Component.onCompleted: {
    view = viewOption === "cycle" ? Util.pick(views) : viewOption
    maybeWake()
  }
}
