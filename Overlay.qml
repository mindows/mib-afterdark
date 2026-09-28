pragma ComponentBehavior: Bound

import QtQuick
import Quickshell
import Quickshell.Io
import Quickshell.Wayland
import qs.Commons
import "lib"
import "lib/Util.js" as Util

// Omarchy After Dark: the runtime.
//
// It stays loaded (keepLoaded) so its own idle monitor can start a
// screensaver on every screen when the machine goes idle, and so the control
// panel opens instantly when summoned:
//
//   omarchy-shell shell toggle io.github.mindows.mib-afterdark
//
// Omarchy's own idle service still owns locking; After Dark only draws. When
// "Replace Omarchy's screensaver" is on, the built-in terminal screensaver is
// switched off with Omarchy's own toggle so the two never run together.
Item {
  id: root

  // Injected by omarchy-shell.
  property string omarchyPath: Quickshell.env("OMARCHY_PATH")
  property var shell: null
  property var manifest: null

  readonly property string pluginId: (manifest && manifest.id) || "io.github.mindows.mib-afterdark"

  // The control panel.
  property bool opened: false
  property bool reopenAfterPreview: false

  // The screensaver.
  property bool saverActive: false
  property bool previewing: false
  property bool paused: false
  property var screenModules: ({})
  property string lastId: ""
  property real startedAt: 0

  // Identity and theme, for the modules' host object.
  readonly property string userName: Quickshell.env("USER") || ""
  property string hostName: ""
  property real uptime: 0
  readonly property color themeForeground: Color.foreground
  readonly property color themeBackground: Color.background
  readonly property color themeAccent: Color.accent

  readonly property alias store: store
  readonly property alias catalog: catalog
  readonly property alias feed: feed
  readonly property bool liveData: store.settings.liveData

  Store { id: store }

  // The user folder is watched only once it exists; a folder that appears
  // later is never picked up by the watcher.
  Catalog {
    id: catalog
    userDir: store.dirsReady ? store.userModulesDir : ""
  }

  SystemFeed {
    id: feed
    active: root.saverActive && !root.paused && store.settings.liveData && root.anyShownNeedsSystem()
  }

  function anyShownNeedsSystem() {
    for (var name in root.screenModules) {
      var m = catalog.module(root.screenModules[name])
      if (m && m.system) return true
    }
    return false
  }

  // ------------------------------------------------------------ choosing

  // Screensavers Random mode may pick: enabled, in a checked category, and a
  // favorite when "favorites only" is on. Favorites come up three times as often.
  function eligible() {
    var s = store.settings
    var out = []
    for (var i = 0; i < catalog.modules.length; i++) {
      var m = catalog.modules[i]
      if (store.isDisabled(m.id)) continue
      if (s.favoritesOnly && !store.isFavorite(m.id)) continue
      var inCategory = m.categories.length === 0
      for (var c = 0; c < m.categories.length; c++) if (s.categories[m.categories[c]]) inCategory = true
      if (!inCategory) continue
      out.push(m)
    }
    return out
  }

  function pickRandom(avoid) {
    var list = eligible()
    if (!list.length) list = catalog.modules.slice()
    if (!list.length) return ""
    var entries = []
    for (var i = 0; i < list.length; i++) {
      if (list.length > 1 && avoid.indexOf(list[i].id) !== -1) continue
      entries.push({ weight: store.isFavorite(list[i].id) ? 3 : 1, value: list[i].id })
    }
    return Util.weighted(entries) || list[0].id
  }

  function assignModules(forcedId) {
    var next = {}
    var screens = Quickshell.screens
    var fixed = forcedId || (store.settings.mode !== "random" && catalog.module(store.settings.mode) ? store.settings.mode : "")
    var shared = fixed || pickRandom([root.lastId])
    var used = [root.lastId]
    for (var i = 0; i < screens.length; i++) {
      var id = shared
      if (!fixed && !store.settings.sameOnAllScreens && i > 0) id = pickRandom(used)
      used.push(id)
      next[screens[i].name] = id
    }
    root.lastId = shared
    root.screenModules = next
  }

  function moduleFor(screenName) {
    return catalog.module(root.screenModules[screenName] || root.lastId)
  }

  // ------------------------------------------------------------ running

  function begin(forcedId, isPreview) {
    if (!catalog.modules.length) return "no screensavers"
    assignModules(forcedId)
    root.previewing = !!isPreview
    root.paused = false
    root.startedAt = Date.now()
    uptimeFile.reload()
    root.uptime = Number(String(uptimeFile.text()).split(" ")[0]) || 0
    graceTimer.restart()
    root.inputSettled = false
    root.saverActive = true
    return "started " + root.lastId
  }

  function stop() {
    if (!root.saverActive) return "stopped"
    root.saverActive = false
    root.previewing = false
    root.paused = false
    if (root.reopenAfterPreview) {
      root.reopenAfterPreview = false
      root.opened = true
    }
    return "stopped"
  }

  // Any input ends the screensaver, except in the first moments after it
  // starts, so the click or key that launched a preview does not also end it.
  function dismiss() {
    if (graceTimer.running) return
    stop()
  }

  Timer {
    id: graceTimer
    interval: 700
  }

  Timer {
    id: rotation
    interval: store.settings.rotateMinutes * 60000
    repeat: true
    running: root.saverActive && !root.previewing && store.settings.mode === "random"
    onTriggered: root.assignModules("")
  }

  // ------------------------------------------------------------ idle

  // Omarchy's idle.screensaver, followed unless After Dark has its own delay.
  property int omarchyIdleSeconds: 150
  property int omarchyLockSeconds: 300
  readonly property int idleSeconds: store.settings.idleSeconds > 0 ? store.settings.idleSeconds : root.omarchyIdleSeconds

  FileView {
    path: Quickshell.env("HOME") + "/.config/omarchy/shell.json"
    watchChanges: true
    printErrors: false
    onFileChanged: reload()
    onLoaded: {
      var config = null
      try { config = JSON.parse(text()) } catch (e) { config = null }
      var idle = config && config.idle && typeof config.idle === "object" ? config.idle : {}
      var saver = Number(idle.screensaver)
      var lock = Number(idle.lock)
      root.omarchyIdleSeconds = isFinite(saver) && saver > 0 ? Math.floor(saver) : 150
      root.omarchyLockSeconds = isFinite(lock) && lock > 0 ? Math.floor(lock) : 300
    }
  }

  // Omarchy's stay-awake indicator (a file) switches the idle monitor off
  // entirely, as it does for Omarchy's own idle service, so turning it off
  // again starts a fresh idle count instead of leaving a stale "idle".
  readonly property string indicatorsDir: Quickshell.env("HOME") + "/.local/state/omarchy/indicators"
  property bool stayAwake: false
  property bool stayAwakeKnown: false

  Process {
    id: stayAwakeProbe
    command: ["test", "-e", root.indicatorsDir + "/stay-awake"]
    onExited: function(code) {
      root.stayAwake = code === 0
      root.stayAwakeKnown = true
    }
  }

  FileView {
    path: root.indicatorsDir
    watchChanges: true
    printErrors: false
    onFileChanged: if (!stayAwakeProbe.running) stayAwakeProbe.running = true
  }

  IdleMonitor {
    id: idleMonitor
    enabled: store.ready && store.settings.enabled && catalog.modules.length > 0 && root.stayAwakeKnown && !root.stayAwake
    timeout: root.idleSeconds
    respectInhibitors: true
    onIsIdleChanged: {
      if (isIdle) {
        if (!root.saverActive && !idleGate.running) idleGate.running = true
      } else if (root.saverActive && !root.previewing) {
        root.stop()
      }
    }
  }

  // Any input at all ends a running screensaver, however it started. The
  // compositor reports this monitor idle after a second without input; the
  // first input after that is the signal. It catches pointer motion that
  // never reaches our surfaces (touchpads, other seats) as well as keys.
  property bool inputSettled: false

  IdleMonitor {
    id: inputWatch
    enabled: root.saverActive
    timeout: 1
    respectInhibitors: false
    onIsIdleChanged: {
      if (isIdle) root.inputSettled = true
      else if (root.inputSettled) root.dismiss()
    }
  }

  // Before starting on idle: never draw under a lock screen that is
  // already up.
  Process {
    id: idleGate
    command: ["sh", "-c", '[ "$(omarchy-shell lock isLocked 2>/dev/null)" != true ]']
    onExited: function(code) {
      if (code === 0 && idleMonitor.isIdle && !root.saverActive) root.begin("", false)
    }
  }

  // Once the lock screen is up nothing of ours is visible, so the
  // screensavers pause until the session is unlocked.
  Timer {
    interval: 5000
    repeat: true
    running: root.saverActive
    onTriggered: if (!lockProbe.running) lockProbe.running = true
  }

  Process {
    id: lockProbe
    command: ["omarchy-shell", "lock", "isLocked"]
    stdout: StdioCollector {
      waitForEnd: true
      onStreamFinished: root.paused = String(text).trim() === "true"
    }
  }

  FileView { id: uptimeFile; path: "/proc/uptime"; blockAllReads: true; printErrors: false }

  FileView {
    path: "/proc/sys/kernel/hostname"
    printErrors: false
    onLoaded: root.hostName = Util.cleanText(text(), 64)
  }

  // ------------------------------------------------------------ built-in

  // Omarchy's terminal screensaver would start at the same moment; its own
  // "screensaver-off" toggle keeps it out of the way. After Dark switches it
  // off once when first enabled, and back on if "Replace" is turned off.
  property bool builtInOff: false
  readonly property string builtInToggle: Quickshell.env("HOME") + "/.local/state/omarchy/toggles/screensaver-off"

  function refreshBuiltIn() {
    if (!builtInProbe.running) builtInProbe.running = true
  }

  function setBuiltInOff(off) {
    Quickshell.execDetached(["omarchy-toggle", "screensaver-off", off ? "on" : "off"])
    root.builtInOff = off
    refreshTimer.restart()
  }

  function setReplaceBuiltIn(on) {
    store.set("replaceBuiltIn", on)
    setBuiltInOff(on)
    store.setTookOver(on)
  }

  Timer {
    id: refreshTimer
    interval: 500
    onTriggered: root.refreshBuiltIn()
  }

  Process {
    id: builtInProbe
    command: ["test", "-e", root.builtInToggle]
    onExited: function(code) { root.builtInOff = code === 0 }
  }

  Connections {
    target: store
    function onReadyChanged() {
      if (!store.ready) return
      root.refreshBuiltIn()
      if (store.settings.replaceBuiltIn && !store.state.tookOver) {
        root.setBuiltInOff(true)
        store.setTookOver(true)
        Quickshell.execDetached(["omarchy-notification-send", "-g", "󰍹", "After Dark is your screensaver now",
          "Omarchy's built-in screensaver is switched off. Open After Dark from the launcher to change that."])
      }
    }
  }

  // ------------------------------------------------------------ launcher

  // Two launcher entries: the control panel, and "start now". Only files
  // carrying the X-MIB-AfterDark-Managed marker are written or removed.
  readonly property string applications: Quickshell.env("HOME") + "/.local/share/applications"
  readonly property string launcherScript:
      'dir=$1; shift\n'
    + 'mkdir -p "$dir" || exit 0\n'
    + 'while [ $# -ge 2 ]; do\n'
    + '  file="$dir/$1"; body=$2; shift 2\n'
    + '  if [ -e "$file" ] && ! grep -q "^X-MIB-AfterDark-Managed=true$" "$file"; then continue; fi\n'
    + '  tmp=$(mktemp "$dir/.mib-afterdark.XXXXXX") || continue\n'
    + '  printf "%s\\n" "$body" > "$tmp"\n'
    + '  chmod 644 -- "$tmp"\n'
    + '  if cmp -s "$tmp" "$file"; then rm -f -- "$tmp"; continue; fi\n'
    // Replace only our own file; a name that was free is claimed without
    // clobbering anything created there in the meantime.
    + '  if [ -e "$file" ]; then mv -f -- "$tmp" "$file"\n'
    + '  else mv --update=none-fail -- "$tmp" "$file" 2>/dev/null || rm -f -- "$tmp"; fi\n'
    + 'done\n'

  function desktopEntry(name, comment, exec) {
    return "[Desktop Entry]\nType=Application\nName=" + name + "\nComment=" + comment
      + "\nExec=" + exec + "\nIcon=preferences-desktop-screensaver\nTerminal=false\nCategories=Settings;\nX-MIB-AfterDark-Managed=true"
  }

  Component.onCompleted: {
    stayAwakeProbe.running = true
    Quickshell.execDetached(["sh", "-c", root.launcherScript, "sh", root.applications,
      "mib-afterdark.desktop",
      desktopEntry("After Dark", "Choose and configure screensavers", "omarchy-shell shell toggle " + root.pluginId),
      "mib-afterdark-start.desktop",
      desktopEntry("After Dark: Start Screensaver", "Start a screensaver now", "omarchy-shell shell call " + root.pluginId + " start random")])
  }

  // ------------------------------------------------------------ IPC

  // omarchy-shell shell summon/hide/toggle <id>: the control panel.
  function open(payloadJson) {
    var payload = {}
    try { payload = payloadJson ? JSON.parse(payloadJson) || {} : {} } catch (e) { payload = {} }
    if (typeof payload.preview === "string" && catalog.module(payload.preview)) {
      begin(payload.preview, true)
      return
    }
    root.refreshBuiltIn()
    root.opened = true
  }

  function close() {
    root.opened = false
  }

  function dismissPanel() {
    root.close()
    if (root.shell && typeof root.shell.hide === "function") root.shell.hide(root.pluginId)
  }

  // omarchy-shell shell call <id> <method> <arg>
  //   start [random|<module-id>]   start now (a module id previews that one)
  //   stop                         end the screensaver
  //   next                         rotate to another screensaver
  //   status                       JSON summary
  function next() {
    if (!root.saverActive) return "not running"
    assignModules("")
    return "showing " + root.lastId
  }

  function status() {
    return JSON.stringify({
      running: root.saverActive,
      previewing: root.previewing,
      paused: root.paused,
      screens: root.screenModules,
      idleSeconds: root.idleSeconds,
      enabled: store.settings.enabled,
      mode: store.settings.mode,
      modules: catalog.modules.map(function(m) { return m.id }),
      liveData: store.settings.liveData,
      builtInOff: root.builtInOff
    })
  }

  function previewFromPanel(id) {
    root.reopenAfterPreview = true
    root.opened = false
    begin(id, true)
  }

  // IPC: start [random|<module-id>]. A module id is a preview: it keeps
  // running, without rotating, until input ends it.
  function start(arg) {
    var id = typeof arg === "string" && arg !== "random" && arg !== "" && catalog.module(arg) ? arg : ""
    return begin(id, id !== "")
  }

  // ------------------------------------------------------------ windows

  Variants {
    model: Quickshell.screens

    PanelWindow {
      id: saverWindow
      required property var modelData

      screen: modelData
      visible: root.saverActive
      color: "black"
      anchors { top: true; bottom: true; left: true; right: true }
      exclusionMode: ExclusionMode.Ignore
      WlrLayershell.namespace: "mib-afterdark"
      WlrLayershell.layer: WlrLayer.Overlay
      WlrLayershell.keyboardFocus: root.saverActive ? WlrKeyboardFocus.Exclusive : WlrKeyboardFocus.None

      SaverHost {
        anchors.fill: parent
        module: root.saverActive ? root.moduleFor(saverWindow.modelData.name) : null
        runtime: root
        running: root.saverActive && !root.paused
      }

      // Input: the pointer is hidden, and a real move, a click, a scroll or
      // a key ends the screensaver.
      MouseArea {
        id: pointer
        anchors.fill: parent
        hoverEnabled: true
        cursorShape: Qt.BlankCursor
        acceptedButtons: Qt.AllButtons
        property point origin: Qt.point(-1, -1)
        onPositionChanged: function(mouse) {
          if (origin.x < 0) { origin = Qt.point(mouse.x, mouse.y); return }
          if (Math.abs(mouse.x - origin.x) + Math.abs(mouse.y - origin.y) > 12) root.dismiss()
        }
        onPressed: root.dismiss()
        onWheel: root.dismiss()
      }

      Item {
        id: keys
        anchors.fill: parent
        focus: true
        Keys.onPressed: function(event) {
          event.accepted = true
          root.dismiss()
        }
      }

      // Each run measures pointer movement from where the pointer is when
      // it starts, not from where the last run left it.
      onVisibleChanged: {
        pointer.origin = Qt.point(-1, -1)
        if (visible) keys.forceActiveFocus()
      }
    }
  }

  ControlPanel {
    runtime: root
    shown: root.opened
    onCloseRequested: root.dismissPanel()
  }
}
