import QtQuick
import "../../lib/Util.js" as Util

// Trace: this machine at the centre, its busiest processes around it, and
// the hosts they talk to on the outer ring, with packets running the links.
//
// The graph itself is painted only when the feed changes it (every couple
// of seconds); packets, flashes and the pulse are items the GPU moves.
Item {
  id: trace

  property var feed: null
  property var host: null
  property bool active: true
  property real unit: 1

  property var graph: ({ cx: 0, cy: 0, nodes: [], peers: [] })
  property var packets: []
  property var flashes: ({})
  readonly property int maxPackets: 140

  Connections {
    target: trace.feed
    function onEvent(kind, text) {
      if (!trace.active) return
      var name = String(text).split(" ")[0]
      var next = {}
      for (var k in trace.flashes) next[k] = trace.flashes[k]
      next[name] = 1
      trace.flashes = next
    }
    function onProcessesChanged() { if (trace.active) trace.relayout() }
    function onConnectionsChanged() { if (trace.active) trace.relayout() }
  }

  function relayout() {
    var cx = width / 2, cy = height / 2
    var r1 = Math.min(width, height) * 0.24
    var r2 = Math.min(width, height) * 0.44
    var procs = trace.feed ? trace.feed.processes.slice(0, 12) : []
    var nodes = []
    for (var i = 0; i < procs.length; i++) {
      var a = i / Math.max(1, procs.length) * Math.PI * 2 - Math.PI / 2
      nodes.push({ name: Util.cleanText(String(procs[i].name), 16), cpu: procs[i].cpu, x: cx + Math.cos(a) * r1, y: cy + Math.sin(a) * r1 * 0.8 })
    }
    var conns = trace.feed ? trace.feed.connections.slice(-16) : []
    var peers = []
    for (var j = 0; j < conns.length; j++) {
      var b = j / Math.max(1, conns.length) * Math.PI * 2 - Math.PI / 2 + 0.2
      // Link each peer to the process that owns it, when we know it.
      var owner = -1
      for (var n = 0; n < nodes.length; n++) if (nodes[n].name === conns[j].process) owner = n
      if (owner < 0 && nodes.length) owner = j % nodes.length
      peers.push({ name: conns[j].peer, port: conns[j].port, owner: owner, x: cx + Math.cos(b) * r2 * 1.25, y: cy + Math.sin(b) * r2 * 0.85 })
    }
    trace.graph = { cx: cx, cy: cy, nodes: nodes, peers: peers }
    canvas.requestPaint()
  }

  onWidthChanged: relayout()
  onHeightChanged: relayout()
  onActiveChanged: if (active) relayout()

  function edge(pk) {
    var g = trace.graph
    if (pk.outer && g.peers.length) {
      var peer = g.peers[Math.floor(pk.edge * g.peers.length)]
      var from = g.nodes[peer.owner]
      if (from) return [from.x, from.y, peer.x, peer.y]
    }
    if (!g.nodes.length) return null
    var node = g.nodes[Math.floor(pk.edge * g.nodes.length)]
    return [g.cx, g.cy, node.x, node.y]
  }

  function step(dt) {
    var next = {}
    for (var k in trace.flashes) if (trace.flashes[k] - dt > 0) next[k] = trace.flashes[k] - dt
    trace.flashes = next

    var rate = trace.feed ? (trace.feed.rxRate + trace.feed.txRate) : 0
    var spawn = Math.min(40, 2 + rate / 20000) * dt
    var live = []
    for (var p = 0; p < trace.packets.length; p++) {
      var pk = trace.packets[p]
      pk.t += dt * pk.speed
      if (pk.t < 1) live.push(pk)
    }
    while (Math.random() < spawn && live.length < trace.maxPackets) {
      live.push({ edge: Math.random(), t: 0, speed: Util.rand(0.4, 1.2), outer: Math.random() < 0.6, back: Math.random() < 0.5 })
      spawn -= 1
    }
    trace.packets = live

    for (var i = 0; i < trace.maxPackets; i++) {
      var dot = packetRepeater.itemAt(i)
      if (!dot) continue
      var packet = trace.packets[i]
      var e = packet ? edge(packet) : null
      if (!e) { if (dot.visible) dot.visible = false; continue }
      var t = packet.back ? 1 - packet.t : packet.t
      dot.x = e[0] + (e[2] - e[0]) * t - dot.width / 2
      dot.y = e[1] + (e[3] - e[1]) * t - dot.height / 2
      dot.visible = true
    }
    pulse.phase = (pulse.phase + dt * 0.8) % 1
  }

  Rectangle { anchors.fill: parent; color: "black" }

  Canvas {
    id: canvas
    anchors.fill: parent
    renderStrategy: Canvas.Cooperative
    onPaint: {
      var ctx = getContext("2d")
      ctx.clearRect(0, 0, width, height)
      var g = trace.graph
      var u = trace.unit

      ctx.lineWidth = Math.max(1, u)
      ctx.strokeStyle = "rgba(25,201,74,0.35)"
      ctx.beginPath()
      for (var i = 0; i < g.nodes.length; i++) { ctx.moveTo(g.cx, g.cy); ctx.lineTo(g.nodes[i].x, g.nodes[i].y) }
      for (var j = 0; j < g.peers.length; j++) {
        var owner = g.nodes[g.peers[j].owner]
        if (!owner) continue
        ctx.moveTo(owner.x, owner.y)
        ctx.lineTo(g.peers[j].x, g.peers[j].y)
      }
      ctx.stroke()

      ctx.font = Math.round(13 * u) + "px monospace"
      ctx.textAlign = "center"
      for (var n = 0; n < g.nodes.length; n++) {
        var nd = g.nodes[n]
        var r = (6 + Math.min(20, nd.cpu / 4)) * u
        ctx.fillStyle = "#19c94a"
        ctx.beginPath(); ctx.arc(nd.x, nd.y, r, 0, Math.PI * 2); ctx.fill()
        ctx.fillStyle = "#9dffb8"
        ctx.fillText(nd.name, nd.x, nd.y + r + 16 * u)
      }
      for (var q = 0; q < g.peers.length; q++) {
        var pr = g.peers[q]
        ctx.strokeStyle = "#f2c230"
        ctx.strokeRect(pr.x - 5 * u, pr.y - 5 * u, 10 * u, 10 * u)
        ctx.fillStyle = "rgba(242,194,48,0.8)"
        ctx.fillText(pr.name + ":" + pr.port, pr.x, pr.y + 20 * u)
      }
      ctx.fillStyle = "#e9fff0"
      ctx.beginPath(); ctx.arc(g.cx, g.cy, 16 * u, 0, Math.PI * 2); ctx.fill()
      ctx.fillStyle = "#9dffb8"
      ctx.font = "bold " + Math.round(16 * u) + "px monospace"
      ctx.fillText(trace.host && trace.host.hostName ? trace.host.hostName.toUpperCase() : "LOCALHOST", g.cx, g.cy + 44 * u)
      ctx.textAlign = "left"
      ctx.fillText("TRACE // " + g.nodes.length + " PROCESSES // " + g.peers.length + " LINKS", 30 * u, 40 * u)
    }
  }

  // Processes that just did something flash.
  Repeater {
    model: trace.graph.nodes
    Rectangle {
      required property var modelData
      readonly property real level: trace.flashes[modelData.name] || 0
      visible: level > 0
      width: (24 + level * 30) * trace.unit
      height: width
      radius: width / 2
      x: modelData.x - width / 2
      y: modelData.y - height / 2
      color: "transparent"
      border.color: "#e9fff0"
      border.width: 2 * trace.unit
      opacity: level
    }
  }

  // The pulse around this machine.
  Rectangle {
    id: pulse
    property real phase: 0
    width: (32 + phase * 60) * trace.unit
    height: width
    radius: width / 2
    x: trace.graph.cx - width / 2
    y: trace.graph.cy - height / 2
    color: "transparent"
    border.color: "#9dffb8"
    border.width: Math.max(1, trace.unit)
    opacity: 1 - phase
  }

  Repeater {
    id: packetRepeater
    model: trace.maxPackets
    Rectangle { visible: false; width: 4 * trace.unit; height: width; color: "#e9fff0" }
  }

  FrameAnimation {
    running: trace.active && trace.visible
    onTriggered: trace.step(Math.min(frameTime, 0.05))
  }
}
