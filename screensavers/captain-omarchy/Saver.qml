import QtQuick
import "../../lib"
import "../../lib/PixelFont.js" as Font
import "../../lib/Util.js" as Util

// Captain Omarchy: the opening of a 1985 home-computer spy caper, on a loop.
// A title card, then a helicopter comes in over a starry field and lands by
// the field briefing sign. The captain hops out and waves it off, then runs
// to the briefing hut, and the base commander's orders type out on a
// teletype. Everything is painted once and then only moved.
//
// Inspired by the opening of Captain Goodnight and the Islands of Fear
// (Broderbund, 1985). The artwork and the story here are new.
Item {
  id: root

  property var host: null
  property bool running: true

  readonly property bool preview: host ? host.preview : false
  readonly property bool themed: (host ? host.option("color", "1985") : "1985") === "theme"
  readonly property bool showTitle: host ? host.option("title", true) !== false : true
  readonly property bool showBriefing: host ? host.option("briefing", true) !== false : true

  readonly property real unit: Math.max(0.5, height / 1080)
  // One art pixel, in whole screen pixels so the sprites stay crisp. Sized
  // so the helicopter spans about a third of a wide screen, as it did the
  // original's, and still fits across a portrait one.
  readonly property int px: Math.max(1, Math.round(Math.min(height / 130, width / 150)))
  // The sign's lettering is finer than the rest.
  readonly property int signPx: Math.max(1, Math.round(px * 0.6))
  readonly property int groundY: Math.round(height * 0.8)
  readonly property int barY: groundY + 10 * px

  // ---------------------------------------------------------------- colors

  function mix(a, b, t) {
    return Qt.tint(a, Qt.rgba(b.r, b.g, b.b, t))
  }

  readonly property var scene: {
    if (!themed || !host) return {
      sky: "#000000", star: "#ffffff", ground: "#3fd13a", bar: "#ffffff", barText: "#1f6fe0",
      text: "#ffffff", frameOuter: "#f2681e", frameInner: "#2a9df4", title: "#ffffff", subtitle: "#f2681e"
    }
    var bg = host.background, fg = host.foreground, ac = host.accent
    return {
      sky: String(bg), star: String(fg), ground: String(ac), bar: String(fg), barText: String(bg),
      text: String(fg), frameOuter: String(ac), frameInner: String(mix(bg, fg, 0.5)),
      title: String(fg), subtitle: String(ac)
    }
  }

  // The sprites keep their trim colors in either mode, as the helicopter's
  // livery would. With theme colors their white and black follow the
  // theme's foreground and background, so they still stand out from a light
  // sky.
  readonly property var ink: {
    var trim = { O: "#f2681e", B: "#2a9df4", G: "#3fd13a", V: "#c35cff" }
    if (!themed || !host) {
      trim.W = "#ffffff"
      trim.K = "#000000"
      trim.S = "#8fa9c8"
    } else {
      trim.W = String(host.foreground)
      trim.K = String(host.background)
      trim.S = String(mix(host.background, host.foreground, 0.6))
    }
    return trim
  }

  // ---------------------------------------------------------------- art

  // The helicopter, nose to the right. Its door, both rotors and whoever is
  // standing in the doorway are separate pieces laid over it.
  readonly property var heliArt: [
    ".......................................................WWW........................",
    ".......WWW....................................WWWWWWWWWWWWWWWWWWW.................",
    "......WWWW.............................GKGGGGWWWWWWWWWWWWWKKWWWWWW................",
    ".....WWWWW.............................GKGKKGKKKKWWWKKWWWWWWKWWWWWWW..............",
    ".....WWWWW.............................GKGGGGWWWWWWKWWWWWWWWWWWWWWWWWWW...........",
    "....WWWWWWW...........................WWWWWWWWWWWWWWWWKKKKKKKKKWWKKKKWKK..........",
    "...WWWKKKWWW.........................WWWWWWWWWWWWWWWKKWKKKKKKKKWWKKKKWKBBW........",
    "..WWWKWWWKWWW......................WWWWWWWWWOOOWOOOWWWWKKKKKKKKWWKKKKWKBBKW.......",
    ".WWWKWWWWWKWWWWKWWWWWWWWWWWWWWWWWWWWWWWWWWWWOWWWOWOWWWWKKKKKKKKWWKKKKWKKBKKWW.....",
    ".WWWKWWWWWKWWWKWWOWOWOWWBBBBBBBBBBBWWWWWWWWWOWWWOWOWWWWKKKKKKKKWWWWWWWWWWWWWWWW...",
    ".WWWKWWWWWKWWWKWWOWOWOWWBBBBBBBBBBBWWWWWWWWWOWWWOWOWWWWKKKKKKKKWWWWWWWWBBOOWWWWW..",
    ".WWWWKWWWKWWWWWKWWWWWWWWWWWWWWWWWWWWWWWWWWWWOOOWOOOWWWWKKKKKKKKWWWWWWWWBBOOWWWWWW.",
    "..WWWWKKKWWWW............WWWW........WWWWWWWWWWWWWWWWWWKKKKKKKKWWWWWWWWBBOOWWWWW..",
    "...WWWWWWWWW.............WWW...........WWWWWWWWWWWWWWWWKKKKKKKKWWWWWWWWBBOOWWW....",
    "....WWWWWWW...............W..............WWWWWWWWWWWWWWWWWWWWWWWWWWWWWWWWWWWW.....",
    ".....WWWW....................................W......................W.............",
    "......WW................................W....W......................W.....W.......",
    ".........................................WWWWWWWWWWWWWWWWWWWWWWWWWWWWWWWWW........"
  ]
  readonly property int heliCols: heliArt[0].length
  readonly property int heliRows: heliArt.length
  // Where the pieces sit on the helicopter, in art pixels.
  readonly property point doorAt: Qt.point(55, 5)
  readonly property point tailRotorAt: Qt.point(5, 7)
  readonly property real hubX: 56.5

  readonly property var doorArt: [
    "KKKKKKKK",
    "KWWWWWWK",
    "KWKKKKWK",
    "KWKKKKWK",
    "KWWWWWWK",
    "KWWWWWWK",
    "KWWWWOWK",
    "KWWWWWWK",
    "KKKKKKKK"
  ]

  // The tail rotor turning, seen edge on through its ring.
  readonly property var tailRotorFrames: [
    [".....", ".....", "KKKKK", ".....", "....."],
    ["K....", ".K...", "..K..", "...K.", "....K"],
    ["..K..", "..K..", "..K..", "..K..", "..K.."],
    ["....K", "...K.", "..K..", ".K...", "K...."]
  ]
  // The main rotor's span as it turns, in art pixels.
  readonly property var rotorSpans: [60, 44, 22, 44]

  // The captain, facing right. S is the far arm and leg, a shade darker,
  // so the run reads as the legs trading places. The run is two strides of
  // four poses each: reaching, sinking onto a bent knee, passing, and
  // driving off with the other knee up. The back foot is only on the
  // ground for the drive; the rest of the time its heel is kicked up.
  readonly property var captainFrames: [
    // Standing
    [
      "....WWW.....",
      "...WWWBB....",
      "...WWWBB....",
      "....WWW.....",
      ".....W......",
      "...WWWWW....",
      "..WWBWOWW...",
      "..W.BWO.W...",
      "..W.WWW.W...",
      "....OOO.....",
      "....WWW.....",
      "....W.W.....",
      "....W.W.....",
      "....W.W.....",
      "...WW.WW...."
    ],
    // Waving
    [
      "....WWW..W..",
      "...WWWBB.W..",
      "...WWWBB.W..",
      "....WWW.W...",
      ".....W.W....",
      "...WWWWW....",
      "..WWBWO.....",
      "..W.BWO.....",
      "..W.WWW.....",
      "....OOO.....",
      "....WWW.....",
      "....W.W.....",
      "....W.W.....",
      "....W.W.....",
      "...WW.WW...."
    ],
    // Running: contact, near leg leading
    [
      "....WWW.....",
      "...WWWBB....",
      "...WWWBB....",
      "....WWW.....",
      ".....W......",
      "...WWWWW....",
      "..W.BWOW.S..",
      ".WW.BWO..SS.",
      "WW..WWW.....",
      "....OOO.....",
      "....WWWW....",
      "SS.SS..WW...",
      ".SSS....WW..",
      "........WW..",
      "........WWW."
    ],
    // Running: down, near leg leading
    [
      "............",
      ".....WWW....",
      "....WWWBB...",
      "....WWWBB...",
      ".....WWW....",
      "......W.....",
      "....WWWWW...",
      "..WWBWOWSSS.",
      ".WW.BWO.....",
      "....OOO.....",
      "SS..WWWWW...",
      ".SS.S..WWW..",
      "..SSS..WW...",
      "......WW....",
      "......WWW..."
    ],
    // Running: passing, near leg leading
    [
      "....WWW.....",
      "...WWWBB....",
      "...WWWBB....",
      "....WWW.....",
      ".....W......",
      "...WWWWW....",
      "...WBWOWS...",
      "..W.BWO.S...",
      "..W.WWW.....",
      "....OOO.....",
      "....WWW.....",
      "..SS.WW.....",
      "...SSSW.....",
      ".....WW.....",
      ".....WWW...."
    ],
    // Running: push-off, near leg leading
    [
      "....WWW.....",
      "...WWWBB....",
      "...WWWBB....",
      "....WWW.....",
      ".....W......",
      "...WWWWW....",
      "..S.BWOW.W..",
      ".SS.BWO..WW.",
      "SS..WWW.....",
      "....OOOSSS..",
      "....WWW..SS.",
      "...WWW...S..",
      "..WWW.......",
      ".WW.........",
      "WW.........."
    ],
    // Running: contact, far leg leading
    [
      "....WWW.....",
      "...WWWBB....",
      "...WWWBB....",
      "....WWW.....",
      ".....W......",
      "...WWWWW....",
      "..S.BWOS.W..",
      ".SS.BWO..WW.",
      "SS..WWW.....",
      "....OOO.....",
      "....WWWS....",
      "WW.WS..SS...",
      ".WWW....SS..",
      "........SS..",
      "........SSS."
    ],
    // Running: down, far leg leading
    [
      "............",
      ".....WWW....",
      "....WWWBB...",
      "....WWWBB...",
      ".....WWW....",
      "......W.....",
      "....WWWWW...",
      "..SSBWOSWWW.",
      ".SS.BWO.....",
      "....OOO.....",
      "WW..WWWSS...",
      ".WW.S..SSS..",
      "..WWS..SS...",
      "......WS....",
      "......WSS..."
    ],
    // Running: passing, far leg leading
    [
      "....WWW.....",
      "...WWWBB....",
      "...WWWBB....",
      "....WWW.....",
      ".....W......",
      "...WWWWW....",
      "...SBWOSW...",
      "..S.BWO.W...",
      "..S.WWW.....",
      "....OOO.....",
      "....WWW.....",
      "..WW.WW.....",
      "...WSSW.....",
      ".....WW.....",
      ".....WWS...."
    ],
    // Running: push-off, far leg leading
    [
      "....WWW.....",
      "...WWWBB....",
      "...WWWBB....",
      "....WWW.....",
      ".....W......",
      "...WWWWW....",
      "..W.BWOS.S..",
      ".WW.BWO..SS.",
      "WW..WWW.....",
      "....OOOWWW..",
      "....WWW..WW.",
      "...SWW...W..",
      "..SSW.......",
      ".SS.........",
      "SS.........."
    ]
  ]
  readonly property int captainStand: 0
  readonly property int captainWave: 1
  readonly property int captainRun: 2
  readonly property int captainCols: captainFrames[0][0].length
  readonly property int captainRows: captainFrames[0].length

  // The briefing hut: a log cabin with its door on the right.
  readonly property var hutArt: [
    "..OOOOOOOOOOOOOOOOOOOOOOOOOOOOOOOOOOOOOOOOOOOOO..",
    ".OOOOOOOOOOOOOOOOOOOOOOOOOOOOOOOOOOOOOOOOOOOOOOOO",
    "...WWBWWWWWWBWWWWWWBWWWWWWBWWWWWWBWWWWWWBWWWWW...",
    "...WWBWWWWWWBWWWWWWBWWWWWWBWWWWWWBWWWWWWBWWWWW...",
    "...WWWWWWWWWWWWWWWWWWWWWWWWWWWWWWWWWWWWWWWWWWW...",
    "...KKKKKKWWWWWWWWWWWKKKKKKKKKKKKKKKWWWWWWWWKKK...",
    "...WWWWWWWOOOOOOOOOWWWWWWWWWWWWWWWWWKKKKKKWWWW...",
    "...KKKKKKWOBBBBBBBOWKKKKKKKKKKKKKKKWOOOOOOWKKK...",
    "...WWWWWWWOBKKKKKBOWWWWWWWWWWWWWWWWWOOOOOOWWWW...",
    "...KKKKKKWOBKKKKKBOWKKKKKKKKKKKKKKKWOOOOOOWKKK...",
    "...WWWWWWWOBWWWWWBOWWWWWWWWWWWWWWWWWOOOOOOWWWW...",
    "...KKKKKKWOBKKKKKBOWKKKKKKKKKKKKKKKWOOOOWOWKKK...",
    "...WWWWWWWOBKKKKKBOWWWWWWWWWWWWWWWWWOOOOOOWWWW...",
    "...KKKKKKWOBBBBBBBOWKKKKKKKKKKKKKKKWOOOOOOWKKK...",
    "...WWWWWWWOOOOOOOOOWWWWWWWWWWWWWWWWWOOOOOOWWWW...",
    "...KKKKKKWWWWWWWWWWWKKKKKKKKKKKKKKKWOOOOOOWKKK...",
    "...WWWWWWWWWWWWWWWWWWWWWWWWWWWWWWWWWOOOOOOWWWW...",
    "...WBWOWBWOWBWOWBWOWBWOWBWOWBWOWBWOWOOOOOOWBWO..."
  ]
  readonly property int hutCols: hutArt[0].length
  readonly property int hutRows: hutArt.length
  // The door, in art pixels: columns 36 to 41, rows 6 to 17.
  readonly property rect hutDoor: Qt.rect(36, 6, 6, 12)

  // The FIELD BRIEFING sign, an arrow pointing back toward the hut.
  readonly property var signArt: {
    var rows = []
    var w = 40, h = 15
    for (var y = 0; y < h; y++) {
      var tip = Math.abs(y - (h - 1) / 2)
      var row = ""
      for (var x = 0; x < w; x++) {
        var inside = x >= Math.floor(tip * 0.6)
        var edge = y === 0 || y === h - 1 || x === w - 1 || x === Math.floor(tip * 0.6)
        row += !inside ? "." : (edge ? "K" : "W")
      }
      rows.push(row)
    }
    return rows
  }

  // ---------------------------------------------------------------- story

  readonly property string hq: {
    // Only what the pixel font can draw, cut after filtering so the FROM line
    // always fits the teletype's 40 columns.
    var name = String(host ? host.hostName : "").toUpperCase().replace(/[^A-Z0-9-]/g, "").substring(0, 16)
    return name || "OMARCHY"
  }

  readonly property var briefingText: [
    "TO END BRIEFING, PRESS ANY KEY.",
    "",
    "TOP SECRET CLASSIFIED MATERIALS",
    "MISSION CLASSIFICATION OM-24 TILING",
    "COVERT OPERATIONS DIVISION, H.Q.",
    "----------------------------------------",
    "TO:      CAPTAIN OMARCHY",
    "FROM:    COMMAND, " + root.hq + " H.Q.",
    "SUBJECT: ULTIMATUM, WORLD CONTROL",
    "",
    "AN ULTIMATUM HAS BEEN RECEIVED AT H.Q.: 200 GIGABYTES OF BLOATWARE MUST RUN ON EVERY DESKTOP WITHIN 24 HOURS, OR THE FREE WORLD WILL BE FORCED TO USE THE MOUSE.",
    "",
    "THE SOURCE OF THIS MESSAGE IS SOMEWHERE ON OR NEAR THE BLOAT ISLANDS, LAST KNOWN LOCATION OF THE EVIL AND INFAMOUS DR. TELEMETRY.",
    "",
    "DR. TELEMETRY HAS THE CAPABILITY AND THE RESOURCES TO BUILD A WORLD-SLOWING DEVICE. THE THREAT IS TO BE TAKEN MOST SERIOUSLY....",
    "",
    "YOUR MISSION: TRAVEL TO THE BLOAT ISLANDS AND LOCATE AND DISABLE THE DEVICE BEFORE IT CAN BE SWITCHED ON.",
    "",
    "THE LATEST TILING JET IS FUELED, ARMED, AND WAITING ON RUNWAY 019. FLY DIRECTLY INTO ENEMY TERRITORY. YOU WILL BE EJECTED OVER THE DROP ZONE.",
    "",
    "ONCE ON THE GROUND, YOU WILL BE STRICTLY ON YOUR OWN....",
    "",
    "GOOD LUCK, CAPTAIN. THE FREE WORLD IS COUNTING ON YOU!!"
  ]
  readonly property int briefCols: 40

  function wrap(paragraphs, cols) {
    var out = []
    for (var i = 0; i < paragraphs.length; i++) {
      var words = paragraphs[i].split(" ")
      var line = ""
      for (var w = 0; w < words.length; w++) {
        var next = line ? line + " " + words[w] : words[w]
        if (next.length > cols && line) { out.push(line); line = words[w] }
        else line = next
      }
      out.push(line)
    }
    return out
  }

  readonly property string arrived: "CAPTAIN OMARCHY HAS ARRIVED!"
  readonly property string waiting: "THE BASE COMMANDER IS WAITING..."

  // ---------------------------------------------------------------- state

  property string phase: ""
  property real phaseTime: 0
  property string builtFor: ""
  property real clock: 0
  property int spin: 0

  property real heliX: 0
  property real heliY: 0
  property bool heliShown: false
  property real doorOpen: 0
  property real departVX: 0
  property real departVY: 0

  // "door" in the doorway, "ground" on the field, "" out of sight.
  property string captainAt: ""
  property real captainX: 0
  property real captainY: 0
  property int captainFrame: 0
  property bool captainLeft: false
  property real runFrom: 0

  property real scroll: 0
  property bool hutDoorOpen: false
  property string status: ""

  property var stars: []

  property var briefLines: []
  property int briefLine: 0
  property real briefChars: 0
  property var briefView: []
  property real briefHold: 0

  // Layout, in screen pixels, worked out again when the size changes.
  readonly property real heliW: heliCols * px
  readonly property real heliH: heliRows * px
  readonly property real landX: Math.round(width * 0.42 - heliW / 2)
  readonly property real landY: groundY - heliH
  readonly property real hutW: hutCols * px
  readonly property real hutHome: Math.round(width * 0.06)
  // The hut waits out of sight to the left until the field scrolls.
  readonly property real hutStart: -hutW - 8 * px
  readonly property real signX: width - 44 * signPx

  readonly property real briefPixel: Math.max(1, Math.min(width * 0.84 / (briefCols * 4), height * 0.84 / (11 * 8)))
  readonly property int briefRows: Math.max(4, Math.floor(height * 0.84 / (8 * briefPixel)))

  function go(next) {
    root.phase = next
    root.phaseTime = 0
  }

  function scatterStars() {
    var list = []
    var n = root.preview ? 14 : 34
    for (var i = 0; i < n; i++)
      list.push({
        x: Math.floor(Math.random() * root.width / root.px) * root.px,
        y: Math.floor(Math.random() * root.groundY * 0.8 / root.px) * root.px,
        // An ink key for the odd colored star; the rest follow the scene.
        tint: Util.chance(6) ? (Util.chance(2) ? "V" : "B") : ""
      })
    root.stars = list
  }

  function startCycle() {
    root.heliShown = false
    root.captainAt = ""
    root.doorOpen = 0
    root.scroll = 0
    root.hutDoorOpen = false
    root.status = ""
    go(root.showTitle ? "title" : "approach")
  }

  function startBriefing() {
    root.briefLines = wrap(root.briefingText, root.briefCols)
    root.briefLine = 0
    root.briefChars = 0
    root.briefView = []
    root.briefHold = 0
    go("briefing")
  }

  function easeOut(t) { return 1 - (1 - t) * (1 - t) }
  function easeInOut(t) { return t * t * (3 - 2 * t) }

  function step(dt) {
    if (root.width <= 0 || root.height <= 0) return
    var size = root.width + "x" + root.height
    if (root.builtFor !== size) {
      // A new size moves everything, so the stars are scattered again and
      // the story starts over.
      root.builtFor = size
      scatterStars()
      startCycle()
    }
    root.clock += dt
    root.phaseTime += dt
    var t = root.phaseTime
    var s = Math.floor(root.clock * 15) % 4
    if (s !== root.spin) root.spin = s

    switch (root.phase) {
    case "title":
      if (t >= 4.5 || !root.showTitle) go("approach")
      break

    case "approach": {
      // In from high on the left, slowing over the field, then settling.
      var u = Math.min(1, t / 6.5)
      root.heliShown = true
      root.heliX = Math.round(Util.lerp(-root.heliW - 10 * root.px, root.landX, easeOut(Math.min(1, u / 0.8))))
      root.heliY = Math.round(Util.lerp(root.height * 0.12, root.landY, easeInOut(u)))
      if (u >= 1) {
        root.status = root.arrived
        go("landed")
      }
      break
    }

    case "landed":
      if (t >= 0.7) go("door")
      break

    case "door":
      root.doorOpen = Math.min(1, t / 0.5)
      if (t >= 0.6) {
        root.captainAt = "door"
        root.captainFrame = root.captainStand
        root.captainLeft = false
        go("doorway")
      }
      break

    case "doorway":
      if (t >= 0.8) {
        // Start the hop exactly where he stands in the doorway, so the
        // ground figure never shows a frame at last cycle's position.
        root.captainX = root.heliX + (root.doorAt.x - 1) * root.px
        root.captainY = root.heliY + (root.doorAt.y + 1) * root.px
        root.captainAt = "ground"
        go("hop")
      }
      break

    case "hop": {
      // Out of the doorway, over the sill and onto the grass in front of it.
      var h = Math.min(1, t / 0.45)
      root.captainX = Math.round(root.heliX + Util.lerp(root.doorAt.x - 1, root.doorAt.x - 2, h) * root.px)
      root.captainY = Math.round(Util.lerp(root.heliY + (root.doorAt.y + 1) * root.px, root.groundY - root.captainRows * root.px, h)
        - Math.sin(h * Math.PI) * 4 * root.px)
      if (h >= 1) go("wave")
      break
    }

    case "wave":
      root.captainFrame = Math.floor(t * 4) % 2 ? root.captainWave : root.captainStand
      root.doorOpen = Math.max(0, 1 - Math.max(0, t - 0.6) / 0.5)
      if (t >= 1.4) {
        root.departVX = 0
        root.departVY = 0
        go("depart")
      }
      break

    case "depart":
      // Up first, then away to the right, while the captain waves it off.
      root.captainFrame = t < 2.6 && Math.floor(t * 4) % 2 ? root.captainWave : root.captainStand
      root.departVY = Math.min(150 * root.unit, root.departVY + 160 * root.unit * dt)
      if (t > 0.6) root.departVX = Math.min(520 * root.unit, root.departVX + 300 * root.unit * dt)
      if (root.heliY > root.height * 0.2) root.heliY -= root.departVY * dt
      root.heliX += root.departVX * dt
      if (root.heliX > root.width) root.heliShown = false
      if (!root.heliShown && t >= 3) {
        root.status = root.waiting
        // Turning round mirrors the sprite about its 12 columns, which would
        // step him a column to the right; step him back.
        root.captainLeft = true
        root.captainX -= root.px
        root.runFrom = root.captainX
        go("run")
      }
      break

    case "run": {
      // The field scrolls right as the captain runs left, until the hut's
      // door is in front of him.
      var r = Math.min(1, t / 4.2)
      root.scroll = (root.hutHome - root.hutStart) * r
      // Mirrored, his middle is column 6 of 12; the door's is 39 of the hut.
      var target = root.hutHome + (root.hutDoor.x - 3) * root.px
      root.captainX = Math.round(Util.lerp(root.runFrom, target, r))
      // Two strides of four poses, at about the pace he covers ground.
      root.captainFrame = root.captainRun + Math.floor(t * 12) % 8
      if (r >= 1) {
        root.captainFrame = root.captainStand
        root.hutDoorOpen = true
        go("enter")
      }
      break
    }

    case "enter":
      if (t >= 0.4) root.captainAt = ""
      if (t >= 1.1) root.hutDoorOpen = false
      if (t >= 2.4) {
        if (root.showBriefing) startBriefing()
        else startCycle()
      }
      break

    case "briefing":
      if (!root.showBriefing) startCycle()
      else typeBriefing(dt)
      break

    default:
      startCycle()
    }
  }

  // The orders come in on a teletype, a line at a time, scrolling up.
  function typeBriefing(dt) {
    var lines = root.briefLines
    if (root.briefLine >= lines.length) {
      root.briefHold += dt
      if (root.briefHold >= 6) startCycle()
      return
    }
    var line = lines[root.briefLine]
    // A blank line is a pause, as long as typing twelve characters.
    var length = line.length || 12
    var before = Math.floor(root.briefChars)
    root.briefChars += dt * 32
    if (root.briefChars >= length) {
      root.briefChars = 0
      root.briefLine++
    } else if (Math.floor(root.briefChars) === before && root.briefView.length) {
      return
    }
    var done = lines.slice(0, root.briefLine)
    var view = done.slice(Math.max(0, done.length - root.briefRows + 1))
    if (root.briefLine < lines.length)
      view.push(lines[root.briefLine].substring(0, Math.floor(root.briefChars)))
    root.briefView = view
  }

  // ------------------------------------------------------------- drawing

  component Captain: Item {
    id: captain
    property int frame: 0
    property bool facingLeft: false
    width: root.captainCols * root.px
    height: root.captainRows * root.px
    Repeater {
      model: root.captainFrames.length
      PixelSprite {
        visible: captain.frame === index
        rows: root.captainFrames[index]
        colors: root.ink
        pixel: root.px
        mirror: captain.facingLeft
      }
    }
  }

  Rectangle {
    anchors.fill: parent
    color: root.scene.sky
  }

  // ------------------------------------------------------------ the field

  Item {
    id: field
    anchors.fill: parent
    visible: root.phase !== "title" && root.phase !== "briefing"

    Repeater {
      model: root.stars
      Rectangle {
        x: modelData.x
        y: modelData.y
        width: root.px
        height: root.px
        color: modelData.tint ? root.ink[modelData.tint] : root.scene.star
      }
    }

    // The ground, and the status line under it.
    Rectangle {
      y: root.groundY
      width: root.width
      height: 8 * root.px
      color: root.scene.ground
    }
    Rectangle {
      y: root.barY
      width: root.width
      height: 9 * root.px
      color: root.scene.bar
      PixelText {
        x: 3 * root.px
        anchors.verticalCenter: parent.verticalCenter
        text: root.status
        color: root.scene.barText
        pixel: root.px
      }
    }

    // The sign and the hut scroll with the field; the stars stay put.
    Item {
      x: root.scroll
      width: root.width
      height: root.height

      // The board on a post, its lettering in the sign's finer pixels.
      Item {
        x: root.signX
        y: root.groundY - 32 * root.signPx
        Rectangle {
          x: 29 * root.signPx
          y: root.signArt.length * root.signPx
          width: 2 * root.signPx
          height: (32 - root.signArt.length) * root.signPx
          color: root.ink.W
        }
        PixelSprite {
          rows: root.signArt
          colors: root.ink
          pixel: root.signPx
        }
        PixelText {
          x: 13 * root.signPx
          y: 2 * root.signPx
          text: "FIELD"
          color: root.ink.B
          pixel: root.signPx
        }
        PixelText {
          x: 6 * root.signPx
          y: 8 * root.signPx
          text: "BRIEFING"
          color: root.ink.O
          pixel: root.signPx
        }
      }

      Item {
        x: root.hutStart
        y: root.groundY - root.hutRows * root.px
        PixelSprite {
          rows: root.hutArt
          colors: root.ink
          pixel: root.px
        }
        Rectangle {
          visible: root.hutDoorOpen
          x: root.hutDoor.x * root.px
          y: root.hutDoor.y * root.px
          width: root.hutDoor.width * root.px
          height: root.hutDoor.height * root.px
          color: root.ink.K
        }
      }
    }

    Item {
      id: heli
      visible: root.heliShown
      x: root.heliX
      y: root.heliY

      PixelSprite {
        rows: root.heliArt
        colors: root.ink
        pixel: root.px
      }

      Repeater {
        model: root.tailRotorFrames.length
        PixelSprite {
          x: root.tailRotorAt.x * root.px
          y: root.tailRotorAt.y * root.px
          visible: root.spin === index
          rows: root.tailRotorFrames[index]
          colors: root.ink
          pixel: root.px
        }
      }

      // The main rotor: a mast, and a blade whose span changes as it turns.
      Rectangle {
        x: Math.floor(root.hubX) * root.px
        y: -root.px
        width: root.px
        height: root.px
        color: root.ink.W
      }
      Rectangle {
        readonly property int span: root.rotorSpans[root.spin]
        x: Math.round(root.hubX - span / 2) * root.px
        y: -2 * root.px
        width: span * root.px
        height: root.px
        color: root.ink.W
        Rectangle { width: 3 * root.px; height: root.px; color: root.ink.O }
        Rectangle { anchors.right: parent.right; width: 3 * root.px; height: root.px; color: root.ink.O }
      }

      // The captain in the doorway, cut off at the knees by the frame.
      Item {
        x: root.doorAt.x * root.px
        y: root.doorAt.y * root.px
        width: 8 * root.px
        height: 9 * root.px
        clip: true
        PixelSprite {
          x: -root.px
          y: root.px
          visible: root.captainAt === "door"
          rows: root.captainFrames[root.captainStand]
          colors: root.ink
          pixel: root.px
        }
      }

      // The sliding door, back toward the tail as it opens.
      PixelSprite {
        x: (root.doorAt.x - Math.round(7 * root.doorOpen)) * root.px
        y: root.doorAt.y * root.px
        rows: root.doorArt
        colors: root.ink
        pixel: root.px
      }
    }

    // The captain on the field. He is taller than the doorway, so as he
    // hops out his legs would reach below the grass line; the grass hides
    // them until he has landed.
    Item {
      width: root.width
      height: root.groundY
      clip: true
      Captain {
        visible: root.captainAt === "ground"
        x: root.captainX
        y: root.captainY
        frame: root.captainFrame
        facingLeft: root.captainLeft
      }
    }
  }

  // ------------------------------------------------------------ title card

  Item {
    id: title
    anchors.fill: parent
    visible: root.phase === "title"

    Item {
      id: card
      readonly property real p: Math.max(1, Math.round(Math.min(root.width * 0.7, root.height * 1.0) / 200))
      width: 200 * p
      height: 136 * p
      anchors.centerIn: parent

      Rectangle {
        anchors.fill: parent
        anchors.topMargin: 6 * card.p
        color: "transparent"
        border.color: root.scene.frameOuter
        border.width: card.p
      }
      Rectangle {
        anchors.fill: parent
        anchors.margins: 3 * card.p
        anchors.topMargin: 10 * card.p
        anchors.bottomMargin: 8 * card.p
        color: "transparent"
        border.color: root.scene.frameInner
        border.width: card.p
      }

      // The header sits on the top border, with sky behind it.
      Rectangle {
        anchors.horizontalCenter: parent.horizontalCenter
        width: headline.width + 8 * card.p
        height: headline.height
        color: root.scene.sky
        PixelText {
          id: headline
          anchors.centerIn: parent
          text: "AFTER DARK"
          color: root.scene.title
          pixel: 2.4 * card.p
        }
      }
      Rectangle {
        anchors.horizontalCenter: parent.horizontalCenter
        y: 13 * card.p
        width: presents.width + 6 * card.p
        height: presents.height + 2 * card.p
        color: root.scene.frameInner
        PixelText {
          id: presents
          anchors.centerIn: parent
          text: "PRESENTS"
          color: root.scene.sky
          pixel: card.p
        }
      }

      // The big words, each with a blue fringe to its right like an old
      // color monitor's.
      Repeater {
        model: [{ text: "CAPTAIN", y: 26 }, { text: "OMARCHY", y: 60 }]
        Item {
          anchors.horizontalCenter: parent.horizontalCenter
          y: modelData.y * card.p
          width: word.width
          height: word.height
          PixelText {
            x: card.p
            text: modelData.text
            color: root.scene.frameInner
            pixel: 6 * card.p
          }
          PixelText {
            id: word
            text: modelData.text
            color: root.scene.title
            pixel: 6 * card.p
          }
        }
      }

      PixelText {
        anchors.horizontalCenter: parent.horizontalCenter
        y: 98 * card.p
        text: "AND THE ISLANDS OF BLOAT"
        color: root.scene.subtitle
        pixel: 1.6 * card.p
      }

      // The year on a plaque set into the bottom border.
      Rectangle {
        anchors.horizontalCenter: parent.horizontalCenter
        y: parent.height - 12 * card.p
        width: year.width + 10 * card.p
        height: year.height + 4 * card.p
        color: root.scene.sky
        border.color: root.scene.frameOuter
        border.width: card.p
        PixelText {
          id: year
          anchors.centerIn: parent
          text: "MMXXVI"
          color: root.scene.title
          pixel: 1.4 * card.p
        }
      }
    }
  }

  // -------------------------------------------------------------- briefing

  Item {
    id: briefing
    anchors.fill: parent
    visible: root.phase === "briefing"

    Item {
      id: page
      width: root.briefCols * 4 * root.briefPixel
      height: root.briefRows * 8 * root.briefPixel
      anchors.centerIn: parent

      Repeater {
        model: root.briefRows
        PixelText {
          y: index * 8 * root.briefPixel
          text: root.briefView[index] || ""
          color: root.scene.text
          pixel: root.briefPixel
        }
      }

      // The cursor, after the last character on the page.
      Rectangle {
        readonly property int row: Math.max(0, root.briefView.length - 1)
        readonly property string line: root.briefView[row] || ""
        visible: Math.floor(root.clock * 3) % 2 === 0
        x: (Font.measure(line) + (line.length ? 1 : 0)) * root.briefPixel
        y: row * 8 * root.briefPixel
        width: 3 * root.briefPixel
        height: 5 * root.briefPixel
        color: root.scene.text
      }
    }
  }

  FrameAnimation {
    running: root.running && root.visible
    onTriggered: root.step(Math.min(frameTime, 0.05))
  }
}
