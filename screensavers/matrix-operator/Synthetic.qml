import QtQuick
import "../../lib/Util.js" as Util

// A pretend machine with the same shape as lib/SystemFeed.qml, for when live
// system data is off. The console labels itself SIMULATION while this runs.
Item {
  id: feed

  readonly property bool live: false
  property bool active: true

  property real cpu: 0.2
  property real mem: 0.45
  property real load1: 0.6
  property real rxRate: 0
  property real txRate: 0
  property real uptime: 86400 * 3 + 3600 * 7
  property real battery: -1
  property int processCount: 212
  property int sshSessions: 0
  property var processes: []
  property var connections: []

  signal event(string kind, string text)

  readonly property var names: [
    "systemd", "Hyprland", "quickshell", "pipewire", "wireplumber", "NetworkManager",
    "firefox", "chromium", "alacritty", "nvim", "node", "python3", "cargo", "rustc",
    "docker", "containerd", "sshd", "walker", "mako", "btop", "kworker/2:1", "ksoftirqd/0",
    "gpg-agent", "dbus-broker", "systemd-journald", "systemd-resolved", "tailscaled", "code"
  ]
  readonly property var units: ["systemd", "kernel", "NetworkManager", "sshd", "sudo", "systemd-logind", "bluetoothd", "tailscaled", "dockerd", "pacman"]
  readonly property var packages: ["linux", "mesa", "hyprland", "firefox", "neovim", "python", "nodejs", "rust", "qt6-base", "pipewire"]

  property var pool: []
  property int nextPid: 4100

  function seed() {
    var list = []
    for (var i = 0; i < feed.names.length; i++)
      list.push({ pid: Util.randInt(1, 4000), name: feed.names[i], cpu: Math.random() * 4, mem: Math.random() * 3 })
    list[0].pid = 1
    feed.pool = list
    var conns = []
    for (var c = 0; c < 9; c++) conns.push(fakeConnection())
    feed.connections = conns
    tick()
  }

  function fakeConnection() {
    var owner = Util.pick(["firefox", "chromium", "tailscaled", "sshd", "node", "code", "NetworkManager"])
    return {
      proto: Math.random() < 0.85 ? "tcp" : "udp",
      state: "ESTAB",
      local: ":" + Util.randInt(32768, 60999),
      peer: Util.randInt(20, 220) + "." + Util.randInt(0, 255) + ".x.x",
      port: Util.pick([443, 443, 443, 80, 22, 993, 5228, 41641]),
      process: owner
    }
  }

  function tick() {
    var t = Date.now() / 1000
    feed.cpu = Util.clamp(0.18 + 0.12 * Math.sin(t / 7) + Math.random() * 0.15 + (Math.random() < 0.05 ? 0.4 : 0), 0, 1)
    feed.mem = Util.clamp(feed.mem + Util.rand(-0.004, 0.004), 0.3, 0.8)
    feed.load1 = feed.cpu * 8 * 0.6 + 0.3
    feed.rxRate = Math.max(0, 40000 + Math.sin(t / 5) * 30000 + (Math.random() < 0.08 ? 900000 : 0))
    feed.txRate = feed.rxRate * Util.rand(0.1, 0.4)
    feed.uptime += 1

    for (var i = 0; i < feed.pool.length; i++) {
      var p = feed.pool[i]
      p.cpu = Math.max(0, p.cpu * 0.7 + Math.random() * (i % 5 === 0 ? 25 : 6) * Math.random())
    }
    // Processes come and go.
    if (Math.random() < 0.35) {
      var name = Util.pick(feed.names)
      var proc = { pid: feed.nextPid++, name: name, cpu: Math.random() * 20, mem: Math.random() * 2 }
      feed.pool.push(proc)
      feed.event("spawn", name + " [" + proc.pid + "]")
    }
    if (feed.pool.length > 30 && Math.random() < 0.35) {
      var idx = Util.randInt(1, feed.pool.length - 1)
      var gone = feed.pool.splice(idx, 1)[0]
      feed.event("exit", gone.name + " [" + gone.pid + "]")
    }
    if (Math.random() < 0.25) feed.event("journal", Util.pick(feed.units))
    if (Math.random() < 0.04) feed.event("package", "upgraded " + Util.pick(feed.packages))
    if (Math.random() < 0.15) {
      var conn = fakeConnection()
      feed.connections = feed.connections.slice(-11).concat([conn])
      feed.event("net", conn.process + " -> " + conn.peer + ":" + conn.port)
    }

    var sorted = feed.pool.slice().sort(function(a, b) { return b.cpu - a.cpu })
    feed.processes = sorted.slice(0, 24)
    feed.processCount = 180 + feed.pool.length
  }

  Timer {
    interval: 1000
    repeat: true
    running: feed.active
    onTriggered: feed.tick()
  }

  Component.onCompleted: seed()
}
