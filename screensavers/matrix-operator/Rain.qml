import QtQuick
import "../../lib/Util.js" as Util

// Code rain, drawn by rain.frag from a glyph atlas: the atlas is 64 glyphs
// of real text rendered once, and the shader picks, fades and scrolls them,
// so the rain costs the CPU almost nothing. Real events surface two ways as
// text over the rain: spelled down a column, and decoded across the screen.
Item {
  id: rain

  property var feed: null
  property bool active: true
  property string glyphs: "katakana"
  property real unit: 1

  readonly property real cell: Math.round(20 * unit)
  readonly property int columns: Math.max(1, Math.ceil(width / cell))
  readonly property int rowsCount: Math.max(1, Math.ceil(height / cell))
  readonly property int trailLength: Math.max(8, Math.round(rowsCount * 0.45))

  // Katakana needs a CJK font; a monospaced one keeps the columns straight.
  readonly property string cjkFamily: {
    var families = Qt.fontFamilies()
    var fallback = ""
    for (var i = 0; i < families.length; i++) {
      if (/Mono CJK JP/.test(families[i])) return families[i]
      if (!fallback && /CJK|Source Han|IPAGothic|VL Gothic|Takao/.test(families[i])) fallback = families[i]
    }
    return fallback
  }
  readonly property bool katakana: glyphs === "katakana" && cjkFamily !== ""
  readonly property string glyphFamily: katakana ? cjkFamily : "monospace"

  // Up to 64 glyphs for the atlas.
  readonly property var glyphList: {
    if (glyphs === "binary") return ["0", "1"]
    var list = []
    if (katakana) for (var i = 0; i < 52; i++) list.push(String.fromCharCode(0xFF66 + i))
    var extra = "0123456789ZXEAKF:.=*+-<>|"
    for (var j = 0; j < extra.length && list.length < 64; j++) list.push(extra.charAt(j))
    return list
  }

  property real time: 0

  function surface(kind, text) {
    var label = Util.cleanText(text, 40).toUpperCase()
    if (!label) return
    drops.launch(label)
    // One in three also decodes across the screen.
    if (Math.random() < 0.34) decoder.show(kind.toUpperCase() + ": " + label)
  }

  Connections {
    target: rain.feed
    function onEvent(kind, text) { if (rain.active) rain.surface(kind, text) }
  }

  Rectangle { anchors.fill: parent; color: "black" }

  // The atlas: 8 x 8 cells of white glyphs, captured once.
  Grid {
    id: atlas
    columns: 8
    width: rain.cell * 8
    height: rain.cell * 8
    Repeater {
      model: rain.glyphList
      Text {
        required property string modelData
        width: rain.cell
        height: rain.cell
        textFormat: Text.PlainText
        font.family: rain.glyphFamily
        font.preferShaping: false
        font.pixelSize: Math.round(rain.cell * 0.85)
        horizontalAlignment: Text.AlignHCenter
        verticalAlignment: Text.AlignVCenter
        color: "white"
        text: modelData
      }
    }
  }

  ShaderEffectSource {
    id: atlasSource
    sourceItem: atlas
    hideSource: true
    smooth: true
  }

  ShaderEffect {
    anchors.fill: parent
    property var atlas: atlasSource
    property real time: rain.time
    property real cell: rain.cell
    property real trail: rain.trailLength
    property real glyphCount: rain.glyphList.length
    property vector2d resolution: Qt.vector2d(width, height)
    fragmentShader: Qt.resolvedUrl("rain.frag.qsb")
  }

  // Events spelled down a column, brighter than the rain around them.
  Item {
    id: drops
    anchors.fill: parent
    readonly property int pool: 6
    property var live: []

    function launch(label) {
      if (drops.live.length >= drops.pool) return
      var used = {}
      for (var i = 0; i < drops.live.length; i++) used[drops.live[i].slot] = true
      var slot = 0
      while (used[slot]) slot++
      drops.live.push({ slot: slot, text: label, col: Util.randInt(0, rain.columns - 1), row: -label.length, speed: Util.rand(9, 14) })
    }

    function step(dt) {
      var kept = []
      for (var i = 0; i < drops.live.length; i++) {
        var d = drops.live[i]
        d.row += d.speed * dt
        if (d.row < rain.rowsCount + 2) kept.push(d)
      }
      drops.live = kept
      var bySlot = {}
      for (var k = 0; k < kept.length; k++) bySlot[kept[k].slot] = kept[k]
      for (var s = 0; s < drops.pool; s++) {
        var item = dropRepeater.itemAt(s)
        if (!item) continue
        var drop = bySlot[s]
        item.visible = !!drop
        if (!drop) continue
        if (item.label !== drop.text) item.label = drop.text
        item.x = drop.col * rain.cell
        item.y = Math.floor(drop.row) * rain.cell
      }
    }

    Repeater {
      id: dropRepeater
      model: drops.pool
      Rectangle {
        property string label: ""
        visible: false
        width: rain.cell
        height: label.length * rain.cell
        color: "black"
        Text {
          anchors.fill: parent
          textFormat: Text.PlainText
          font.family: "monospace"
          font.preferShaping: false
          font.bold: true
          font.pixelSize: Math.round(rain.cell * 0.85)
          lineHeightMode: Text.FixedHeight
          lineHeight: rain.cell
          horizontalAlignment: Text.AlignHCenter
          color: "#9dffb8"
          text: parent.label.split("").join("\n")
        }
      }
    }
  }

  // A real event, decoded across the screen: random glyphs settle into the
  // text, it holds, and fades.
  Rectangle {
    id: decoder
    property string message: ""
    property real t: 10
    visible: t < 5
    color: Qt.rgba(0, 0, 0, 0.85)
    opacity: t > 4 ? Math.max(0, 5 - t) : 1
    width: decodedText.implicitWidth + rain.cell
    height: rain.cell * 1.6

    function show(text) {
      if (decoder.t < 5) return
      message = text
      t = 0
      x = Util.randInt(1, Math.max(1, Math.floor((rain.width - rain.cell * 0.6 * text.length) / rain.cell) - 1)) * rain.cell
      y = Util.randInt(2, Math.max(2, rain.rowsCount - 3)) * rain.cell
    }

    Text {
      id: decodedText
      anchors.centerIn: parent
      textFormat: Text.PlainText
      font.family: "monospace"
      font.preferShaping: false
      font.bold: true
      font.pixelSize: Math.round(rain.cell * 0.95)
      color: "#e9fff0"
      text: {
        var settled = Math.floor(decoder.t * 24)
        var out = ""
        for (var i = 0; i < decoder.message.length; i++)
          out += i < settled ? decoder.message.charAt(i) : "0123456789ABCDEF#$%&"[Math.floor(Math.random() * 20)]
        return out
      }
    }
  }

  FrameAnimation {
    running: rain.active && rain.visible
    onTriggered: {
      var dt = Math.min(frameTime, 0.05)
      rain.time += dt
      if (decoder.t < 5) decoder.t += dt
      if (drops.live.length) drops.step(dt)
    }
  }
}
