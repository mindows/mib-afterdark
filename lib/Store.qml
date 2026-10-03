import QtQuick
import Quickshell
import Quickshell.Io
import "Util.js" as Util

// Settings and state, in two small JSON files:
//
//   ~/.config/mib-afterdark/settings.json   choices the user makes
//   ~/.local/state/mib-afterdark/state.json  what the screensavers remember
//                                            (Pong's lifetime score, high scores),
//                                            and whether the first-run question
//                                            about Omarchy's screensaver was answered
//
// Omarchy hands a summoned overlay no inline settings, so the plugin keeps
// its own files, the same way MIB Vlog does. Both are validated on read, so
// a hand edit can never put a wrong type into a binding.
Item {
  id: store

  readonly property string home: Quickshell.env("HOME")
  readonly property string configDir: home + "/.config/mib-afterdark"
  readonly property string stateDir: home + "/.local/state/mib-afterdark"
  readonly property string settingsPath: configDir + "/settings.json"
  readonly property string statePath: stateDir + "/state.json"
  readonly property string userModulesDir: configDir + "/screensavers"

  readonly property var defaults: ({
    version: 1,
    enabled: true,
    idleSeconds: 0,
    mode: "random",
    rotateMinutes: 5,
    categories: { omarchy: true, arcade: true, retro: true, system: true, weird: true, calm: true, chaotic: true },
    favoritesOnly: false,
    disabled: [],
    favorites: [],
    liveData: false,
    sameOnAllScreens: true,
    options: {}
  })

  property var settings: normalize({})
  property var state: ({ modules: {}, askedReplace: false })

  readonly property bool ready: settingsResolved && stateResolved && dirsReady
  property bool settingsResolved: false
  property bool stateResolved: false
  property bool dirsReady: false

  // ------------------------------------------------------------ reading

  function normalize(raw) {
    var d = store.defaults
    var s = raw && typeof raw === "object" && !Array.isArray(raw) ? raw : {}
    var out = {}
    out.version = 1
    out.enabled = typeof s.enabled === "boolean" ? s.enabled : d.enabled
    out.idleSeconds = isFinite(s.idleSeconds) ? Util.clamp(Math.floor(s.idleSeconds), 0, 86400) : d.idleSeconds
    out.mode = typeof s.mode === "string" && /^(random|[a-z0-9][a-z0-9-]{0,40})$/.test(s.mode) ? s.mode : d.mode
    out.rotateMinutes = isFinite(s.rotateMinutes) ? Util.clamp(Math.floor(s.rotateMinutes), 1, 240) : d.rotateMinutes
    out.categories = {}
    for (var i = 0; i < Util.categories.length; i++) {
      var id = Util.categories[i].id
      var given = s.categories && typeof s.categories === "object" ? s.categories[id] : undefined
      out.categories[id] = typeof given === "boolean" ? given : d.categories[id]
    }
    out.favoritesOnly = typeof s.favoritesOnly === "boolean" ? s.favoritesOnly : d.favoritesOnly
    out.disabled = idList(s.disabled)
    out.favorites = idList(s.favorites)
    out.liveData = typeof s.liveData === "boolean" ? s.liveData : d.liveData
    out.sameOnAllScreens = typeof s.sameOnAllScreens === "boolean" ? s.sameOnAllScreens : d.sameOnAllScreens
    out.options = {}
    if (s.options && typeof s.options === "object" && !Array.isArray(s.options)) {
      for (var moduleId in s.options) {
        if (!/^[a-z0-9][a-z0-9-]{0,40}$/.test(moduleId)) continue
        var given2 = s.options[moduleId]
        if (!given2 || typeof given2 !== "object" || Array.isArray(given2)) continue
        var clean = {}
        for (var key in given2) {
          var v = given2[key]
          if (!/^[A-Za-z][A-Za-z0-9_]{0,30}$/.test(key)) continue
          if (typeof v === "string" && v.length <= 60) clean[key] = v
          else if (typeof v === "boolean" || (typeof v === "number" && isFinite(v))) clean[key] = v
        }
        out.options[moduleId] = clean
      }
    }
    return out
  }

  function idList(value) {
    var out = []
    if (!Array.isArray(value)) return out
    for (var i = 0; i < value.length && out.length < 200; i++)
      if (typeof value[i] === "string" && /^[a-z0-9][a-z0-9-]{0,40}$/.test(value[i]) && out.indexOf(value[i]) === -1)
        out.push(value[i])
    return out
  }

  function normalizeState(raw) {
    var s = raw && typeof raw === "object" && !Array.isArray(raw) ? raw : {}
    // Earlier builds recorded the switch either way as tookOver: true when
    // they switched Omarchy's off, false when the user switched it back.
    var out = { modules: {}, askedReplace: s.askedReplace === true || typeof s.tookOver === "boolean" }
    if (s.modules && typeof s.modules === "object") {
      for (var id in s.modules) {
        if (!/^[a-z0-9][a-z0-9-]{0,40}$/.test(id)) continue
        var values = s.modules[id]
        if (!values || typeof values !== "object" || Array.isArray(values)) continue
        var clean = {}
        for (var key in values) {
          var v = values[key]
          if (!/^[A-Za-z][A-Za-z0-9_]{0,30}$/.test(key)) continue
          if ((typeof v === "number" && isFinite(v)) || typeof v === "boolean" || (typeof v === "string" && v.length <= 200))
            clean[key] = v
        }
        out.modules[id] = clean
      }
    }
    return out
  }

  // ------------------------------------------------------------ settings

  function save() {
    settingsFile.setText(JSON.stringify(store.settings, null, 2) + "\n")
  }

  function update(mutator) {
    var next = JSON.parse(JSON.stringify(store.settings))
    mutator(next)
    store.settings = normalize(next)
    save()
  }

  function set(key, value) {
    update(function(s) { s[key] = value })
  }

  function setCategory(id, on) {
    update(function(s) { s.categories[id] = !!on })
  }

  function isDisabled(id) { return store.settings.disabled.indexOf(id) !== -1 }
  function isFavorite(id) { return store.settings.favorites.indexOf(id) !== -1 }

  function toggleIn(listKey, id) {
    update(function(s) {
      var at = s[listKey].indexOf(id)
      if (at === -1) s[listKey].push(id)
      else s[listKey].splice(at, 1)
    })
  }

  function toggleDisabled(id) { toggleIn("disabled", id) }
  function toggleFavorite(id) { toggleIn("favorites", id) }

  function setOption(moduleId, key, value) {
    update(function(s) {
      if (!s.options[moduleId]) s.options[moduleId] = {}
      s.options[moduleId][key] = value
    })
  }

  function optionsFor(moduleId) {
    return store.settings.options[moduleId] || {}
  }

  // ------------------------------------------------------------ state

  function moduleValue(moduleId, key) {
    var values = store.state.modules[moduleId]
    return values ? values[key] : undefined
  }

  function setModuleValue(moduleId, key, value) {
    if (!/^[A-Za-z][A-Za-z0-9_]{0,30}$/.test(key)) return
    if (!((typeof value === "number" && isFinite(value)) || typeof value === "boolean" || (typeof value === "string" && value.length <= 200))) return
    if (!store.state.modules[moduleId]) store.state.modules[moduleId] = {}
    store.state.modules[moduleId][key] = value
    // Scores change many times a minute; the file only needs the latest.
    stateSaveTimer.restart()
  }

  function setAskedReplace() {
    store.state.askedReplace = true
    saveState()
  }

  function saveState() {
    stateSaveTimer.stop()
    if (store.stateResolved) stateFile.setText(JSON.stringify(store.state) + "\n")
  }

  Timer {
    id: stateSaveTimer
    interval: 3000
    onTriggered: store.saveState()
  }

  // ------------------------------------------------------------ files

  Process {
    running: true
    command: ["mkdir", "-p", "--", store.configDir, store.stateDir, store.userModulesDir]
    onExited: function(code) { store.dirsReady = code === 0 }
  }

  FileView {
    id: settingsFile
    path: store.settingsPath
    watchChanges: true
    blockWrites: true
    printErrors: false
    onFileChanged: reload()
    onLoaded: {
      var parsed = null
      try { parsed = JSON.parse(text()) } catch (e) { parsed = null }
      store.settings = normalize(parsed)
      store.settingsResolved = true
    }
    // A missing file is the first run: the defaults stand.
    onLoadFailed: store.settingsResolved = true
  }

  FileView {
    id: stateFile
    path: store.statePath
    blockWrites: true
    printErrors: false
    onLoaded: {
      var parsed = null
      try { parsed = JSON.parse(text()) } catch (e) { parsed = null }
      store.state = normalizeState(parsed)
      store.stateResolved = true
    }
    onLoadFailed: store.stateResolved = true
  }

  // Scores reached since the last write are not lost to a shell restart.
  Component.onDestruction: if (stateSaveTimer.running) saveState()
}
