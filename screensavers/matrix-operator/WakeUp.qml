import QtQuick

// The rare one. Types four lines on an empty screen, one at a time, then
// asks to be put away.
Item {
  id: wake

  property string userName: ""
  property bool active: false
  signal finished()

  readonly property string who: userName ? userName.charAt(0).toUpperCase() + userName.slice(1) : "Neo"
  readonly property var lines: [
    "Wake up, " + who + "...",
    "The Matrix has you...",
    "Follow the white rabbit.",
    "Knock, knock, " + who + "."
  ]
  property int line: 0
  property real t: 0
  property string shown: ""

  function start() {
    wake.line = 0
    wake.t = 0
    wake.shown = ""
  }

  onActiveChanged: if (active) start()

  Rectangle { anchors.fill: parent; color: "black" }

  Text {
    x: parent.width * 0.08
    y: parent.height * 0.12
    textFormat: Text.PlainText
    font.family: "monospace"
    font.preferShaping: false
    font.pixelSize: Math.round(Math.max(18, parent.height / 32))
    color: "#19c94a"
    text: wake.shown + (Math.floor(wake.t * 2.5) % 2 === 0 ? "█" : " ")
  }

  FrameAnimation {
    running: wake.active
    onTriggered: {
      wake.t += Math.min(frameTime, 0.05)
      var full = wake.lines[wake.line] || ""
      // Each line types out, holds, then clears for the next.
      var typed = Math.floor(wake.t * 11)
      wake.shown = full.slice(0, Math.min(full.length, typed))
      if (wake.t > full.length / 11 + 2.6) {
        wake.line++
        wake.t = 0
        if (wake.line >= wake.lines.length) wake.finished()
      }
    }
  }
}
