import QtQuick
import "../../lib/Util.js" as Util

// An intentionally overdramatic "something is happening" sequence, built on
// harmless telemetry from this machine: its own hostname, uptime, process
// count and load. It loops through five acts.
Item {
  id: act

  property var feed: null
  property var host: null
  property bool active: true
  property real unit: 1

  readonly property color bright: "#9dffb8"
  readonly property color green: "#19c94a"
  readonly property real fontPx: Math.round(20 * unit)
  readonly property string target: host && host.hostName ? host.hostName.toUpperCase() : "LOCALHOST"

  property real t: 0
  property int stage: 0
  property var terminal: []
  property var hex: []
  property bool denied: false
  readonly property var stageEnds: [7, 14, 21, 26, 34]

  function reset() {
    act.t = 0
    act.stage = 0
    act.terminal = []
    act.denied = Math.random() < 0.12
    act.scriptIndex = 0
  }

  function say(line) {
    act.terminal = act.terminal.slice(-14).concat([line])
  }

  function hexLine() {
    var s = Util.pad((Math.floor(Math.random() * 0xffffff)).toString(16), 8, "0") + "  "
    for (var i = 0; i < 32; i++) s += Util.pad(Math.floor(Math.random() * 256).toString(16), 2, "0") + " "
    return s.toUpperCase()
  }

  readonly property var script: [
    [0.3, function() { return "> establishing uplink to " + act.target.toLowerCase() + " ..." }],
    [1.2, function() { return "> handshake ............... OK" }],
    [2.0, function() { return "> enumerating processes ... " + (act.feed ? act.feed.processCount : 0) + " found" }],
    [2.8, function() { return "> uptime .................. " + Util.formatDuration(act.feed ? act.feed.uptime : 0) }],
    [3.6, function() { return "> load average ............ " + (act.feed ? act.feed.load1.toFixed(2) : "0.00") }],
    [4.4, function() { return "> open links .............. " + (act.feed ? act.feed.connections.length : 0) }],
    [5.4, function() { return "> injecting payload: harmless.sh" }],
    [6.2, function() { return "> it's fine. this is a screensaver." }]
  ]
  property int scriptIndex: 0

  function step(dt) {
    act.t += dt
    while (act.stage < act.stageEnds.length && act.t > act.stageEnds[act.stage]) act.stage++
    if (act.stage >= act.stageEnds.length) { reset(); return }
    if (act.stage === 0) {
      while (act.scriptIndex < act.script.length && act.t >= act.script[act.scriptIndex][0]) {
        say(act.script[act.scriptIndex][1]())
        act.scriptIndex++
      }
    }
    if (act.stage === 1) act.hex = act.hex.slice(-40).concat([hexLine(), hexLine()])
  }

  component Line: Text {
    textFormat: Text.PlainText
    font.family: "monospace"
    font.preferShaping: false
    font.pixelSize: act.fontPx
    color: act.green
  }

  Rectangle { anchors.fill: parent; color: "black" }

  // Act 1: the terminal.
  Column {
    visible: act.stage === 0
    anchors { left: parent.left; top: parent.top; margins: 60 * act.unit }
    spacing: act.fontPx * 0.4
    Repeater {
      model: act.terminal
      Line { required property string modelData; text: modelData; color: act.bright }
    }
    Line { text: "_"; visible: Math.floor(act.t * 3) % 2 === 0; color: act.bright }
  }

  // Act 2: the firewall.
  Item {
    anchors.fill: parent
    visible: act.stage === 1
    Column {
      anchors.fill: parent
      anchors.margins: 30 * act.unit
      clip: true
      opacity: 0.45
      Repeater {
        model: act.hex
        Line { required property string modelData; text: modelData; font.pixelSize: act.fontPx * 0.8 }
      }
    }
    Rectangle {
      anchors.centerIn: parent
      width: parent.width * 0.5
      height: act.fontPx * 7
      color: "black"
      border.color: act.bright
      border.width: 2 * act.unit
      Line {
        anchors { horizontalCenter: parent.horizontalCenter; top: parent.top; topMargin: act.fontPx }
        text: "BYPASSING FIREWALL"
        color: act.bright
        font.pixelSize: act.fontPx * 1.4
        font.bold: true
      }
      Rectangle {
        anchors { left: parent.left; right: parent.right; bottom: parent.bottom; margins: act.fontPx * 1.2 }
        height: act.fontPx * 1.4
        color: "transparent"
        border.color: act.green
        Rectangle {
          anchors { left: parent.left; top: parent.top; bottom: parent.bottom; margins: 3 * act.unit }
          // Stalls at 99% for a moment, as it always does.
          width: (parent.width - 6 * act.unit) * Math.min(0.99, Math.max(0, (act.t - 7) / 6)) + ((act.t - 7) > 6.6 ? parent.width * 0.01 : 0)
          color: act.bright
        }
      }
    }
  }

  // Act 3: decrypting /proc.
  Item {
    anchors.fill: parent
    visible: act.stage === 2
    Line {
      anchors { horizontalCenter: parent.horizontalCenter; top: parent.top; topMargin: 60 * act.unit }
      text: "DECRYPTING /proc"
      color: act.bright
      font.pixelSize: act.fontPx * 1.6
      font.bold: true
    }
    Grid {
      anchors.centerIn: parent
      columns: 3
      columnSpacing: 40 * act.unit
      rowSpacing: act.fontPx * 0.6
      Repeater {
        model: act.feed ? act.feed.processes.slice(0, 18) : []
        Line {
          required property var modelData
          required property int index
          readonly property real reveal: Math.max(0, act.t - 14 - index * 0.25) * 12
          readonly property string real: Util.cleanText(String(modelData.name), 18)
          text: {
            var out = ""
            for (var i = 0; i < real.length; i++) out += i < reveal ? real.charAt(i) : "#$%&*@01"[Math.floor(Math.random() * 8)]
            return Util.pad(modelData.pid, 6) + " " + out
          }
          color: reveal > real.length ? act.bright : act.green
        }
      }
    }
  }

  // Act 4: the verdict.
  Line {
    anchors.centerIn: parent
    visible: act.stage === 3 && Math.floor(act.t * 4) % 2 === 0
    text: act.denied ? "ACCESS DENIED" : "ACCESS GRANTED"
    color: act.denied ? "#ff3b30" : act.bright
    font.pixelSize: act.fontPx * 5
    font.bold: true
  }

  // Act 5: the trace.
  Column {
    anchors.centerIn: parent
    visible: act.stage === 4
    spacing: act.fontPx * 0.6
    Line { text: "TRACE COMPLETE"; color: act.bright; font.pixelSize: act.fontPx * 2.4; font.bold: true }
    Line { text: "TARGET ........ " + act.target }
    Line { text: "PROCESSES ..... " + (act.feed ? act.feed.processCount : 0) }
    Line { text: "LINKS ......... " + (act.feed ? act.feed.connections.length : 0) }
    Line { text: "UPTIME ........ " + Util.formatDuration(act.feed ? act.feed.uptime : 0) }
    Line { text: "THREAT LEVEL .. NONE. IT IS YOUR OWN COMPUTER." ; color: act.bright }
  }

  FrameAnimation {
    running: act.active && act.visible
    onTriggered: act.step(Math.min(frameTime, 0.05))
  }

  onActiveChanged: if (active) reset()
  Component.onCompleted: reset()
}
