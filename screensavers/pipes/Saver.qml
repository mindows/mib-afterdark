import QtQuick
import "../../lib/Util.js" as Util

// Pipes: pipes grow through a 3D grid seen in perspective until the room is
// full, then the room fades and starts again. Only the newest segments are
// painted each frame; the canvas keeps everything drawn before.
Item {
  id: root

  property var host: null
  property bool running: true

  readonly property string styleOption: host ? host.option("style", "random") : "random"
  readonly property int pipeCount: Number(host ? host.option("pipes", "3") : "3") || 3

  // Grid size and camera.
  readonly property int nx: 16
  readonly property int ny: 10
  readonly property int nz: 10
  readonly property real camDistance: 23
  readonly property real yaw: 0.55
  readonly property real pitch: 0.32

  property string style: "classic"
  property var occupied: ({})
  property int filled: 0
  property var pipes: []
  property var ops: []
  property real growClock: 0
  property real fade: 0
  property bool clearNext: true

  readonly property var colors: ["#e8433a", "#3fbf5f", "#3a7bd5", "#f2c230", "#2fc4c4", "#c457d6", "#f08a24", "#e8e8e8"]
  readonly property var dirs: [[1, 0, 0], [-1, 0, 0], [0, 1, 0], [0, -1, 0], [0, 0, 1], [0, 0, -1]]

  function key(c) { return c[0] + "," + c[1] + "," + c[2] }

  function inside(c) {
    return c[0] >= 0 && c[0] < root.nx && c[1] >= 0 && c[1] < root.ny && c[2] >= 0 && c[2] < root.nz
  }

  function project(c) {
    var x = c[0] - (root.nx - 1) / 2
    var y = c[1] - (root.ny - 1) / 2
    var z = c[2] - (root.nz - 1) / 2
    var cy = Math.cos(root.yaw), sy = Math.sin(root.yaw)
    var x1 = x * cy - z * sy
    var z1 = x * sy + z * cy
    var cp = Math.cos(root.pitch), sp = Math.sin(root.pitch)
    var y2 = y * cp - z1 * sp
    var z2 = y * sp + z1 * cp + root.camDistance
    var f = root.height * 1.9
    return { x: root.width / 2 + x1 / z2 * f, y: root.height / 2 - y2 / z2 * f, r: 0.26 * f / z2 }
  }

  function reset() {
    root.occupied = ({})
    root.filled = 0
    root.pipes = []
    root.ops = []
    root.fade = 0
    root.clearNext = true
    root.style = root.styleOption === "random" ? Util.pick(["classic", "classic", "neon", "wireframe"]) : root.styleOption
  }

  function freeCell() {
    for (var tries = 0; tries < 60; tries++) {
      var c = [Util.randInt(0, root.nx - 1), Util.randInt(0, root.ny - 1), Util.randInt(0, root.nz - 1)]
      if (!root.occupied[key(c)]) return c
    }
    return null
  }

  function startPipe() {
    var c = freeCell()
    if (!c) return null
    root.occupied[key(c)] = true
    root.filled++
    var pipe = { at: c, dir: Util.pick(root.dirs), color: Util.pick(root.colors), alive: true }
    root.ops.push({ kind: "joint", at: c, color: pipe.color })
    return pipe
  }

  function growPipe(pipe) {
    var options = []
    var straight = [pipe.at[0] + pipe.dir[0], pipe.at[1] + pipe.dir[1], pipe.at[2] + pipe.dir[2]]
    var canStraight = inside(straight) && !root.occupied[key(straight)]
    for (var i = 0; i < root.dirs.length; i++) {
      var d = root.dirs[i]
      var n = [pipe.at[0] + d[0], pipe.at[1] + d[1], pipe.at[2] + d[2]]
      if (inside(n) && !root.occupied[key(n)]) options.push(d)
    }
    if (options.length === 0) {
      root.ops.push({ kind: "joint", at: pipe.at, color: pipe.color })
      pipe.alive = false
      return
    }
    var nextDir = canStraight && Math.random() < 0.72 ? pipe.dir : Util.pick(options)
    if (nextDir !== pipe.dir) {
      // Something odd sometimes grows at a bend.
      var teapot = root.host ? root.host.rare(300) : Util.chance(300)
      root.ops.push({ kind: teapot ? "teapot" : "joint", at: pipe.at, color: pipe.color })
    }
    var next = [pipe.at[0] + nextDir[0], pipe.at[1] + nextDir[1], pipe.at[2] + nextDir[2]]
    root.ops.push({ kind: "segment", from: pipe.at, to: next, color: pipe.color })
    root.occupied[key(next)] = true
    root.filled++
    pipe.at = next
    pipe.dir = nextDir
  }

  function step(dt) {
    if (root.width <= 0) return
    if (root.fade > 0) {
      root.fade -= dt
      if (root.fade <= 0) reset()
      canvas.requestPaint()
      return
    }
    root.growClock += dt
    // More pipes grow more slowly each, so a room takes about half a
    // minute to fill however many there are.
    var tick = 0.04 + 0.03 * root.pipeCount
    while (root.growClock >= tick) {
      root.growClock -= tick
      var alive = []
      for (var i = 0; i < root.pipes.length; i++) {
        growPipe(root.pipes[i])
        if (root.pipes[i].alive) alive.push(root.pipes[i])
      }
      while (alive.length < root.pipeCount) {
        var p = startPipe()
        if (!p) break
        alive.push(p)
      }
      root.pipes = alive
      if (root.filled > root.nx * root.ny * root.nz * 0.42 || alive.length === 0) {
        root.fade = 2.2
        break
      }
    }
    if (root.ops.length) canvas.requestPaint()
  }

  function shade(hex, k) {
    var c = Qt.color(hex)
    return Qt.rgba(Math.min(1, c.r * k), Math.min(1, c.g * k), Math.min(1, c.b * k), 1)
  }

  function alpha(hex, a) {
    var c = Qt.color(hex)
    return Qt.rgba(c.r, c.g, c.b, a)
  }

  function drawSegment(ctx, op) {
    var a = project(op.from)
    var b = project(op.to)
    var r = (a.r + b.r) / 2
    var dx = b.x - a.x, dy = b.y - a.y
    var len = Math.max(0.001, Math.sqrt(dx * dx + dy * dy))
    // The side of the pipe that faces the light (up and to the left).
    var nx = -dy / len, ny = dx / len
    if (ny > 0 || (ny === 0 && nx > 0)) { nx = -nx; ny = -ny }

    function line(width, color, offset) {
      ctx.strokeStyle = color
      ctx.lineWidth = Math.max(0.5, width)
      ctx.beginPath()
      ctx.moveTo(a.x + nx * offset, a.y + ny * offset)
      ctx.lineTo(b.x + nx * offset, b.y + ny * offset)
      ctx.stroke()
    }

    if (root.style === "wireframe") {
      line(1, alpha(op.color, 0.9), r)
      line(1, alpha(op.color, 0.9), -r)
      ctx.strokeStyle = alpha(op.color, 0.6)
      ctx.lineWidth = 1
      ctx.beginPath()
      for (var t = 0; t <= 1.001; t += 0.5) {
        var x = a.x + dx * t, y = a.y + dy * t
        ctx.moveTo(x + nx * r, y + ny * r)
        ctx.lineTo(x - nx * r, y - ny * r)
      }
      ctx.stroke()
      return
    }
    ctx.lineCap = "round"
    if (root.style === "neon") {
      line(r * 3.2, alpha(op.color, 0.10), 0)
      line(r * 1.9, alpha(op.color, 0.25), 0)
      line(r * 0.8, shade(op.color, 1.3), 0)
      line(r * 0.25, "#ffffff", 0)
      return
    }
    line(r * 2, shade(op.color, 0.4), 0)
    line(r * 1.6, shade(op.color, 0.75), r * 0.1)
    line(r * 1.0, op.color, r * 0.3)
    line(r * 0.45, shade(op.color, 1.45), r * 0.55)
    line(r * 0.12, "rgba(255,255,255,0.8)", r * 0.62)
  }

  function drawJoint(ctx, op) {
    var p = project(op.at)
    var r = p.r * 1.3
    if (root.style === "wireframe") {
      ctx.strokeStyle = alpha(op.color, 0.9)
      ctx.lineWidth = 1
      ctx.beginPath()
      ctx.arc(p.x, p.y, r, 0, Math.PI * 2)
      ctx.stroke()
      return
    }
    if (root.style === "neon") {
      ctx.fillStyle = alpha(op.color, 0.2)
      ctx.beginPath(); ctx.arc(p.x, p.y, r * 1.6, 0, Math.PI * 2); ctx.fill()
      ctx.fillStyle = shade(op.color, 1.3)
      ctx.beginPath(); ctx.arc(p.x, p.y, r * 0.55, 0, Math.PI * 2); ctx.fill()
      return
    }
    var g = ctx.createRadialGradient(p.x - r * 0.35, p.y - r * 0.4, r * 0.1, p.x, p.y, r)
    g.addColorStop(0, shade(op.color, 1.7))
    g.addColorStop(0.45, op.color)
    g.addColorStop(1, shade(op.color, 0.35))
    ctx.fillStyle = g
    ctx.beginPath()
    ctx.arc(p.x, p.y, r, 0, Math.PI * 2)
    ctx.fill()
  }

  // The rare joint.
  function drawTeapot(ctx, op) {
    var p = project(op.at)
    var r = p.r * 2.2
    var x = p.x, y = p.y
    var g = ctx.createRadialGradient(x - r * 0.3, y - r * 0.35, r * 0.1, x, y, r * 1.1)
    g.addColorStop(0, shade(op.color, 1.7))
    g.addColorStop(0.5, op.color)
    g.addColorStop(1, shade(op.color, 0.35))
    ctx.fillStyle = g
    ctx.strokeStyle = shade(op.color, 0.3)
    ctx.lineWidth = Math.max(1, r * 0.08)
    // Spout.
    ctx.beginPath()
    ctx.moveTo(x + r * 0.7, y + r * 0.1)
    ctx.quadraticCurveTo(x + r * 1.3, y + r * 0.1, x + r * 1.45, y - r * 0.55)
    ctx.lineTo(x + r * 1.25, y - r * 0.55)
    ctx.quadraticCurveTo(x + r * 1.1, y - r * 0.1, x + r * 0.7, y - r * 0.2)
    ctx.closePath()
    ctx.fill(); ctx.stroke()
    // Handle.
    ctx.lineWidth = Math.max(1, r * 0.18)
    ctx.beginPath()
    ctx.arc(x - r * 0.95, y - r * 0.05, r * 0.38, Math.PI * 0.5, Math.PI * 1.5)
    ctx.stroke()
    // Body, lid, knob.
    ctx.lineWidth = Math.max(1, r * 0.08)
    ctx.beginPath()
    ctx.ellipse(x - r, y - r * 0.65, r * 2, r * 1.35)
    ctx.fill(); ctx.stroke()
    ctx.beginPath()
    ctx.ellipse(x - r * 0.5, y - r * 0.9, r, r * 0.4)
    ctx.fill(); ctx.stroke()
    ctx.beginPath()
    ctx.arc(x, y - r * 0.95, r * 0.14, 0, Math.PI * 2)
    ctx.fill(); ctx.stroke()
  }

  Rectangle { anchors.fill: parent; color: "black" }

  Canvas {
    id: canvas
    anchors.fill: parent
    renderStrategy: Canvas.Cooperative

    onPaint: {
      var ctx = getContext("2d")
      if (root.clearNext) {
        ctx.fillStyle = "black"
        ctx.fillRect(0, 0, width, height)
        root.clearNext = false
      }
      if (root.fade > 0) {
        ctx.fillStyle = "rgba(0,0,0,0.09)"
        ctx.fillRect(0, 0, width, height)
        return
      }
      var list = root.ops
      root.ops = []
      for (var i = 0; i < list.length; i++) {
        var op = list[i]
        if (op.kind === "segment") root.drawSegment(ctx, op)
        else if (op.kind === "teapot") root.drawTeapot(ctx, op)
        else root.drawJoint(ctx, op)
      }
    }
  }

  FrameAnimation {
    running: root.running && root.visible
    onTriggered: root.step(Math.min(frameTime, 0.05))
  }

  onStyleOptionChanged: reset()
  Component.onCompleted: reset()
}
