import QtQuick
import Quickshell
import Quickshell.Io
import Quickshell.Services.UPower
import "Util.js" as Util

// Live telemetry for the screensavers that react to the machine. It only
// runs while such a screensaver is on screen and live system data is on in
// the control panel; otherwise nothing here is read or started.
//
// Everything stays on this machine. Sources: /proc (CPU, memory, network
// totals, uptime, load), `ps` (process names and CPU), `ss` (established
// connections, remote addresses masked to their first half), the journal
// (unit and identifier names only, never message text), pacman's log
// (package names), and UPower (battery level).
Item {
  id: feed

  readonly property bool live: true
  property bool active: false

  property real cpu: 0
  property real mem: 0
  property real load1: 0
  property real rxRate: 0
  property real txRate: 0
  property real uptime: 0
  property real battery: -1
  property int processCount: 0
  property int sshSessions: 0
  property var processes: []
  property var connections: []

  signal event(string kind, string text)

  property var lastCpu: null
  property var lastNet: null
  property var knownPids: null
  // Our own ps and ss runs, so they never show up as "events".
  property var helperPids: []
  property var knownLinks: null
  property real journalBudget: 0

  // ------------------------------------------------------------ /proc

  FileView { id: statFile; path: "/proc/stat"; blockAllReads: true; printErrors: false }
  FileView { id: memFile; path: "/proc/meminfo"; blockAllReads: true; printErrors: false }
  FileView { id: netFile; path: "/proc/net/dev"; blockAllReads: true; printErrors: false }
  FileView { id: uptimeFile; path: "/proc/uptime"; blockAllReads: true; printErrors: false }
  FileView { id: loadFile; path: "/proc/loadavg"; blockAllReads: true; printErrors: false }

  function readProc() {
    statFile.reload()
    var first = String(statFile.text()).split("\n")[0].trim().split(/\s+/)
    if (first[0] === "cpu") {
      var n = first.slice(1, 9).map(Number)
      var idle = n[3] + n[4]
      var total = 0
      for (var i = 0; i < n.length; i++) total += n[i] || 0
      if (feed.lastCpu && total > feed.lastCpu.total)
        feed.cpu = Util.clamp(1 - (idle - feed.lastCpu.idle) / (total - feed.lastCpu.total), 0, 1)
      feed.lastCpu = { idle: idle, total: total }
    }

    memFile.reload()
    var memText = String(memFile.text())
    var totalMatch = /MemTotal:\s+(\d+)/.exec(memText)
    var availMatch = /MemAvailable:\s+(\d+)/.exec(memText)
    if (totalMatch && availMatch) feed.mem = Util.clamp(1 - Number(availMatch[1]) / Number(totalMatch[1]), 0, 1)

    netFile.reload()
    var rx = 0, tx = 0
    var lines = String(netFile.text()).split("\n")
    for (var l = 2; l < lines.length; l++) {
      var parts = lines[l].trim().split(/[:\s]+/)
      if (parts.length < 10 || parts[0] === "lo") continue
      rx += Number(parts[1]) || 0
      tx += Number(parts[9]) || 0
    }
    var now = Date.now()
    if (feed.lastNet) {
      var dt = Math.max(0.1, (now - feed.lastNet.at) / 1000)
      feed.rxRate = Math.max(0, (rx - feed.lastNet.rx) / dt)
      feed.txRate = Math.max(0, (tx - feed.lastNet.tx) / dt)
    }
    feed.lastNet = { rx: rx, tx: tx, at: now }

    uptimeFile.reload()
    feed.uptime = Number(String(uptimeFile.text()).split(" ")[0]) || 0
    loadFile.reload()
    feed.load1 = Number(String(loadFile.text()).split(" ")[0]) || 0

    var device = UPower.displayDevice
    feed.battery = device && device.isPresent && device.isLaptopBattery ? Util.clamp(Number(device.percentage) || 0, 0, 1) : -1
  }

  // ------------------------------------------------------------ processes

  Process {
    id: psProcess
    command: ["ps", "-eo", "pid=,pcpu=,pmem=,comm=", "--sort=-pcpu"]
    onStarted: feed.noteHelper(processId)
    stdout: StdioCollector {
      waitForEnd: true
      onStreamFinished: feed.readProcesses(text)
    }
  }

  function noteHelper(pid) {
    if (pid > 0) feed.helperPids = feed.helperPids.slice(-5).concat([pid])
  }

  function readProcesses(text) {
    var lines = String(text).split("\n")
    var list = []
    var pids = {}
    for (var i = 0; i < lines.length && i < 5000; i++) {
      var m = /^\s*(\d+)\s+([\d.]+)\s+([\d.]+)\s+(.+)$/.exec(lines[i])
      if (!m) continue
      var proc = { pid: Number(m[1]), cpu: Number(m[2]), mem: Number(m[3]), name: Util.cleanText(m[4], 32) }
      if (feed.helperPids.indexOf(proc.pid) !== -1) continue
      pids[proc.pid] = proc.name
      if (list.length < 24) list.push(proc)
    }
    feed.processCount = Object.keys(pids).length
    feed.processes = list
    // Starts and exits since the last look, a few at a time.
    if (feed.knownPids) {
      var told = 0
      for (var pid in pids) {
        if (!(pid in feed.knownPids) && told < 4) { feed.event("spawn", pids[pid] + " [" + pid + "]"); told++ }
      }
      for (var old in feed.knownPids) {
        if (!(old in pids) && told < 7) { feed.event("exit", feed.knownPids[old] + " [" + old + "]"); told++ }
      }
    }
    feed.knownPids = pids
  }

  // ------------------------------------------------------------ connections

  Process {
    id: ssProcess
    command: ["ss", "-tunpH", "state", "established"]
    onStarted: feed.noteHelper(processId)
    stdout: StdioCollector {
      waitForEnd: true
      onStreamFinished: feed.readConnections(text)
    }
  }

  function splitAddress(text) {
    var m = /^(.*):(\d+|\*)$/.exec(String(text))
    return m ? { host: m[1].replace(/^\[|\]$/g, "").replace(/%.*$/, ""), port: m[2] } : { host: String(text), port: "" }
  }

  function readConnections(text) {
    var lines = String(text).split("\n")
    var list = []
    var ssh = 0
    var links = {}
    for (var i = 0; i < lines.length && i < 2000; i++) {
      var parts = lines[i].trim().split(/\s+/)
      if (parts.length < 5) continue
      var local = splitAddress(parts[3])
      var peer = splitAddress(parts[4])
      if (local.port === "22" || peer.port === "22") ssh++
      var owner = /users:\(\("([^"]{1,64})"/.exec(parts.slice(5).join(" "))
      var conn = {
        proto: parts[0] === "udp" ? "udp" : "tcp",
        state: "ESTAB",
        local: ":" + local.port,
        peer: Util.maskAddress(peer.host),
        port: peer.port,
        process: owner ? Util.cleanText(owner[1], 24) : ""
      }
      var key = conn.process + "|" + conn.peer + "|" + conn.port
      if (feed.knownLinks && !feed.knownLinks[key] && Object.keys(links).length < 400)
        feed.event("net", (conn.process || "?") + " -> " + conn.peer + ":" + conn.port)
      links[key] = true
      if (list.length < 40) list.push(conn)
    }
    feed.knownLinks = links
    feed.connections = list
    feed.sshSessions = ssh
  }

  // ------------------------------------------------------------ journal

  // Identifiers only: the message text never leaves journalctl.
  Process {
    id: journal
    running: feed.active
    command: ["journalctl", "-f", "-n", "0", "-o", "json", "--output-fields=SYSLOG_IDENTIFIER,_SYSTEMD_UNIT"]
    stdout: SplitParser {
      onRead: function(line) {
        if (line.length > 65536 || feed.journalBudget <= 0) return
        var entry = null
        try { entry = JSON.parse(line) } catch (e) { return }
        var id = entry && (typeof entry.SYSLOG_IDENTIFIER === "string" ? entry.SYSLOG_IDENTIFIER : (typeof entry._SYSTEMD_UNIT === "string" ? entry._SYSTEMD_UNIT : ""))
        id = Util.cleanText(id || "", 40)
        if (!id) return
        feed.journalBudget--
        feed.event("journal", id)
      }
    }
  }

  // Package activity from pacman's log: verb and package name only.
  Process {
    id: pacmanLog
    running: feed.active
    command: ["tail", "-n", "0", "-F", "/var/log/pacman.log"]
    stdout: SplitParser {
      onRead: function(line) {
        if (line.length > 4096) return
        var m = /\[ALPM\] (installed|upgraded|removed|downgraded|reinstalled) ([A-Za-z0-9@._+-]{1,80})/.exec(line)
        if (m) feed.event("package", m[1] + " " + m[2])
      }
    }
  }

  // ------------------------------------------------------------ schedule

  Timer {
    interval: 1000
    repeat: true
    running: feed.active
    triggeredOnStart: true
    onTriggered: {
      feed.readProc()
      feed.journalBudget = 3
    }
  }

  Timer {
    interval: 2000
    repeat: true
    running: feed.active
    triggeredOnStart: true
    onTriggered: if (!psProcess.running) psProcess.running = true
  }

  Timer {
    interval: 3000
    repeat: true
    running: feed.active
    triggeredOnStart: true
    onTriggered: if (!ssProcess.running) ssProcess.running = true
  }

  // A fresh start forgets what it knew, so the first look after a pause
  // does not report every process as new.
  onActiveChanged: {
    if (active) return
    feed.knownPids = null
    feed.knownLinks = null
    feed.lastCpu = null
    feed.lastNet = null
  }
}
