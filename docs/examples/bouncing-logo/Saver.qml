import QtQuick

// A minimal After Dark module. Everything it needs arrives through `host`
// (see docs/MODULES.md); it imports nothing from the plugin, so it works from
// ~/.config/mib-afterdark/screensavers/bouncing-logo/ as it is.
Item {
  id: root

  // Set by After Dark before Component.onCompleted.
  property var host: null
  // False while the screen is locked or the preview is hidden: stop working.
  property bool running: true

  readonly property string word: host ? host.option("word", "OMARCHY") : "OMARCHY"
  readonly property bool corners: host ? host.option("corners", true) === true : true
  readonly property var colors: ["#ff6b6b", "#feca57", "#48dbfb", "#1dd1a1", "#f368e0", "#ff9f43"]

  property real vx: 0.18
  property real vy: 0.13
  property int colorIndex: 0
  property int cornerHits: 0

  Rectangle { anchors.fill: parent; color: "black" }

  Text {
    id: logo
    textFormat: Text.PlainText
    text: root.word
    color: root.colors[root.colorIndex]
    font.family: "monospace"
    font.bold: true
    font.pixelSize: Math.max(16, root.height / 9)
  }

  Text {
    anchors { horizontalCenter: parent.horizontalCenter; bottom: parent.bottom; bottomMargin: root.height * 0.05 }
    visible: root.corners && root.cornerHits > 0
    textFormat: Text.PlainText
    text: "CORNER x" + root.cornerHits
    color: "white"
    font.family: "monospace"
    font.pixelSize: Math.max(12, root.height / 30)
  }

  FrameAnimation {
    running: root.running && root.visible
    onTriggered: {
      var dt = Math.min(frameTime, 0.05)
      var maxX = root.width - logo.width
      var maxY = root.height - logo.height
      logo.x += root.vx * root.height * dt
      logo.y += root.vy * root.height * dt
      var hitX = logo.x <= 0 || logo.x >= maxX
      var hitY = logo.y <= 0 || logo.y >= maxY
      if (hitX) { root.vx = -root.vx; logo.x = Math.max(0, Math.min(maxX, logo.x)) }
      if (hitY) { root.vy = -root.vy; logo.y = Math.max(0, Math.min(maxY, logo.y)) }
      if (hitX || hitY) root.colorIndex = (root.colorIndex + 1) % root.colors.length
      // The moment everyone waited for. It is remembered across runs.
      if (hitX && hitY && root.host) {
        root.cornerHits = (Number(root.host.get("corners", 0)) || 0) + 1
        root.host.set("corners", root.cornerHits)
      }
    }
  }

  Component.onCompleted: {
    if (root.host) root.cornerHits = Number(root.host.get("corners", 0)) || 0
    logo.x = Math.random() * 200
    logo.y = Math.random() * 200
  }
}
