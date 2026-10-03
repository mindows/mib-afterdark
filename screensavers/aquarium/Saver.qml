import QtQuick
import "../../lib/Util.js" as Util

// Terminal Aquarium: an ASCII tank. On its own it is a calm scene of fish,
// crabs and seaweed. With live system data it reacts to the machine: CPU
// load makes bubbles, network traffic brings schools of fish, each SSH
// session sends a submarine, and the battery level sets the light.
Item {
  id: root

  property var host: null
  property bool running: true

  readonly property var system: host ? host.system : null
  readonly property string population: host ? host.option("population", "normal") : "normal"
  readonly property string water: host ? host.option("water", "deep") : "deep"
  readonly property bool preview: host ? host.preview : false

  readonly property real unit: Math.max(0.5, height / 1080)
  readonly property real fontPx: Math.round(20 * unit)
  readonly property real charW: fontPx * 0.6
  readonly property real lineH: fontPx * 1.15
  readonly property real sandTop: height - lineH * 3.2
  readonly property int maxCreatures: 48
  readonly property int maxBubbles: 70

  readonly property int fishTarget: {
    var n = population === "sparse" ? 7 : (population === "crowded" ? 22 : 13)
    return preview ? Math.ceil(n / 2) : n
  }

  readonly property var fishColors: ["#ff9f43", "#feca57", "#ff6b6b", "#48dbfb", "#1dd1a1", "#f368e0", "#c8d6e5", "#ffb8b8"]

  // Right-facing art; left-facing copies are mirrored in code.
  readonly property var fishArt: [
    ["><>"],
    ["><((('>"],
    ["  __", "\\/ o\\", "/\\__/"],
    ["   _.-._", "><_  o  >", "   '-.-'"],
    ["    ___", "|\\ /   \\", "| >  o  >", "|/ \\___/"],
    ["  ,  ", "><=o>"]
  ]
  readonly property var submarineArt: [
    "        |",
    "      __|__",
    "  ___/_____\\____",
    " (  o   o   o   )>",
    "  '~~~~~~~~~~~~~'"
  ]
  readonly property var rootSubArt: [
    "   root",
    "    _|_",
    "  _(o_o)>"
  ]
  readonly property var tuxArt: [
    "  _",
    " (o>",
    " //\\",
    " V_/_"
  ]
  readonly property var whaleArt: [
    "           .  .",
    "            ::",
    "      _.-''''''-._",
    "  _.-'  o          '-._/|",
    " (_____________________ <",
    "                       \\|"
  ]
  readonly property var crabArt: ["(\\/)(o,,o)(\\/)"]

  property var creatures: []
  property var bubbles: []
  property real clock: 0
  property real spawnClock: 0
  property real bubbleBudget: 0
  property real schoolCooldown: 0
  property real rareClock: 20
  property real lastNet: 0

  function mirrorLine(line) {
    var swap = { "<": ">", ">": "<", "(": ")", ")": "(", "/": "\\", "\\": "/", "{": "}", "}": "{", "[": "]", "]": "[", "`": "'", "'": "`" }
    var out = ""
    for (var i = line.length - 1; i >= 0; i--) {
      var ch = line.charAt(i)
      out += swap[ch] || ch
    }
    return out
  }

  function orient(lines, facingRight) {
    if (facingRight) return lines
    var width = 0
    for (var i = 0; i < lines.length; i++) width = Math.max(width, lines[i].length)
    var out = []
    for (var j = 0; j < lines.length; j++) {
      var padded = lines[j]
      while (padded.length < width) padded += " "
      out.push(mirrorLine(padded))
    }
    return out
  }

  function artWidth(lines) {
    var w = 0
    for (var i = 0; i < lines.length; i++) w = Math.max(w, lines[i].length)
    return w * root.charW
  }

  function add(kind, art, color, speed, y, facingRight) {
    if (root.creatures.length >= root.maxCreatures) return null
    var lines = orient(art, facingRight)
    var w = artWidth(lines)
    var c = {
      kind: kind, text: lines.join("\n"), color: color, w: w,
      x: facingRight ? -w - Util.rand(0, 200) * root.unit : root.width + Util.rand(0, 200) * root.unit,
      y: y, vx: (facingRight ? 1 : -1) * speed * root.unit,
      bob: Math.random() * 6.28, bobAmp: Util.rand(2, 8) * root.unit
    }
    root.creatures.push(c)
    return c
  }

  function swimY() {
    return Util.rand(root.height * 0.08, root.sandTop - root.lineH * 4)
  }

  function addFish(scattered) {
    var art = Util.pick(root.fishArt)
    var right = Math.random() < 0.5
    var c = add("fish", art, Util.pick(root.fishColors), Util.rand(25, 90) / Math.sqrt(art.length), swimY(), right)
    if (c && scattered) c.x = Util.rand(0, root.width - c.w)
    return c
  }

  function addSchool() {
    var right = Math.random() < 0.5
    var y = swimY()
    var color = Util.pick(root.fishColors)
    var speed = Util.rand(90, 140)
    for (var i = 0; i < 12; i++) {
      var c = add("school", ["><>"], color, speed, y + Util.rand(-60, 60) * root.unit, right)
      if (c) c.x += (right ? -1 : 1) * Util.rand(0, 260) * root.unit
    }
  }

  function countKind(kind) {
    var n = 0
    for (var i = 0; i < root.creatures.length; i++) if (root.creatures[i].kind === kind) n++
    return n
  }

  function addBubble(x, y) {
    if (root.bubbles.length >= root.maxBubbles) return
    root.bubbles.push({ x: x, y: y, vy: Util.rand(40, 90) * root.unit, phase: Math.random() * 6.28, ch: Util.pick([".", "o", "o", "O", "°"]) })
  }

  function rareEvent() {
    var roll = Math.random()
    if (roll < 0.35) {
      // The smallest submarine in the fleet, and the most privileged.
      add("rare", root.rootSubArt, "#f2c230", 35, swimY(), Math.random() < 0.5)
    } else if (roll < 0.7) {
      add("rare", root.tuxArt, "#f5f5f0", 55, swimY(), Math.random() < 0.5)
    } else {
      add("rare", root.whaleArt, "#9fb4c7", 22, root.height * 0.12, Math.random() < 0.5)
    }
  }

  function step(dt) {
    if (root.width <= 0) return
    root.clock += dt
    var sys = root.system

    // Keep the tank stocked.
    root.spawnClock -= dt
    if (root.spawnClock <= 0) {
      if (countKind("fish") < root.fishTarget) addFish(root.clock < 1)
      root.spawnClock = root.clock < 1 ? 0 : Util.rand(0.4, 2.5)
    }
    if (root.clock < 1) {
      while (countKind("fish") < root.fishTarget && root.creatures.length < root.maxCreatures) addFish(true)
      if (countKind("crab") === 0) {
        var crab = add("crab", root.crabArt, "#ff7f50", 18, root.sandTop - root.lineH * 0.9, true)
        if (crab) crab.x = Util.rand(0, root.width * 0.6)
      }
    }

    // CPU makes bubbles; an idle machine still breathes a little.
    var cpu = sys ? Util.clamp(sys.cpu, 0, 1) : 0.08
    root.bubbleBudget += dt * (0.8 + cpu * 26)
    while (root.bubbleBudget >= 1) {
      root.bubbleBudget -= 1
      var fromCastle = Math.random() < 0.3
      addBubble(fromCastle ? castle.x + castle.width * 0.5 : Util.rand(0, root.width), root.sandTop)
    }

    // Network traffic brings a school through.
    root.schoolCooldown -= dt
    if (sys && root.schoolCooldown <= 0 && (sys.rxRate + sys.txRate) > 256 * 1024) {
      addSchool()
      root.schoolCooldown = 25
    }

    // One submarine per SSH session; without system data, now and then.
    var wantSubs = sys ? Math.min(3, sys.sshSessions) : 0
    if (countKind("sub") < wantSubs && Util.chance(120)) add("sub", root.submarineArt, "#b8c4cf", 30, swimY(), Math.random() < 0.5)

    root.rareClock -= dt
    if (root.rareClock <= 0) {
      root.rareClock = 20
      var odds = sys ? 40 : 30
      if (!sys && Util.chance(12)) add("sub", root.submarineArt, "#b8c4cf", 30, swimY(), Math.random() < 0.5)
      if (root.host ? root.host.rare(odds) : Util.chance(odds)) rareEvent()
    }

    var kept = []
    for (var i = 0; i < root.creatures.length; i++) {
      var c = root.creatures[i]
      c.x += c.vx * dt
      c.bob += dt * (c.kind === "crab" ? 0 : 1.3)
      if (c.kind === "crab") {
        // Crabs pace the sand and turn around at the glass.
        if (c.x < 0 || c.x + c.w > root.width) c.vx = -c.vx
        if (Util.chance(400)) c.vx = -c.vx
      }
      var gone = (c.vx > 0 && c.x > root.width + 40) || (c.vx < 0 && c.x + c.w < -40)
      if (!gone) kept.push(c)
      if ((c.kind === "sub" || c.kind === "fish") && Util.chance(c.kind === "sub" ? 20 : 900)) addBubble(c.x + c.w / 2, c.y)
    }
    root.creatures = kept

    var keptBubbles = []
    for (var b = 0; b < root.bubbles.length; b++) {
      var bubble = root.bubbles[b]
      bubble.y -= bubble.vy * dt
      bubble.phase += dt * 3
      if (bubble.y > root.height * 0.02) keptBubbles.push(bubble)
    }
    root.bubbles = keptBubbles
    sync()
  }

  function sync() {
    for (var i = 0; i < root.maxCreatures; i++) {
      var item = creatureRepeater.itemAt(i)
      if (!item) continue
      var c = root.creatures[i]
      if (!c) { item.visible = false; continue }
      if (item.text !== c.text) item.text = c.text
      item.color = c.color
      item.x = c.x
      item.y = c.y + Math.sin(c.bob) * c.bobAmp
      item.visible = true
    }
    for (var b = 0; b < root.maxBubbles; b++) {
      var dot = bubbleRepeater.itemAt(b)
      if (!dot) continue
      var bubble = root.bubbles[b]
      if (!bubble) { dot.visible = false; continue }
      dot.text = bubble.ch
      dot.x = bubble.x + Math.sin(bubble.phase) * 6 * root.unit
      dot.y = bubble.y
      dot.visible = true
    }
  }

  // ------------------------------------------------------------------ scene

  readonly property var waterColors: {
    if (water === "tropical") return ["#0a6b8a", "#063d5c", "#04253a"]
    if (water === "theme" && host) {
      var bg = host.background, ac = host.accent
      return [Qt.tint(bg, Qt.rgba(ac.r, ac.g, ac.b, 0.35)), Qt.tint(bg, Qt.rgba(ac.r, ac.g, ac.b, 0.18)), bg]
    }
    return ["#0b2a4a", "#071a30", "#030b16"]
  }

  Rectangle {
    anchors.fill: parent
    gradient: Gradient {
      GradientStop { position: 0; color: root.waterColors[0] }
      GradientStop { position: 0.55; color: root.waterColors[1] }
      GradientStop { position: 1; color: root.waterColors[2] }
    }
  }

  // Light from above.
  Repeater {
    model: 5
    Rectangle {
      required property int index
      x: root.width * (0.12 + index * 0.19) + Math.sin(root.clock * 0.3 + index) * 40 * root.unit
      y: -root.height * 0.1
      width: root.width * 0.05
      height: root.height * 0.9
      rotation: 12 + index * 3
      transformOrigin: Item.Top
      gradient: Gradient {
        GradientStop { position: 0; color: Qt.rgba(1, 1, 1, 0.07) }
        GradientStop { position: 1; color: Qt.rgba(1, 1, 1, 0) }
      }
    }
  }

  Text {
    anchors { left: parent.left; right: parent.right; top: parent.top; topMargin: root.lineH * 0.4 }
    textFormat: Text.PlainText
    font.family: "monospace"
    font.preferShaping: false
    font.pixelSize: root.fontPx
    color: Qt.rgba(0.7, 0.85, 1, 0.35)
    clip: true
    text: {
      var s = ""
      var n = Math.ceil(root.width / root.charW) + 8
      var shift = Math.floor(root.clock * 2) % 4
      for (var i = 0; i < n; i++) s += "~^~-"[(i + shift) % 4]
      return s
    }
  }

  // Seaweed, swaying.
  Repeater {
    model: Math.max(3, Math.round(root.width / (220 * root.unit)))
    Column {
      id: weed
      required property int index
      readonly property real seed: Math.sin(index * 91.7) * 1000
      readonly property int tall: 4 + Math.floor((seed - Math.floor(seed)) * 7)
      x: (index + 0.3 + (seed - Math.floor(seed)) * 0.4) * root.width / Math.max(3, Math.round(root.width / (220 * root.unit)))
      y: root.sandTop - tall * root.lineH + root.lineH * 0.4
      Repeater {
        model: weed.tall
        Text {
          required property int index
          textFormat: Text.PlainText
          font.family: "monospace"
          font.preferShaping: false
          font.pixelSize: root.fontPx
          color: "#2e8b57"
          x: Math.sin(root.clock * 1.2 + weed.index + index * 0.6) * (weed.tall - index) * 2.2 * root.unit
          text: (index + Math.floor(root.clock * 1.5)) % 2 === 0 ? "(" : ")"
        }
      }
    }
  }

  Text {
    id: castle
    x: root.width * 0.72
    y: root.sandTop - height + root.lineH * 0.3
    textFormat: Text.PlainText
    font.family: "monospace"
    font.preferShaping: false
    font.pixelSize: root.fontPx
    color: "#8c8c9a"
    text: "   |>\n   |\n /^\\ /^\\\n |#|_|#|\n | _  _ |\n |_[]___|"
  }

  // The sand.
  Rectangle {
    x: 0
    y: root.sandTop
    width: root.width
    height: root.height - root.sandTop
    color: "#3a2f1f"
    Text {
      anchors.fill: parent
      textFormat: Text.PlainText
      font.family: "monospace"
      font.preferShaping: false
      font.pixelSize: root.fontPx
      color: "#c2a36b"
      clip: true
      text: {
        var line = ""
        var n = Math.ceil(root.width / root.charW) + 2
        for (var i = 0; i < n; i++) line += "._,-.'`,._"[(i * 7) % 10]
        return line + "\n" + line.split("").reverse().join("") + "\n" + line
      }
    }
  }

  Repeater {
    id: bubbleRepeater
    model: root.maxBubbles
    Text {
      visible: false
      textFormat: Text.PlainText
      font.family: "monospace"
      font.preferShaping: false
      font.pixelSize: root.fontPx
      color: Qt.rgba(0.8, 0.95, 1, 0.75)
    }
  }

  Repeater {
    id: creatureRepeater
    model: root.maxCreatures
    Text {
      visible: false
      textFormat: Text.PlainText
      font.family: "monospace"
      font.preferShaping: false
      font.pixelSize: root.fontPx
      lineHeight: 1.0
    }
  }

  // The battery sets the light: a draining battery dims the tank.
  Rectangle {
    anchors.fill: parent
    color: "black"
    opacity: root.system && root.system.battery >= 0 ? (1 - root.system.battery) * 0.45 : 0
  }

  FrameAnimation {
    running: root.running && root.visible
    onTriggered: root.step(Math.min(frameTime, 0.05))
  }
}
