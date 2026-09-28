import QtQuick

// The object every screensaver receives as `host`. It is the whole contract
// between a module and After Dark (see docs/MODULES.md), so community modules
// never have to reach into the runtime.
QtObject {
  id: host

  // The module's id from its module.json.
  property string moduleId: ""
  // module.json option defaults, overlaid with the user's choices.
  property var options: ({})
  // Live telemetry (lib/SystemFeed.qml), or null when live system data is
  // off or the module did not ask for it. Modules must work without it.
  property var system: null
  // True in the control panel's small preview: skip anything expensive and
  // do not write persistent state.
  property bool preview: false
  // Seconds this screensaver has been on screen. Arcade modes use it to
  // escalate; "increasingly ridiculous traffic" is measured against it.
  property real elapsed: 0
  // Seconds since boot, for the events that only very long uptimes unlock.
  property real uptime: 0
  property string userName: ""
  property string hostName: ""

  // The Omarchy theme, for modules that want to match it.
  property color foreground: "#e6e6e6"
  property color background: "#000000"
  property color accent: "#7aa2f7"

  // Runtime storage, reached only through get() and set().
  property var store: null

  function option(key, fallback) {
    var value = host.options ? host.options[key] : undefined
    return value === undefined || value === null ? fallback : value
  }

  // Per-module persistent values (Pong's lifetime score, a high score).
  // They live in ~/.local/state/mib-afterdark/state.json.
  function get(key, fallback) {
    if (!host.store || typeof host.store.moduleValue !== "function") return fallback
    var value = host.store.moduleValue(host.moduleId, String(key))
    return value === undefined ? fallback : value
  }

  function set(key, value) {
    if (host.preview || !host.store || typeof host.store.setModuleValue !== "function") return
    host.store.setModuleValue(host.moduleId, String(key), value)
  }

  // true once in `oneIn` calls, on average.
  function rare(oneIn) {
    return Math.random() * Math.max(1, oneIn) < 1
  }

  function random(lo, hi) {
    return lo + Math.random() * (hi - lo)
  }

  function randomInt(lo, hi) {
    return Math.floor(lo + Math.random() * (hi - lo + 1))
  }

  function pick(list) {
    return list && list.length ? list[Math.floor(Math.random() * list.length)] : undefined
  }
}
