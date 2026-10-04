import QtQuick
import Qt.labs.folderlistmodel
import Quickshell.Io
import "Util.js" as Util

// Finds screensaver modules: the ones bundled in screensavers/, and any the
// user has added under ~/.config/mib-afterdark/screensavers/. Each module is a
// folder holding a module.json and a QML entry point (docs/MODULES.md).
//
// Everything read from a module.json is checked before it is used: ids and
// option keys against strict patterns, text cleaned and capped, the entry
// point limited to a plain .qml file name inside the module's own folder.
Item {
  id: catalog

  property string userDir: ""
  readonly property string bundledDir: decodeURIComponent(String(Qt.resolvedUrl("../screensavers")).replace(/^file:\/\//, ""))

  // A local path as a file URL, each segment encoded, so a home folder with
  // a space, "#" or "?" in it still resolves.
  function fileUrl(path) {
    return "file://" + String(path).split("/").map(encodeURIComponent).join("/")
  }

  // The order the control panel lists the bundled modules in.
  readonly property var bundledOrder: ["flying-quattros", "matrix-operator", "invaders", "pong", "asteroids", "moon-patrol", "captain-omarchy", "pipes", "starfield", "plasma", "aquarium"]

  property var byId: ({})
  readonly property var modules: {
    var list = []
    for (var id in catalog.byId) list.push(catalog.byId[id])
    list.sort(function(a, b) {
      var ia = catalog.bundledOrder.indexOf(a.id), ib = catalog.bundledOrder.indexOf(b.id)
      if (ia !== -1 || ib !== -1) return (ia === -1 ? 999 : ia) - (ib === -1 ? 999 : ib)
      return a.name.localeCompare(b.name)
    })
    return list
  }
  readonly property bool ready: bundledModel.status === FolderListModel.Ready

  function module(id) {
    return catalog.byId[id] || null
  }

  function validOption(o) {
    if (!o || typeof o !== "object") return null
    if (typeof o.key !== "string" || !/^[A-Za-z][A-Za-z0-9_]{0,30}$/.test(o.key)) return null
    var out = { key: o.key, label: Util.cleanText(typeof o.label === "string" ? o.label : o.key, 40) || o.key }
    if (o.type === "enum") {
      if (!Array.isArray(o.options)) return null
      out.type = "enum"
      out.options = []
      for (var i = 0; i < o.options.length && out.options.length < 12; i++)
        if (typeof o.options[i] === "string" && /^[A-Za-z0-9][A-Za-z0-9 _.-]{0,29}$/.test(o.options[i])) out.options.push(o.options[i])
      if (!out.options.length) return null
      out["default"] = out.options.indexOf(o["default"]) !== -1 ? o["default"] : out.options[0]
    } else if (o.type === "boolean") {
      out.type = "boolean"
      out["default"] = o["default"] === true
    } else {
      return null
    }
    return out
  }

  function register(folder, raw, bundled) {
    var meta = null
    try { meta = JSON.parse(raw) } catch (e) { meta = null }
    if (!meta || typeof meta !== "object") {
      console.warn("mib-afterdark: unreadable module.json in " + folder)
      return
    }
    var name = folder.replace(/\/+$/, "").split("/").pop()
    if (typeof meta.id !== "string" || meta.id !== name || !/^[a-z0-9][a-z0-9-]{0,40}$/.test(meta.id)) {
      console.warn("mib-afterdark: module id must match its folder name: " + folder)
      return
    }
    // A bundled module keeps its id; a user module cannot replace it.
    if (catalog.byId[meta.id] && catalog.byId[meta.id].bundled && !bundled) {
      console.warn("mib-afterdark: skipping user module that reuses bundled id " + meta.id)
      return
    }
    var entry = typeof meta.entry === "string" && /^[A-Za-z0-9_-]{1,60}\.qml$/.test(meta.entry) ? meta.entry : "Saver.qml"
    var categories = []
    if (Array.isArray(meta.categories))
      for (var i = 0; i < meta.categories.length; i++)
        if (Util.isCategory(meta.categories[i]) && categories.indexOf(meta.categories[i]) === -1) categories.push(meta.categories[i])
    var options = []
    if (Array.isArray(meta.options))
      for (var j = 0; j < meta.options.length && options.length < 8; j++) {
        var o = validOption(meta.options[j])
        if (o) options.push(o)
      }
    var next = {}
    for (var k in catalog.byId) next[k] = catalog.byId[k]
    next[meta.id] = {
      id: meta.id,
      name: Util.cleanText(typeof meta.name === "string" ? meta.name : meta.id, 40) || meta.id,
      description: Util.cleanText(typeof meta.description === "string" ? meta.description : "", 400),
      categories: categories,
      options: options,
      system: meta.system === true,
      bundled: bundled,
      url: fileUrl(folder.replace(/\/+$/, "") + "/" + entry)
    }
    catalog.byId = next
  }

  function unregisterMissing(model, bundled) {
    var present = {}
    for (var i = 0; i < model.count; i++) present[model.get(i, "fileName")] = true
    var next = {}
    var changed = false
    for (var id in catalog.byId) {
      var m = catalog.byId[id]
      if (m.bundled === bundled && !present[id]) { changed = true; continue }
      next[id] = m
    }
    if (changed) catalog.byId = next
  }

  FolderListModel {
    id: bundledModel
    folder: catalog.fileUrl(catalog.bundledDir)
    showFiles: false
    showDirs: true
    showDotAndDotDot: false
  }

  FolderListModel {
    id: userModel
    folder: catalog.userDir ? catalog.fileUrl(catalog.userDir) : ""
    showFiles: false
    showDirs: true
    showDotAndDotDot: false
    onCountChanged: catalog.unregisterMissing(userModel, false)
  }

  component ModuleReader: FileView {
    required property string filePath
    required property bool bundledModule
    path: filePath + "/module.json"
    printErrors: false
    watchChanges: !bundledModule
    onFileChanged: reload()
    onLoaded: catalog.register(filePath, text(), bundledModule)
  }

  Instantiator {
    model: bundledModel
    delegate: ModuleReader { bundledModule: true }
  }

  Instantiator {
    model: userModel
    delegate: ModuleReader { bundledModule: false }
  }
}
