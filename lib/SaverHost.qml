import QtQuick
import "Util.js" as Util

// Runs one screensaver module: builds its `host`, loads its entry point,
// crossfades when the module changes, and keeps the clock it escalates by.
// Used for every fullscreen screen and for the control panel's preview.
Item {
  id: holder

  // A catalog entry (lib/Catalog.qml), or null.
  property var module: null
  // The runtime (Overlay.qml): store, feed, identity, theme.
  property var runtime: null
  property bool preview: false
  property bool running: true

  property var shown: null
  property string failure: ""

  // Running a screensaver that uses live data: the runtime keeps its feed
  // going while any host says so.
  readonly property bool wantsFeed: running && !!shown && shown.system === true
  onWantsFeedChanged: if (runtime) runtime.feedUsers += wantsFeed ? 1 : -1
  Component.onDestruction: if (wantsFeed && runtime) runtime.feedUsers--

  clip: true

  HostApi {
    id: api
    moduleId: holder.shown ? holder.shown.id : ""
    preview: holder.preview
    store: holder.runtime ? holder.runtime.store : null
    options: {
      var out = {}
      var m = holder.shown
      if (!m) return out
      for (var i = 0; i < m.options.length; i++) out[m.options[i].key] = m.options[i]["default"]
      var chosen = holder.runtime && holder.runtime.store ? holder.runtime.store.optionsFor(m.id) : {}
      for (var j = 0; j < m.options.length; j++) {
        var o = m.options[j]
        var v = chosen[o.key]
        if (o.type === "enum" && o.options.indexOf(v) !== -1) out[o.key] = v
        else if (o.type === "boolean" && typeof v === "boolean") out[o.key] = v
      }
      return out
    }
    system: holder.shown && holder.shown.system && holder.runtime && holder.runtime.liveData ? holder.runtime.feed : null
    uptime: holder.runtime ? holder.runtime.uptime : 0
    userName: holder.runtime ? holder.runtime.userName : ""
    hostName: holder.runtime ? holder.runtime.hostName : ""
    foreground: holder.runtime ? holder.runtime.themeForeground : "#e6e6e6"
    background: holder.runtime ? holder.runtime.themeBackground : "#000000"
    accent: holder.runtime ? holder.runtime.themeAccent : "#7aa2f7"
  }

  function show(m) {
    holder.shown = m
    holder.failure = ""
    api.elapsed = 0
    if (!m) { loader.source = ""; return }
    // Initial properties, so a module sees its host in Component.onCompleted.
    loader.setSource(m.url, { host: api, running: Qt.binding(function() { return holder.running }) })
  }

  onModuleChanged: {
    if (!holder.shown || !loader.item) { show(holder.module); stage.opacity = 1; return }
    if (holder.module && holder.shown && holder.module.id === holder.shown.id) return
    swap.restart()
  }

  SequentialAnimation {
    id: swap
    NumberAnimation { target: stage; property: "opacity"; to: 0; duration: 450 }
    ScriptAction { script: holder.show(holder.module) }
    NumberAnimation { target: stage; property: "opacity"; to: 1; duration: 600 }
  }

  Rectangle { anchors.fill: parent; color: "black" }

  Item {
    id: stage
    anchors.fill: parent

    Loader {
      id: loader
      anchors.fill: parent
      onStatusChanged: {
        if (status === Loader.Error) {
          holder.failure = holder.shown ? holder.shown.name : "screensaver"
          console.warn("mib-afterdark: screensaver failed to load: " + (holder.shown ? holder.shown.url : ""))
        }
      }
    }
  }

  Text {
    anchors.centerIn: parent
    visible: holder.failure !== ""
    textFormat: Text.PlainText
    color: "#808080"
    font.family: "monospace"
    font.pixelSize: Math.max(12, holder.height / 40)
    text: holder.failure + " could not start"
  }

  Timer {
    interval: 1000
    repeat: true
    running: holder.running && !!holder.shown
    onTriggered: api.elapsed += 1
  }

  // Now and then a quattro drives straight through whatever is showing.
  Quattro {
    id: driveBy
    property real speed: 0
    visible: false
    z: 10
    pixel: Math.max(2, holder.height / 150)
    y: holder.height - height - holder.height * 0.03

    function launch() {
      x = holder.width + 10
      speed = holder.width / 3.2
      visible = true
    }
  }

  Timer {
    interval: 60000
    repeat: true
    running: holder.running && !holder.preview && !!holder.shown && holder.shown.id !== "flying-quattros"
    onTriggered: if (!driveBy.visible && Util.chance(45)) driveBy.launch()
  }

  FrameAnimation {
    running: driveBy.visible && holder.running
    onTriggered: {
      driveBy.x -= driveBy.speed * Math.min(frameTime, 0.05)
      if (driveBy.x < -driveBy.width - 10) driveBy.visible = false
    }
  }

  Component.onCompleted: show(holder.module)
}
