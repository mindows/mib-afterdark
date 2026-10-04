import QtQuick
import QtQuick.Shapes
import "../../lib"
import "../../lib/Util.js" as Util

// Asteroids: a vector ship flying and fighting on its own. It aims ahead of
// the nearest rock, dodges anything on a collision course, and jumps to
// hyperspace when dodging will not do.
Item {
  id: root

  property var host: null
  property bool running: true

  readonly property bool omarchyRocks: (host ? host.option("rocks", "omarchy") : "omarchy") === "omarchy"
  readonly property string colorOption: host ? host.option("color", "vector") : "vector"
  readonly property color ink: colorOption === "amber" ? "#ffb000" : (colorOption === "theme" && host ? host.accent : "#e6f0ff")
  readonly property real unit: Math.max(0.5, Math.min(width, height) / 1080)

  readonly property var bigLabels: ["node_modules", "texlive-full", "electron", "systemd", "chromium", "linux-firmware", "llvm", "rustc"]
  readonly property var midLabels: ["npm", "pip", "cargo", "yay", "go", "gcc", "qt6", "mesa", "hypr", "nvim"]
  readonly property var smallLabels: ["$", ">_", "~", "#", "&&", "|", "*", "!!", "root", "rm"]

  property var ship: ({ x: 0, y: 0, vx: 0, vy: 0, a: -Math.PI / 2, alive: true, invuln: 3, cooldown: 0, respawn: 0, thrust: false })
  property var rocks: []
  property var bullets: []
  property var particles: []
  property var ufo: null
  property real ufoClock: 25
  property int score: 0
  property int hiScore: 0
  property int lives: 3
  property int wave: 0
  property string banner: ""
  property real bannerTime: 0
  property bool started: false

  function wrapDelta(d, span) {
    return ((d + span * 1.5) % span) - span / 2
  }

  function makeRock(size, x, y) {
    var r = [0, 22, 44, 80][size] * root.unit
    var angle = Math.random() * Math.PI * 2
    var speed = Util.rand(30, 75) * root.unit * (4 - size) * 0.6 * (1 + root.wave * 0.05)
    var shape = []
    for (var i = 0; i < 11; i++) shape.push(Util.rand(0.72, 1.08))
    var labels = size === 3 ? root.bigLabels : (size === 2 ? root.midLabels : root.smallLabels)
    return {
      x: x, y: y, vx: Math.cos(angle) * speed, vy: Math.sin(angle) * speed,
      r: r, size: size, rot: Math.random() * 6.28, spin: Util.rand(-0.8, 0.8),
      shape: shape, label: Util.pick(labels)
    }
  }

  function newWave() {
    root.wave++
    var n = Math.min(11, 3 + root.wave)
    var list = []
    for (var i = 0; i < n; i++) {
      // Rocks start at the edges, never on top of the ship.
      var edge = Math.random() < 0.5
      var x = edge ? (Math.random() < 0.5 ? 0 : root.width) : Math.random() * root.width
      var y = edge ? Math.random() * root.height : (Math.random() < 0.5 ? 0 : root.height)
      list.push(makeRock(3, x, y))
    }
    root.rocks = list
    showBanner("WAVE " + root.wave, 2)
  }

  function showBanner(text, seconds) {
    root.banner = text
    root.bannerTime = seconds
  }

  // A run dismissed before GAME OVER keeps its high score too. SaverHost
  // unloads a module before switching its host to the next one.
  Component.onDestruction: if (root.score > root.hiScore && root.host) root.host.set("hiscore", root.score)

  function newGame() {
    if (root.score > root.hiScore) {
      root.hiScore = root.score
      if (root.host) root.host.set("hiscore", root.hiScore)
    }
    root.score = 0
    root.lives = 3
    root.wave = 0
    resetShip()
    newWave()
  }

  function resetShip() {
    root.ship = { x: root.width / 2, y: root.height / 2, vx: 0, vy: 0, a: -Math.PI / 2, alive: true, invuln: 3, cooldown: 0, respawn: 0, thrust: false }
  }

  function explode(x, y, count, speed) {
    for (var i = 0; i < count && root.particles.length < 400; i++) {
      var a = Math.random() * Math.PI * 2
      var v = Math.random() * speed * root.unit
      root.particles.push({ x: x, y: y, vx: Math.cos(a) * v, vy: Math.sin(a) * v, life: Util.rand(0.5, 1.2) })
    }
  }

  function fire(from, x, y, angle, speed) {
    root.bullets.push({ from: from, x: x, y: y, vx: Math.cos(angle) * speed, vy: Math.sin(angle) * speed, life: 1.1 })
  }

  function angleDiff(a, b) {
    var d = (a - b) % (Math.PI * 2)
    if (d > Math.PI) d -= Math.PI * 2
    if (d < -Math.PI) d += Math.PI * 2
    return d
  }

  // The pilot.
  function think(dt) {
    var s = root.ship
    var shipR = 16 * root.unit
    var bulletSpeed = 620 * root.unit
    var desired = s.a
    var thrust = false

    // Anything on a collision course within the next second and a bit?
    var threat = null
    var threatT = 1.3
    for (var i = 0; i < root.rocks.length; i++) {
      var r = root.rocks[i]
      var dx = wrapDelta(r.x - s.x, root.width)
      var dy = wrapDelta(r.y - s.y, root.height)
      var rvx = r.vx - s.vx, rvy = r.vy - s.vy
      var vv = rvx * rvx + rvy * rvy
      var t = vv > 0 ? Math.max(0, -(dx * rvx + dy * rvy) / vv) : 0
      var cx = dx + rvx * t, cy = dy + rvy * t
      if (Math.sqrt(cx * cx + cy * cy) < r.r + shipR * 2.5 && t < threatT) { threat = { r: r, dx: dx, dy: dy, t: t }; threatT = t }
    }

    var target = null
    var best = 1e9
    for (var j = 0; j < root.rocks.length; j++) {
      var rock = root.rocks[j]
      var ddx = wrapDelta(rock.x - s.x, root.width)
      var ddy = wrapDelta(rock.y - s.y, root.height)
      var d = Math.sqrt(ddx * ddx + ddy * ddy)
      if (d < best) { best = d; target = { dx: ddx, dy: ddy, r: rock, d: d } }
    }
    if (root.ufo) {
      var ux = wrapDelta(root.ufo.x - s.x, root.width), uy = wrapDelta(root.ufo.y - s.y, root.height)
      var ud = Math.sqrt(ux * ux + uy * uy)
      if (ud < best * 1.4) target = { dx: ux, dy: uy, r: root.ufo, d: ud }
    }

    if (threat && threat.t < 0.25 && Util.chance(3)) {
      // Too close to dodge: hyperspace.
      s.x = Math.random() * root.width
      s.y = Math.random() * root.height
      s.vx = 0; s.vy = 0
      s.invuln = 0.6
      explode(s.x, s.y, 12, 90)
      return
    }
    if (threat) {
      // Turn side-on to the rock's approach and burn.
      var away = Math.atan2(-threat.dy, -threat.dx)
      desired = away + (angleDiff(Math.atan2(threat.r.vy, threat.r.vx), away) > 0 ? -0.6 : 0.6)
      thrust = Math.abs(angleDiff(desired, s.a)) < 0.9
    } else if (target) {
      var lead = target.d / bulletSpeed
      var ax = target.dx + (target.r.vx - s.vx) * lead
      var ay = target.dy + (target.r.vy - s.vy) * lead
      desired = Math.atan2(ay, ax)
      thrust = target.d > Math.min(root.width, root.height) * 0.42 && Math.abs(angleDiff(desired, s.a)) < 0.4
    }

    var turn = angleDiff(desired, s.a)
    var maxTurn = 4.8 * dt
    s.a += Math.max(-maxTurn, Math.min(maxTurn, turn))
    s.thrust = thrust
    if (thrust) {
      s.vx += Math.cos(s.a) * 340 * root.unit * dt
      s.vy += Math.sin(s.a) * 340 * root.unit * dt
    }
    var ownBullets = 0
    for (var b = 0; b < root.bullets.length; b++) if (root.bullets[b].from === "ship") ownBullets++
    s.cooldown -= dt
    if (target && Math.abs(turn) < 0.12 && s.cooldown <= 0 && ownBullets < 6 && target.d < Math.max(root.width, root.height) * 0.6) {
      fire("ship", s.x + Math.cos(s.a) * shipR, s.y + Math.sin(s.a) * shipR, s.a, bulletSpeed)
      s.cooldown = 0.16
    }
  }

  function wrap(o) {
    if (o.x < 0) o.x += root.width
    if (o.x >= root.width) o.x -= root.width
    if (o.y < 0) o.y += root.height
    if (o.y >= root.height) o.y -= root.height
  }

  function hit(a, b, dist) {
    var dx = wrapDelta(a.x - b.x, root.width)
    var dy = wrapDelta(a.y - b.y, root.height)
    return dx * dx + dy * dy < dist * dist
  }

  function splitRock(index, byShip) {
    var r = root.rocks[index]
    root.rocks.splice(index, 1)
    explode(r.x, r.y, 10 + r.size * 5, 160)
    if (byShip) root.score += [0, 100, 50, 20][r.size]
    if (r.size > 1) {
      root.rocks.push(makeRock(r.size - 1, r.x, r.y))
      root.rocks.push(makeRock(r.size - 1, r.x, r.y))
    }
  }

  function step(dt) {
    if (root.width <= 0) return
    if (!root.started) {
      root.started = true
      root.hiScore = root.host ? Number(root.host.get("hiscore", 0)) || 0 : 0
      newGame()
    }
    if (root.bannerTime > 0) root.bannerTime -= dt
    var s = root.ship

    if (s.alive) {
      think(dt)
      s.invuln = Math.max(0, s.invuln - dt)
      s.vx *= Math.pow(0.55, dt)
      s.vy *= Math.pow(0.55, dt)
      s.x += s.vx * dt
      s.y += s.vy * dt
      wrap(s)
    } else {
      s.respawn -= dt
      if (s.respawn <= 0) {
        if (root.lives <= 0) {
          // After newGame(), whose first wave would replace it.
          newGame()
          showBanner("GAME OVER", 3)
        } else {
          resetShip()
        }
      }
    }

    for (var i = 0; i < root.rocks.length; i++) {
      var r = root.rocks[i]
      r.x += r.vx * dt
      r.y += r.vy * dt
      r.rot += r.spin * dt
      wrap(r)
      if (s.alive && s.invuln <= 0 && hit(r, s, r.r * 0.85 + 12 * root.unit)) {
        s.alive = false
        s.respawn = 2.2
        root.lives--
        explode(s.x, s.y, 40, 220)
      }
    }

    var keptBullets = []
    for (var b = 0; b < root.bullets.length; b++) {
      var bullet = root.bullets[b]
      bullet.life -= dt
      bullet.x += bullet.vx * dt
      bullet.y += bullet.vy * dt
      wrap(bullet)
      var spent = bullet.life <= 0
      for (var k = 0; !spent && k < root.rocks.length; k++) {
        if (hit(bullet, root.rocks[k], root.rocks[k].r)) {
          splitRock(k, bullet.from === "ship")
          spent = true
        }
      }
      if (!spent && root.ufo && bullet.from === "ship" && hit(bullet, root.ufo, root.ufo.r)) {
        root.score += root.ufo.kind === "quattro" ? 5000 : 1000
        if (root.ufo.kind === "quattro") showBanner("QUATTRO BONUS 5000", 2.5)
        explode(root.ufo.x, root.ufo.y, 50, 240)
        root.ufo = null
        spent = true
      }
      if (!spent && bullet.from === "ufo" && s.alive && s.invuln <= 0 && hit(bullet, s, 10 * root.unit)) {
        s.alive = false
        s.respawn = 2.2
        root.lives--
        explode(s.x, s.y, 40, 220)
        spent = true
      }
      if (!spent) keptBullets.push(bullet)
    }
    root.bullets = keptBullets

    // Saucers now and then; one in eight is a quattro, worth a lot more.
    root.ufoClock -= dt
    if (!root.ufo && root.ufoClock <= 0) {
      var fromLeft = Math.random() < 0.5
      var quattro = root.host ? root.host.rare(8) : Util.chance(8)
      root.ufo = {
        kind: quattro ? "quattro" : "saucer",
        x: fromLeft ? 0 : root.width - 1, y: Util.rand(0.15, 0.85) * root.height,
        vx: (fromLeft ? 1 : -1) * 110 * root.unit, vy: 0, r: 22 * root.unit, fire: 1.2, travelled: 0
      }
      root.ufoClock = Util.rand(20, 40)
    }
    if (root.ufo) {
      var u = root.ufo
      u.x += u.vx * dt
      u.travelled += Math.abs(u.vx * dt)
      u.y += Math.sin(u.travelled / (80 * root.unit)) * 40 * root.unit * dt
      wrap(u)
      u.fire -= dt
      if (u.fire <= 0 && s.alive) {
        var aim = Math.atan2(wrapDelta(s.y - u.y, root.height), wrapDelta(s.x - u.x, root.width)) + Util.rand(-0.35, 0.35)
        fire("ufo", u.x, u.y, aim, 380 * root.unit)
        u.fire = Util.rand(0.9, 1.8)
      }
      if (u.travelled > root.width * 1.05) root.ufo = null
    }

    var keptParticles = []
    for (var p = 0; p < root.particles.length; p++) {
      var part = root.particles[p]
      part.life -= dt
      if (part.life <= 0) continue
      part.x += part.vx * dt
      part.y += part.vy * dt
      keptParticles.push(part)
    }
    root.particles = keptParticles

    if (root.rocks.length === 0) newWave()
    sync()
  }

  // ------------------------------------------------------------- drawing

  // Everything on screen is a vector shape moved by the GPU. A rock's
  // outline is built once, when it takes a slot; after that only its
  // position and rotation change.

  readonly property int maxRocks: 44
  readonly property int maxBullets: 24
  readonly property int maxParticles: 220
  readonly property var shipShape: [[1.3, 0], [-0.9, -0.8], [-0.55, 0], [-0.9, 0.8], [1.3, 0]]
  readonly property var flameShape: [[-0.6, -0.4], [-1.5, 0], [-0.6, 0.4]]
  readonly property var saucerShape: [[-1, 0], [-0.45, -0.35], [0.45, -0.35], [1, 0], [-1, 0], [-0.45, 0.3], [0.45, 0.3], [1, 0], [0.45, -0.35], [0.25, -0.7], [-0.25, -0.7], [-0.45, -0.35]]
  // The quattro in outline: bonnet, glasshouse, boot, and two arches.
  readonly property var quattroShape: [[-1, 0.2], [-1, -0.08], [-0.72, -0.12], [-0.42, -0.5], [0.18, -0.5], [0.42, -0.12], [1, -0.06], [1, 0.2], [0.78, 0.2], [0.72, 0.05], [0.4, 0.05], [0.34, 0.2], [-0.38, 0.2], [-0.44, 0.05], [-0.76, 0.05], [-0.82, 0.2], [-1, 0.2]]

  function points(list, scale) {
    var out = []
    for (var i = 0; i < list.length; i++) out.push(Qt.point(list[i][0] * scale, list[i][1] * scale))
    return out
  }

  function rockPoints(rock) {
    var out = []
    var n = rock.shape.length
    for (var k = 0; k <= n; k++) {
      var a = (k % n) / n * Math.PI * 2
      var rr = rock.r * rock.shape[k % n]
      out.push(Qt.point(Math.cos(a) * rr, Math.sin(a) * rr))
    }
    return out
  }

  property int rockSerial: 0

  function sync() {
    // Give new rocks a free slot; a slot keeps its rock until the rock goes.
    var used = {}
    for (var i = 0; i < root.rocks.length; i++) if (root.rocks[i].slot !== undefined) used[root.rocks[i].slot] = true
    var nextFree = 0
    for (var j = 0; j < root.rocks.length; j++) {
      var rock = root.rocks[j]
      if (rock.slot !== undefined) continue
      while (nextFree < root.maxRocks && used[nextFree]) nextFree++
      if (nextFree >= root.maxRocks) break
      rock.slot = nextFree
      rock.serial = ++root.rockSerial
      used[nextFree] = true
    }
    var bySlot = {}
    for (var r = 0; r < root.rocks.length; r++) if (root.rocks[r].slot !== undefined) bySlot[root.rocks[r].slot] = root.rocks[r]
    for (var slot = 0; slot < root.maxRocks; slot++) {
      var item = rockRepeater.itemAt(slot)
      if (!item) continue
      var rk = bySlot[slot]
      if (!rk) { item.visible = false; continue }
      if (item.serial !== rk.serial) {
        item.serial = rk.serial
        item.outline = rockPoints(rk)
        item.label = rk.label
        item.labelSize = Math.round([0, 13, 16, 19][rk.size] * root.unit)
      }
      item.x = rk.x
      item.y = rk.y
      item.angle = rk.rot * 180 / Math.PI
      item.visible = true
    }

    var s = root.ship
    shipItem.visible = s.alive && (s.invuln <= 0 || Math.floor(s.invuln * 8) % 2 === 0)
    shipItem.x = s.x
    shipItem.y = s.y
    shipItem.rotation = s.a * 180 / Math.PI
    flame.visible = s.thrust && Math.random() < 0.7

    ufoItem.visible = !!root.ufo
    if (root.ufo) {
      ufoItem.x = root.ufo.x
      ufoItem.y = root.ufo.y
      ufoItem.quattro = root.ufo.kind === "quattro"
      ufoItem.flip = root.ufo.vx < 0
    }

    for (var b = 0; b < root.maxBullets; b++) {
      var dot = bulletRepeater.itemAt(b)
      if (!dot) continue
      var bullet = root.bullets[b]
      dot.visible = !!bullet
      if (bullet) { dot.x = bullet.x - dot.width / 2; dot.y = bullet.y - dot.height / 2 }
    }
    for (var p = 0; p < root.maxParticles; p++) {
      var spark = particleRepeater.itemAt(p)
      if (!spark) continue
      var part = root.particles[p]
      if (!part) { if (spark.visible) spark.visible = false; continue }
      spark.x = part.x
      spark.y = part.y
      spark.opacity = Math.min(1, part.life)
      spark.visible = true
    }
  }

  // A vector outline: a wide faint stroke under a thin bright one, for the
  // glow of a vector monitor.
  component Vector: Shape {
    id: vector
    property var outline: []
    property real glow: 8 * root.unit
    property real line: Math.max(1.5, 2.2 * root.unit)
    preferredRendererType: Shape.CurveRenderer
    ShapePath {
      strokeColor: Qt.rgba(root.ink.r, root.ink.g, root.ink.b, 0.18)
      strokeWidth: vector.glow
      fillColor: "transparent"
      joinStyle: ShapePath.RoundJoin
      capStyle: ShapePath.RoundCap
      PathPolyline { path: vector.outline }
    }
    ShapePath {
      strokeColor: root.ink
      strokeWidth: vector.line
      fillColor: "transparent"
      joinStyle: ShapePath.RoundJoin
      capStyle: ShapePath.RoundCap
      PathPolyline { path: vector.outline }
    }
  }

  Rectangle { anchors.fill: parent; color: "black" }

  Repeater {
    id: particleRepeater
    model: root.maxParticles
    Rectangle { visible: false; width: 2 * root.unit; height: width; color: root.ink }
  }

  Repeater {
    id: rockRepeater
    model: root.maxRocks
    Item {
      id: rockItem
      property int serial: -1
      property var outline: []
      property real angle: 0
      property string label: ""
      property int labelSize: 12
      visible: false
      Vector {
        outline: rockItem.outline
        rotation: rockItem.angle
        transformOrigin: Item.TopLeft
      }
      Text {
        visible: root.omarchyRocks
        anchors.centerIn: parent
        textFormat: Text.PlainText
        text: rockItem.label
        color: root.ink
        font.family: "monospace"
        font.bold: true
        font.pixelSize: rockItem.labelSize
      }
    }
  }

  Item {
    id: shipItem
    visible: false
    Vector { outline: root.points(root.shipShape, 15 * root.unit) }
    Vector { id: flame; visible: false; outline: root.points(root.flameShape, 15 * root.unit) }
  }

  Item {
    id: ufoItem
    property bool quattro: false
    property bool flip: false
    visible: false
    Vector { visible: !ufoItem.quattro; outline: root.points(root.saucerShape, 22 * root.unit) }
    Vector {
      visible: ufoItem.quattro
      outline: root.points(root.quattroShape, 31 * root.unit)
      transform: Scale { xScale: ufoItem.flip ? -1 : 1 }
    }
  }

  Repeater {
    id: bulletRepeater
    model: root.maxBullets
    Rectangle { visible: false; width: 4 * root.unit; height: width; radius: width / 2; color: root.ink }
  }

  // Spare lives, under the score.
  Row {
    x: 32 * root.unit
    y: 96 * root.unit
    spacing: 26 * root.unit
    Repeater {
      model: Math.max(0, root.lives)
      Item {
        width: 1
        height: 1
        Vector { rotation: -90; transformOrigin: Item.TopLeft; outline: root.points(root.shipShape, 9 * root.unit) }
      }
    }
  }

  PixelText {
    x: 28 * root.unit
    y: 28 * root.unit
    text: Util.pad(root.score, 6, "0")
    color: root.ink
    pixel: 7 * root.unit
  }

  PixelText {
    anchors.horizontalCenter: parent.horizontalCenter
    y: 28 * root.unit
    text: "HI " + Util.pad(Math.max(root.hiScore, root.score), 6, "0")
    color: root.ink
    opacity: 0.6
    pixel: 4 * root.unit
  }

  PixelText {
    anchors.centerIn: parent
    visible: root.bannerTime > 0
    opacity: Math.min(1, root.bannerTime * 2)
    text: root.banner
    color: root.ink
    pixel: 8 * root.unit
  }

  FrameAnimation {
    running: root.running && root.visible
    onTriggered: root.step(Math.min(frameTime, 0.05))
  }
}
