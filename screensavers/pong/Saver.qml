import QtQuick
import "../../lib"
import "../../lib/Sprites.js" as Sprites
import "../../lib/Util.js" as Util

// Pong Forever: two autonomous players, QUATTRO on the left and TUX on the
// right. Every point also lands in a lifetime tally kept in the state file,
// so the match picks up where it left off, on every screen, for months.
Item {
  id: root

  property var host: null
  property bool running: true

  readonly property string variantOption: host ? host.option("variant", "random") : "random"
  readonly property bool themed: host ? host.option("color", "phosphor") === "theme" : false
  readonly property color ink: themed && host ? host.foreground : "#f4f4ec"
  readonly property color net: Qt.rgba(ink.r, ink.g, ink.b, 0.35)

  readonly property var variants: ["classic", "impossible", "four-paddle", "multiball", "tiny-paddle", "quattro-vs-tux", "ludicrous"]
  property string variant: "classic"

  // Layout unit: everything scales with the smaller screen side.
  readonly property real u: Math.max(2, Math.min(width, height) / 90)
  readonly property real ballSize: u * 1.6
  readonly property real paddleThickness: u * 1.4
  readonly property real paddleLength: (variant === "tiny-paddle" ? 3.5 : (variant === "quattro-vs-tux" ? 13 : 12)) * u
  readonly property bool fourPaddle: variant === "four-paddle"

  property int scoreLeft: 0
  property int scoreRight: 0
  property int lifetimeLeft: 0
  property int lifetimeRight: 0
  property int rally: 0
  property string banner: ""
  property real bannerTime: 0
  property real chaosTime: 0

  readonly property int maxBalls: 24
  property var balls: []
  property var paddles: []
  property real serveDelay: 0.6

  function baseSpeed() {
    var s = root.height * 0.55
    if (root.variant === "ludicrous") s *= 2.6
    if (root.variant === "impossible") s *= 1.2
    return s
  }

  function pickVariant() {
    if (root.variantOption !== "random" && root.variants.indexOf(root.variantOption) !== -1)
      return root.variantOption
    return Util.pick(root.variants)
  }

  function refreshLifetime() {
    if (!root.host) return
    root.lifetimeLeft = Number(root.host.get("quattro", 0)) || 0
    root.lifetimeRight = Number(root.host.get("tux", 0)) || 0
  }

  function award(side) {
    if (side === "left") root.scoreLeft++
    else root.scoreRight++
    // Re-read before adding: another screen may be playing the same match.
    if (root.host) {
      var key = side === "left" ? "quattro" : "tux"
      root.host.set(key, (Number(root.host.get(key, 0)) || 0) + 1)
    }
    refreshLifetime()
    if (!root.host || root.host.preview) {
      if (side === "left") root.lifetimeLeft++
      else root.lifetimeRight++
    }
    root.rally = 0
    if (root.scoreLeft >= 11 || root.scoreRight >= 11) {
      showBanner(root.scoreLeft > root.scoreRight ? "QUATTRO WINS" : "TUX WINS", 2.5)
      root.serveDelay = 2.6
      newGame()
    }
  }

  function showBanner(text, seconds) {
    root.banner = text
    root.bannerTime = seconds
  }

  function newGame() {
    root.scoreLeft = 0
    root.scoreRight = 0
    root.variant = pickVariant()
    root.balls = []
    setupPaddles()
    if (root.bannerTime <= 0) showBanner(root.variant.replace(/-/g, " ").toUpperCase(), 2)
  }

  function setupPaddles() {
    var list = [
      { side: "left", axis: "y", pos: root.height / 2, target: root.height / 2, err: 0, tracking: -1 },
      { side: "right", axis: "y", pos: root.height / 2, target: root.height / 2, err: 0, tracking: -1 }
    ]
    if (root.fourPaddle) {
      list.push({ side: "top", axis: "x", pos: root.width / 2, target: root.width / 2, err: 0, tracking: -1 })
      list.push({ side: "bottom", axis: "x", pos: root.width / 2, target: root.width / 2, err: 0, tracking: -1 })
    }
    root.paddles = list
  }

  function serve(towardLeft) {
    if (root.balls.length >= root.maxBalls) return
    var angle = Util.rand(-0.45, 0.45)
    if (root.fourPaddle) angle = Util.rand(-0.9, 0.9)
    var speed = baseSpeed()
    var dir = towardLeft === undefined ? (Math.random() < 0.5 ? -1 : 1) : (towardLeft ? -1 : 1)
    root.balls.push({
      x: root.width / 2, y: root.height / 2 + Util.rand(-0.2, 0.2) * root.height,
      vx: Math.cos(angle) * speed * dir, vy: Math.sin(angle) * speed,
      id: Math.random()
    })
  }

  function wantedBalls() {
    if (root.chaosTime > 0) return 20
    if (root.variant === "multiball") return 4
    return 1
  }

  // Where a ball will cross `line` along x, following bounces off the top
  // and bottom walls (four-paddle has no walls, so no bounces).
  function interceptY(ball, lineX) {
    if (ball.vx === 0) return ball.y
    var t = (lineX - ball.x) / ball.vx
    if (t < 0) return root.height / 2
    var y = ball.y + ball.vy * t
    if (root.fourPaddle) return y
    var h = root.height - root.ballSize
    var m = ((y % (2 * h)) + 2 * h) % (2 * h)
    return m > h ? 2 * h - m : m
  }

  function interceptX(ball, lineY) {
    if (ball.vy === 0) return ball.x
    var t = (lineY - ball.y) / ball.vy
    return t < 0 ? root.width / 2 : ball.x + ball.vx * t
  }

  // How deep a paddle is, from the screen edge margin to the face the ball
  // bounces off. Quattro vs Tux plays with a car on its tail and a fat
  // penguin, both deeper than a bar.
  function paddleDepth(p) {
    if (root.variant === "quattro-vs-tux") {
      // The car is drawn at three-quarters, so its box has empty corners;
      // the ball meets the car, not the box.
      if (p.side === "left") return carPaddle.height * 0.85
      if (p.side === "right") return tuxPaddle.width
    }
    return root.paddleThickness
  }

  function paddleLine(p) {
    var m = root.u * 3
    if (p.side === "left") return m + paddleDepth(p)
    if (p.side === "right") return root.width - m - paddleDepth(p)
    if (p.side === "top") return m + root.paddleThickness
    return root.height - m - root.paddleThickness
  }

  function incoming(p, b) {
    if (p.side === "left") return b.vx < 0
    if (p.side === "right") return b.vx > 0
    if (p.side === "top") return b.vy < 0
    return b.vy > 0
  }

  function steerPaddle(p, dt) {
    var best = null
    var bestT = 1e9
    var line = paddleLine(p)
    for (var i = 0; i < root.balls.length; i++) {
      var b = root.balls[i]
      if (!incoming(p, b)) continue
      var t = p.axis === "y" ? Math.abs((line - b.x) / (b.vx || 1)) : Math.abs((line - b.y) / (b.vy || 1))
      if (t < bestT) { bestT = t; best = b }
    }
    var impossible = root.variant === "impossible"
    if (best) {
      // A fresh approach rolls a fresh aiming error: the source of every miss.
      if (p.tracking !== best.id) {
        p.tracking = best.id
        var spread = impossible ? 0 : root.paddleLength * (root.variant === "tiny-paddle" ? 1.2 : 0.62)
        p.err = Util.rand(-spread, spread)
      }
      var aim = p.axis === "y" ? interceptY(best, line) + root.ballSize / 2 : interceptX(best, line) + root.ballSize / 2
      p.target = aim + p.err
    } else {
      p.tracking = -1
      p.target = (p.axis === "y" ? root.height : root.width) / 2
    }
    var maxSpeed = (impossible ? 12 : (root.variant === "ludicrous" ? 2.4 : 0.95)) * root.height
    var delta = p.target - p.pos
    var step = Math.max(-maxSpeed * dt, Math.min(maxSpeed * dt, delta))
    var span = p.axis === "y" ? root.height : root.width
    var half = root.paddleLength / 2
    p.pos = Util.clamp(p.pos + step, half, span - half)
  }

  function collide(b, p) {
    var line = paddleLine(p)
    var half = root.paddleLength / 2
    var s = root.ballSize
    if (p.axis === "y") {
      var hitLeft = p.side === "left" && b.vx < 0 && b.x <= line && b.x >= line - root.paddleThickness - s
      var hitRight = p.side === "right" && b.vx > 0 && b.x + s >= line && b.x + s <= line + root.paddleThickness + s
      if (!hitLeft && !hitRight) return false
      var off = (b.y + s / 2 - p.pos) / (half + s / 2)
      if (Math.abs(off) > 1) return false
      bounce(b, off, "x", hitLeft ? 1 : -1)
      b.x = hitLeft ? line : line - s
      return true
    }
    var hitTop = p.side === "top" && b.vy < 0 && b.y <= line && b.y >= line - root.paddleThickness - s
    var hitBottom = p.side === "bottom" && b.vy > 0 && b.y + s >= line && b.y + s <= line + root.paddleThickness + s
    if (!hitTop && !hitBottom) return false
    var offX = (b.x + s / 2 - p.pos) / (half + s / 2)
    if (Math.abs(offX) > 1) return false
    bounce(b, offX, "y", hitTop ? 1 : -1)
    b.y = hitTop ? line : line - s
    return true
  }

  function bounce(b, offset, axis, dir) {
    var speed = Math.sqrt(b.vx * b.vx + b.vy * b.vy)
    var accel = root.variant === "impossible" ? 1.045 : 1.03
    speed = Math.min(speed * accel, baseSpeed() * (root.variant === "impossible" ? 4.5 : 2.2))
    var angle = offset * 1.0
    if (axis === "x") {
      b.vx = Math.cos(angle) * speed * dir
      b.vy = Math.sin(angle) * speed
    } else {
      b.vy = Math.cos(angle) * speed * dir
      b.vx = Math.sin(angle) * speed
    }
    root.rally++
  }

  function step(dt) {
    if (root.width <= 0 || root.height <= 0) return
    if (root.paddles.length === 0) setupPaddles()
    if (root.bannerTime > 0) root.bannerTime -= dt
    if (root.chaosTime > 0) {
      root.chaosTime -= dt
      if (root.chaosTime <= 0) root.balls = root.balls.slice(0, 1)
    }

    root.serveDelay -= dt
    if (root.serveDelay <= 0 && root.balls.length < wantedBalls()) {
      // One serve in two hundred and fifty becomes twenty balls at once.
      if (root.chaosTime <= 0 && root.host && root.host.rare(250)) {
        root.chaosTime = 25
        showBanner("20 BALL MODE", 2.5)
      }
      serve()
      root.serveDelay = root.balls.length < wantedBalls() ? 0.25 : 0.8
    }

    for (var pi = 0; pi < root.paddles.length; pi++) steerPaddle(root.paddles[pi], dt)

    // Sub-steps keep ludicrous-speed balls from skipping through a paddle.
    var fastest = 1
    for (var i = 0; i < root.balls.length; i++)
      fastest = Math.max(fastest, Math.abs(root.balls[i].vx) + Math.abs(root.balls[i].vy))
    var steps = Math.min(12, Math.max(1, Math.ceil(fastest * dt / (root.paddleThickness * 0.8))))
    var h = dt / steps

    for (var sIndex = 0; sIndex < steps; sIndex++) {
      var kept = []
      for (var bi = 0; bi < root.balls.length; bi++) {
        var b = root.balls[bi]
        b.x += b.vx * h
        b.y += b.vy * h
        if (!root.fourPaddle) {
          if (b.y < 0) { b.y = -b.y; b.vy = Math.abs(b.vy) }
          var floor = root.height - root.ballSize
          if (b.y > floor) { b.y = 2 * floor - b.y; b.vy = -Math.abs(b.vy) }
        }
        for (var pj = 0; pj < root.paddles.length; pj++) {
          var p = root.paddles[pj]
          // Impossible Pong is only impossible until the ball outruns
          // physics: past top speed a paddle occasionally glitches.
          if (root.variant === "impossible" && p.tracking === b.id && root.rally > 60 && Math.random() < 0.0015) continue
          if (collide(b, p)) break
        }
        var out = b.x < -root.ballSize * 2 ? "right" : (b.x > root.width + root.ballSize ? "left" : "")
        if (!out && root.fourPaddle)
          out = b.y < -root.ballSize * 2 ? "right" : (b.y > root.height + root.ballSize ? "left" : "")
        if (out) {
          award(out)
          if (root.serveDelay < 0.5) root.serveDelay = 0.5
        } else {
          kept.push(b)
        }
      }
      root.balls = kept
    }
    sync()
  }

  // Push the simulation onto the scene's items.
  function sync() {
    for (var i = 0; i < root.maxBalls; i++) {
      var item = ballRepeater.itemAt(i)
      if (!item) continue
      var b = root.balls[i]
      item.visible = !!b
      if (b) { item.x = b.x; item.y = b.y }
    }
    for (var j = 0; j < 4; j++) {
      var pad = paddleRepeater.itemAt(j)
      if (!pad) continue
      var p = root.paddles[j]
      pad.visible = !!p && !(root.variant === "quattro-vs-tux" && j < 2)
      if (!p) continue
      var line = paddleLine(p)
      if (p.axis === "y") {
        pad.width = root.paddleThickness
        pad.height = root.paddleLength
        pad.x = p.side === "left" ? line - root.paddleThickness : line
        pad.y = p.pos - root.paddleLength / 2
      } else {
        pad.width = root.paddleLength
        pad.height = root.paddleThickness
        pad.x = p.pos - root.paddleLength / 2
        pad.y = p.side === "top" ? line - root.paddleThickness : line
      }
    }
    if (root.variant === "quattro-vs-tux" && root.paddles.length >= 2) {
      // The car stands on its tail; rotation turns it about its centre. It
      // sits against the edge margin, and the ball's line (paddleDepth)
      // falls inside its box, on the car itself.
      carPaddle.x = root.u * 3 + carPaddle.height / 2 - carPaddle.width / 2
      carPaddle.y = root.paddles[0].pos - carPaddle.height / 2
      tuxPaddle.x = paddleLine(root.paddles[1])
      tuxPaddle.y = root.paddles[1].pos - tuxPaddle.height / 2
    }
  }

  Rectangle { anchors.fill: parent; color: "black" }

  // The net.
  Repeater {
    model: 30
    Rectangle {
      required property int index
      visible: !root.fourPaddle
      x: root.width / 2 - root.u * 0.4
      y: index * root.height / 30 + root.height / 120
      width: root.u * 0.8
      height: root.height / 60
      color: root.net
    }
  }

  // Lifetime scoreboard.
  Row {
    id: leftBoard
    anchors { right: parent.horizontalCenter; rightMargin: root.u * 8; top: parent.top; topMargin: root.u * 7 }
    spacing: root.u * 2
    Quattro {
      anchors.verticalCenter: parent.verticalCenter
      facingLeft: false
      livery: 1
      pixel: root.u * 0.28
    }
    PixelText { text: "QUATTRO"; color: root.ink; pixel: root.u * 0.5; anchors.verticalCenter: parent.verticalCenter }
  }
  PixelText {
    anchors { right: leftBoard.right; top: leftBoard.bottom; topMargin: root.u * 1.5 }
    text: Util.formatThousands(root.lifetimeLeft)
    color: root.ink
    pixel: root.u * 1.1
  }
  Row {
    id: rightBoard
    anchors { left: parent.horizontalCenter; leftMargin: root.u * 8; top: parent.top; topMargin: root.u * 7 }
    spacing: root.u * 2
    PixelText { text: "TUX"; color: root.ink; pixel: root.u * 0.5; anchors.verticalCenter: parent.verticalCenter }
    PixelSprite {
      anchors.verticalCenter: parent.verticalCenter
      rows: Sprites.tux
      colors: Sprites.tuxPalette
      pixel: root.u * 0.4
    }
  }
  PixelText {
    anchors { left: rightBoard.left; top: rightBoard.bottom; topMargin: root.u * 1.5 }
    text: Util.formatThousands(root.lifetimeRight)
    color: root.ink
    pixel: root.u * 1.1
  }

  // This game's score, small, at the foot of the net.
  PixelText {
    anchors { horizontalCenter: parent.horizontalCenter; bottom: parent.bottom; bottomMargin: root.u * 4 }
    text: root.scoreLeft + " - " + root.scoreRight
    color: root.ink
    pixel: root.u * 0.6
    visible: !(root.variant === "impossible" && root.rally > 5)
  }

  Repeater {
    id: paddleRepeater
    model: 4
    Rectangle { visible: false; color: root.ink }
  }

  Quattro {
    id: carPaddle
    visible: root.variant === "quattro-vs-tux"
    facingLeft: false
    pixel: root.paddleLength / Sprites.quattroColumns
    rotation: -90
  }
  PixelSprite {
    id: tuxPaddle
    visible: root.variant === "quattro-vs-tux"
    rows: Sprites.tux
    colors: Sprites.tuxPalette
    pixel: root.paddleLength / 12
  }

  Repeater {
    id: ballRepeater
    model: root.maxBalls
    Rectangle {
      visible: false
      width: root.ballSize
      height: root.ballSize
      color: root.ink
    }
  }

  PixelText {
    anchors { horizontalCenter: parent.horizontalCenter; bottom: parent.bottom; bottomMargin: root.u * 4 }
    visible: root.variant === "impossible" && root.rally > 5
    text: "RALLY " + root.rally
    color: root.net
    pixel: root.u * 0.5
  }

  PixelText {
    anchors.centerIn: parent
    visible: root.bannerTime > 0
    text: root.banner
    color: root.ink
    pixel: root.u * 0.9
    opacity: Math.min(1, root.bannerTime * 2)
  }

  FrameAnimation {
    running: root.running && root.visible
    onTriggered: root.step(Math.min(frameTime, 0.05))
  }

  Timer {
    interval: 2000
    repeat: true
    running: root.running
    onTriggered: root.refreshLifetime()
  }

  onHostChanged: refreshLifetime()
  Component.onCompleted: {
    refreshLifetime()
    newGame()
  }
}
