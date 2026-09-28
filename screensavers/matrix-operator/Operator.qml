import QtQuick
import "../../lib/Util.js" as Util

// The operator console: process table, network, event stream, and core
// telemetry, styled as a command-and-control screen rather than a monitor.
Item {
  id: console_

  property var feed: null
  property var host: null
  property bool active: true
  property real unit: 1

  readonly property color bright: "#9dffb8"
  readonly property color green: "#19c94a"
  readonly property color dim: "#0d5a24"
  readonly property real fontPx: Math.round(15 * unit)
  readonly property real pad: 14 * unit

  property var cpuHistory: []
  property var netHistory: []
  property string clock: ""
  property int blink: 0

  ListModel { id: events }

  function stamp() {
    return Qt.formatTime(new Date(), "hh:mm:ss")
  }

  function logEvent(kind, text) {
    var labels = { spawn: "SPAWN", exit: "EXIT ", journal: "UNIT ", package: "PKG  ", net: "LINK " }
    events.append({ line: "[" + stamp() + "] " + (labels[kind] || "EVT  ") + " " + Util.cleanText(text, 60), kind: kind })
    while (events.count > 60) events.remove(0)
    eventList.positionViewAtEnd()
  }

  Connections {
    target: console_.feed
    function onEvent(kind, text) { console_.logEvent(kind, text) }
  }

  Timer {
    interval: 1000
    repeat: true
    running: console_.active
    triggeredOnStart: true
    onTriggered: {
      console_.clock = Qt.formatDateTime(new Date(), "yyyy-MM-dd hh:mm:ss")
      console_.blink++
      if (!console_.feed) return
      console_.cpuHistory = console_.cpuHistory.slice(-119).concat([console_.feed.cpu])
      console_.netHistory = console_.netHistory.slice(-119).concat([console_.feed.rxRate + console_.feed.txRate])
      graph.requestPaint()
    }
  }

  function rate(bytes) {
    if (bytes > 1048576) return (bytes / 1048576).toFixed(1) + " MB/s"
    if (bytes > 1024) return (bytes / 1024).toFixed(0) + " KB/s"
    return Math.round(bytes) + " B/s"
  }

  component Label: Text {
    textFormat: Text.PlainText
    font.family: "monospace"
    font.preferShaping: false
    font.pixelSize: console_.fontPx
    color: console_.green
    elide: Text.ElideRight
  }

  component Panel: Rectangle {
    id: panel
    property string title: ""
    default property alias content: body.data
    color: Qt.rgba(0, 0.08, 0.02, 0.85)
    border.color: console_.dim
    border.width: Math.max(1, console_.unit)
    Rectangle {
      id: titleBar
      width: parent.width
      height: console_.fontPx * 1.7
      color: console_.dim
      Label {
        anchors { left: parent.left; leftMargin: console_.pad; verticalCenter: parent.verticalCenter }
        text: "// " + panel.title
        color: console_.bright
        font.bold: true
      }
    }
    Item {
      id: body
      anchors { fill: parent; topMargin: titleBar.height + console_.pad * 0.6; margins: console_.pad }
      clip: true
    }
  }

  Rectangle { anchors.fill: parent; color: "black" }

  // Header.
  Item {
    id: header
    anchors { left: parent.left; right: parent.right; top: parent.top; margins: console_.pad }
    height: console_.fontPx * 2.4
    Label {
      anchors { left: parent.left; verticalCenter: parent.verticalCenter }
      text: "OPERATOR CONSOLE // " + (console_.host && console_.host.hostName ? console_.host.hostName.toUpperCase() : "LOCALHOST")
        + " // OP " + (console_.host && console_.host.userName ? console_.host.userName.toUpperCase() : "UNKNOWN")
      color: console_.bright
      font.pixelSize: console_.fontPx * 1.4
      font.bold: true
    }
    Row {
      anchors { right: parent.right; verticalCenter: parent.verticalCenter }
      spacing: console_.pad
      Rectangle {
        anchors.verticalCenter: parent.verticalCenter
        width: console_.fontPx * 0.7
        height: width
        radius: width / 2
        color: console_.feed && console_.feed.live ? "#ff3b30" : "#f2c230"
        opacity: console_.blink % 2 ? 1 : 0.3
      }
      Label {
        text: (console_.feed && console_.feed.live ? "LIVE" : "SIMULATION") + "   " + console_.clock
        color: console_.bright
        font.pixelSize: console_.fontPx * 1.2
      }
    }
  }

  Grid {
    id: grid
    anchors { left: parent.left; right: parent.right; top: header.bottom; bottom: parent.bottom; margins: console_.pad }
    columns: 2
    spacing: console_.pad
    readonly property real cellW: (width - spacing) / 2
    readonly property real cellH: (height - spacing) / 2

    Panel {
      title: "PROCESS TABLE"
      width: grid.cellW
      height: grid.cellH
      Column {
        width: parent.width
        spacing: console_.fontPx * 0.25
        Label { text: "   PID  NAME                 CPU"; color: console_.bright }
        Repeater {
          model: console_.feed ? console_.feed.processes.slice(0, Math.max(1, Math.floor((grid.cellH - console_.fontPx * 5) / (console_.fontPx * 1.35)))) : []
          Item {
            required property var modelData
            width: parent.width
            height: console_.fontPx * 1.1
            Label {
              width: parent.width * 0.62
              text: Util.pad(modelData.pid, 6) + "  " + Util.cleanText(String(modelData.name), 20)
            }
            Rectangle {
              x: parent.width * 0.64
              anchors.verticalCenter: parent.verticalCenter
              // Scaled to the busiest process, so an idle machine still shows a ranking.
              width: parent.width * 0.26 * Math.min(1, modelData.cpu / Math.max(5, console_.feed.processes.length ? console_.feed.processes[0].cpu : 5))
              height: console_.fontPx * 0.6
              color: modelData.cpu > 50 ? console_.bright : console_.green
            }
            Label {
              anchors.right: parent.right
              text: modelData.cpu.toFixed(1)
              color: console_.bright
            }
          }
        }
      }
    }

    Panel {
      title: "NETWORK"
      width: grid.cellW
      height: grid.cellH
      Column {
        width: parent.width
        spacing: console_.fontPx * 0.25
        Label {
          text: "RX " + console_.rate(console_.feed ? console_.feed.rxRate : 0) + "   TX " + console_.rate(console_.feed ? console_.feed.txRate : 0)
            + "   SSH " + (console_.feed ? console_.feed.sshSessions : 0)
          color: console_.bright
        }
        Repeater {
          model: console_.feed ? console_.feed.connections.slice(-Math.max(1, Math.floor((grid.cellH - console_.fontPx * 5) / (console_.fontPx * 1.35)))) : []
          Label {
            required property var modelData
            width: parent.width
            text: Util.pad(modelData.proto.toUpperCase(), 3) + " " + Util.pad(modelData.state, 6) + "  "
              + Util.cleanText(String(modelData.process || "?"), 14) + "  ->  " + modelData.peer + ":" + modelData.port
          }
        }
      }
    }

    Panel {
      title: "EVENT STREAM"
      width: grid.cellW
      height: grid.cellH
      ListView {
        id: eventList
        anchors.fill: parent
        model: events
        interactive: false
        delegate: Label {
          required property string line
          required property string kind
          width: eventList.width
          text: line
          color: kind === "spawn" ? console_.bright : (kind === "exit" ? "#f2c230" : console_.green)
        }
      }
    }

    Panel {
      title: "CORE"
      width: grid.cellW
      height: grid.cellH
      Row {
        id: stats
        spacing: console_.pad * 3
        Column {
          Label { text: "CPU"; color: console_.green }
          Label {
            text: Math.round((console_.feed ? console_.feed.cpu : 0) * 100) + "%"
            color: console_.bright
            font.pixelSize: console_.fontPx * 3.6
            font.bold: true
          }
        }
        Column {
          Label { text: "MEM"; color: console_.green }
          Label {
            text: Math.round((console_.feed ? console_.feed.mem : 0) * 100) + "%"
            color: console_.bright
            font.pixelSize: console_.fontPx * 3.6
            font.bold: true
          }
        }
        Column {
          spacing: console_.fontPx * 0.3
          Label { text: "LOAD   " + (console_.feed ? console_.feed.load1.toFixed(2) : "0.00") }
          Label { text: "PROCS  " + (console_.feed ? console_.feed.processCount : 0) }
          Label { text: "UPTIME " + Util.formatDuration(console_.feed ? console_.feed.uptime : 0) }
          Label { text: "NODES  " + (console_.feed ? console_.feed.connections.length : 0) + " LINKED" }
        }
      }
      Canvas {
        id: graph
        anchors { left: parent.left; right: parent.right; top: stats.bottom; bottom: parent.bottom; topMargin: console_.pad }
        onPaint: {
          var ctx = getContext("2d")
          ctx.clearRect(0, 0, width, height)
          ctx.strokeStyle = "#0d5a24"
          ctx.lineWidth = 1
          ctx.beginPath()
          for (var g = 1; g < 4; g++) { ctx.moveTo(0, height * g / 4); ctx.lineTo(width, height * g / 4) }
          ctx.stroke()
          function trace(list, scale, color) {
            if (list.length < 2) return
            ctx.strokeStyle = color
            ctx.lineWidth = Math.max(1, 2 * console_.unit)
            ctx.beginPath()
            for (var i = 0; i < list.length; i++) {
              var x = width - (list.length - 1 - i) * width / 119
              var y = height - Math.min(1, list[i] / scale) * height * 0.95
              if (i === 0) ctx.moveTo(x, y)
              else ctx.lineTo(x, y)
            }
            ctx.stroke()
          }
          var peak = 1
          for (var n = 0; n < console_.netHistory.length; n++) peak = Math.max(peak, console_.netHistory[n])
          trace(console_.netHistory, peak * 1.1, "rgba(242,194,48,0.8)")
          trace(console_.cpuHistory, 1, "#9dffb8")
        }
      }
    }
  }

  // Scanlines over everything.
  Column {
    anchors.fill: parent
    Repeater {
      model: Math.ceil(console_.height / 4)
      Rectangle { width: console_.width; height: 2; color: Qt.rgba(0, 0, 0, 0.18); y: 0 }
    }
    spacing: 2
  }
}
