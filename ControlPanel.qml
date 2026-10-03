pragma ComponentBehavior: Bound

import QtQuick
import Quickshell
import Quickshell.Hyprland
import Quickshell.Wayland
import qs.Commons
import "lib"
import "lib/Util.js" as Util

// The After Dark control panel: pick screensavers, preview them live, set
// their options, and choose how Random mode rotates.
//
// Keys: Up/Down select, Space enables or disables, F favorites, Enter
// previews fullscreen, Esc closes.
PanelWindow {
  id: panel

  property var runtime: null
  property bool shown: false
  signal closeRequested()

  readonly property var store: runtime ? runtime.store : null
  readonly property var catalog: runtime ? runtime.catalog : null
  readonly property var settings: store ? store.settings : ({})
  readonly property var modules: catalog ? catalog.modules : []
  readonly property bool askingReplace: !!runtime && runtime.askingReplace
  property int selectedIndex: 0
  readonly property var selected: modules.length ? modules[Math.min(selectedIndex, modules.length - 1)] : null

  readonly property color fg: Color.foreground
  readonly property color bg: Color.background
  readonly property color accent: Color.accent
  readonly property color muted: Color.muted
  readonly property string fontFamily: Style.font.family

  // Designed at 1320 x 900 and scaled down to fit smaller screens.
  readonly property real designW: 1320
  readonly property real designH: 900
  readonly property real fit: Math.min(1, (width - 48) / designW, (height - 48) / designH)

  screen: {
    var focused = Hyprland.focusedMonitor
    var screens = Quickshell.screens
    for (var i = 0; i < screens.length; i++) if (focused && screens[i].name === focused.name) return screens[i]
    return screens.length ? screens[0] : null
  }
  visible: shown
  color: "transparent"
  anchors { top: true; bottom: true; left: true; right: true }
  exclusionMode: ExclusionMode.Ignore
  WlrLayershell.namespace: "mib-afterdark-panel"
  WlrLayershell.layer: WlrLayer.Overlay
  WlrLayershell.keyboardFocus: shown ? WlrKeyboardFocus.Exclusive : WlrKeyboardFocus.None

  onShownChanged: if (shown) Qt.callLater(function() { keyCatcher.forceActiveFocus() })

  function idleLabel(seconds) {
    if (seconds % 60 === 0) return (seconds / 60) + " min"
    return seconds + " s"
  }

  function move(delta) {
    if (!modules.length) return
    selectedIndex = (selectedIndex + delta + modules.length) % modules.length
  }

  // ------------------------------------------------------------ pieces

  component Label: Text {
    textFormat: Text.PlainText
    font.family: panel.fontFamily
    font.pixelSize: 14
    color: panel.fg
    elide: Text.ElideRight
  }

  component Heading: Label {
    font.pixelSize: 12
    font.bold: true
    font.letterSpacing: 1.5
    color: panel.muted
  }

  component Toggle: Item {
    id: toggle
    property bool checked: false
    property string text: ""
    signal toggled()
    implicitWidth: row.implicitWidth
    implicitHeight: 28
    Row {
      id: row
      spacing: 10
      anchors.verticalCenter: parent.verticalCenter
      Rectangle {
        width: 40
        height: 22
        radius: 11
        color: toggle.checked ? panel.accent : Qt.rgba(panel.fg.r, panel.fg.g, panel.fg.b, 0.15)
        Rectangle {
          width: 16
          height: 16
          radius: 8
          y: 3
          x: toggle.checked ? parent.width - width - 3 : 3
          color: toggle.checked ? panel.bg : panel.fg
          Behavior on x { NumberAnimation { duration: 120 } }
        }
      }
      Label { text: toggle.text; anchors.verticalCenter: parent.verticalCenter; visible: text !== "" }
    }
    MouseArea {
      anchors.fill: parent
      cursorShape: Qt.PointingHandCursor
      onClicked: toggle.toggled()
    }
  }

  component Chip: Rectangle {
    id: chip
    property string text: ""
    property bool selected: false
    signal clicked()
    implicitWidth: chipLabel.implicitWidth + 22
    implicitHeight: 28
    radius: 14
    color: selected ? panel.accent : (chipMouse.containsMouse ? Qt.rgba(panel.fg.r, panel.fg.g, panel.fg.b, 0.12) : "transparent")
    border.width: 1
    border.color: selected ? panel.accent : Qt.rgba(panel.fg.r, panel.fg.g, panel.fg.b, 0.25)
    Label {
      id: chipLabel
      anchors.centerIn: parent
      text: chip.text
      font.pixelSize: 13
      color: chip.selected ? panel.bg : panel.fg
    }
    MouseArea {
      id: chipMouse
      anchors.fill: parent
      hoverEnabled: true
      cursorShape: Qt.PointingHandCursor
      onClicked: chip.clicked()
    }
  }

  component Button: Rectangle {
    id: button
    property string text: ""
    property bool primary: false
    signal clicked()
    implicitWidth: buttonLabel.implicitWidth + 32
    implicitHeight: 36
    radius: 6
    color: primary ? panel.accent : (buttonMouse.containsMouse ? Qt.rgba(panel.fg.r, panel.fg.g, panel.fg.b, 0.14) : Qt.rgba(panel.fg.r, panel.fg.g, panel.fg.b, 0.07))
    border.width: primary ? 0 : 1
    border.color: Qt.rgba(panel.fg.r, panel.fg.g, panel.fg.b, 0.25)
    Label {
      id: buttonLabel
      anchors.centerIn: parent
      text: button.text
      font.bold: button.primary
      color: button.primary ? panel.bg : panel.fg
    }
    MouseArea {
      id: buttonMouse
      anchors.fill: parent
      hoverEnabled: true
      cursorShape: Qt.PointingHandCursor
      onClicked: button.clicked()
    }
  }

  // ------------------------------------------------------------ scrim

  Rectangle {
    anchors.fill: parent
    color: Qt.rgba(0, 0, 0, 0.6)
    MouseArea {
      anchors.fill: parent
      onClicked: panel.closeRequested()
    }
  }

  Item {
    id: keyCatcher
    anchors.fill: parent
    focus: true
    Keys.onPressed: function(event) {
      var m = panel.selected
      if (panel.askingReplace) {
        if (event.key === Qt.Key_Escape) panel.closeRequested()
        else if (event.key === Qt.Key_Return || event.key === Qt.Key_Enter) panel.runtime.answerReplace(true)
        event.accepted = true
        return
      }
      if (event.key === Qt.Key_Escape) panel.closeRequested()
      else if (event.key === Qt.Key_Down || event.key === Qt.Key_J) panel.move(1)
      else if (event.key === Qt.Key_Up || event.key === Qt.Key_K) panel.move(-1)
      else if (event.key === Qt.Key_Space && m) panel.store.toggleDisabled(m.id)
      else if (event.key === Qt.Key_F && m) panel.store.toggleFavorite(m.id)
      else if ((event.key === Qt.Key_Return || event.key === Qt.Key_Enter) && m) panel.runtime.previewFromPanel(m.id)
      else return
      event.accepted = true
    }
  }

  // ------------------------------------------------------------ card

  Rectangle {
    id: card
    width: panel.designW
    height: panel.designH
    anchors.centerIn: parent
    scale: panel.fit
    radius: Math.max(0, Style.cornerRadius)
    color: panel.bg
    border.width: 1
    border.color: Qt.rgba(panel.accent.r, panel.accent.g, panel.accent.b, 0.6)

    // Swallow clicks, so only the scrim closes the panel.
    MouseArea { anchors.fill: parent }

    // Header.
    Item {
      id: header
      anchors { left: parent.left; right: parent.right; top: parent.top; margins: 28 }
      height: 48

      Row {
        anchors.verticalCenter: parent.verticalCenter
        spacing: 18
        PixelText {
          anchors.verticalCenter: parent.verticalCenter
          text: "AFTER DARK"
          color: panel.accent
          pixel: 6
        }
        Label {
          anchors.verticalCenter: parent.verticalCenter
          text: "screensavers for Omarchy"
          color: panel.muted
        }
      }

      Row {
        anchors { right: parent.right; verticalCenter: parent.verticalCenter }
        spacing: 16
        Label {
          anchors.verticalCenter: parent.verticalCenter
          text: panel.runtime ? "after " + panel.idleLabel(panel.runtime.idleSeconds) + " idle" : ""
          color: panel.muted
        }
        Toggle {
          anchors.verticalCenter: parent.verticalCenter
          text: "Start when idle"
          checked: panel.settings.enabled === true
          onToggled: panel.store.set("enabled", !checked)
        }
      }
    }

    // Left column: the screensavers, then how Random mode rotates.
    Column {
      id: left
      anchors { left: parent.left; top: header.bottom; leftMargin: 28; topMargin: 22 }
      width: 470
      spacing: 6

      Heading { text: "SCREENSAVERS" }

      Repeater {
        model: panel.modules
        Rectangle {
          id: moduleRow
          required property var modelData
          required property int index
          readonly property bool isSelected: index === panel.selectedIndex
          readonly property bool isEnabled: panel.settings.disabled ? panel.settings.disabled.indexOf(modelData.id) === -1 : true
          readonly property bool isFavorite: panel.settings.favorites ? panel.settings.favorites.indexOf(modelData.id) !== -1 : false
          width: left.width
          height: 38
          radius: 6
          color: isSelected ? Qt.rgba(panel.accent.r, panel.accent.g, panel.accent.b, 0.18)
            : (rowMouse.containsMouse ? Qt.rgba(panel.fg.r, panel.fg.g, panel.fg.b, 0.06) : "transparent")

          MouseArea {
            id: rowMouse
            anchors.fill: parent
            hoverEnabled: true
            onClicked: panel.selectedIndex = moduleRow.index
            onDoubleClicked: panel.runtime.previewFromPanel(moduleRow.modelData.id)
          }

          Rectangle {
            id: check
            anchors { left: parent.left; leftMargin: 10; verticalCenter: parent.verticalCenter }
            width: 18
            height: 18
            radius: 4
            color: moduleRow.isEnabled ? panel.accent : "transparent"
            border.width: 1
            border.color: moduleRow.isEnabled ? panel.accent : Qt.rgba(panel.fg.r, panel.fg.g, panel.fg.b, 0.4)
            Label {
              anchors.centerIn: parent
              text: "✓"
              visible: moduleRow.isEnabled
              color: panel.bg
              font.pixelSize: 13
              font.bold: true
            }
            MouseArea {
              anchors.fill: parent
              anchors.margins: -6
              cursorShape: Qt.PointingHandCursor
              onClicked: panel.store.toggleDisabled(moduleRow.modelData.id)
            }
          }

          Label {
            anchors { left: check.right; leftMargin: 12; verticalCenter: parent.verticalCenter }
            width: 170
            text: moduleRow.modelData.name
            opacity: moduleRow.isEnabled ? 1 : 0.5
            font.bold: moduleRow.isSelected
          }

          Label {
            anchors { right: star.left; rightMargin: 10; verticalCenter: parent.verticalCenter }
            width: 190
            horizontalAlignment: Text.AlignRight
            text: moduleRow.modelData.categories.join(" · ")
            color: panel.muted
            font.pixelSize: 11
          }

          Label {
            id: star
            anchors { right: parent.right; rightMargin: 12; verticalCenter: parent.verticalCenter }
            text: moduleRow.isFavorite ? "★" : "☆"
            color: moduleRow.isFavorite ? panel.accent : panel.muted
            font.pixelSize: 18
            MouseArea {
              anchors.fill: parent
              anchors.margins: -6
              cursorShape: Qt.PointingHandCursor
              onClicked: panel.store.toggleFavorite(moduleRow.modelData.id)
            }
          }
        }
      }

      Item { width: 1; height: 12 }
      Heading { text: "RANDOM ROTATION" }

      Flow {
        width: left.width
        spacing: 8
        Repeater {
          model: Util.categories
          Chip {
            required property var modelData
            text: modelData.label
            selected: panel.settings.categories ? panel.settings.categories[modelData.id] === true : false
            onClicked: panel.store.setCategory(modelData.id, !selected)
          }
        }
      }

      Item { width: 1; height: 4 }
      Row {
        spacing: 8
        Label { text: "Change every"; anchors.verticalCenter: parent.verticalCenter; width: 104 }
        Repeater {
          model: [1, 2, 5, 10, 30]
          Chip {
            required property int modelData
            text: modelData + " min"
            selected: panel.settings.rotateMinutes === modelData
            onClicked: panel.store.set("rotateMinutes", modelData)
          }
        }
      }

      Item { width: 1; height: 4 }
      Row {
        spacing: 24
        Toggle {
          text: "Favorites only"
          checked: panel.settings.favoritesOnly === true
          onToggled: panel.store.set("favoritesOnly", !checked)
        }
        Toggle {
          text: "Different on each screen"
          checked: panel.settings.sameOnAllScreens === false
          onToggled: panel.store.set("sameOnAllScreens", checked)
        }
      }
    }

    // Right column: live preview, description, options.
    Column {
      id: right
      anchors { left: left.right; right: parent.right; top: header.bottom; leftMargin: 32; rightMargin: 28; topMargin: 22 }
      spacing: 12

      Rectangle {
        width: Math.min(right.width, 640)
        height: Math.round(width * 9 / 16)
        color: "black"
        radius: 6
        clip: true

        SaverHost {
          anchors.fill: parent
          module: panel.shown ? panel.selected : null
          runtime: panel.runtime
          preview: true
          running: panel.shown
        }

        MouseArea {
          anchors.fill: parent
          cursorShape: Qt.PointingHandCursor
          onClicked: if (panel.selected) panel.runtime.previewFromPanel(panel.selected.id)
        }
      }

      Row {
        width: right.width
        spacing: 12
        Label {
          id: nameLabel
          anchors.verticalCenter: parent.verticalCenter
          text: panel.selected ? panel.selected.name : ""
          font.pixelSize: 20
          font.bold: true
          elide: Text.ElideNone
        }
        Label {
          anchors.verticalCenter: parent.verticalCenter
          visible: panel.selected && !panel.selected.bundled
          text: "community module"
          color: panel.muted
          font.pixelSize: 12
        }
        Label {
          anchors.verticalCenter: parent.verticalCenter
          visible: !!panel.selected && panel.selected.system
          text: panel.settings.liveData ? "live system data" : "simulated system data"
          color: panel.muted
          font.pixelSize: 12
        }
      }

      Label {
        width: right.width
        text: panel.selected ? panel.selected.description : ""
        color: panel.muted
        wrapMode: Text.WordWrap
        maximumLineCount: 3
      }

      Repeater {
        model: panel.selected ? panel.selected.options : []
        Row {
          id: optionRow
          required property var modelData
          readonly property var current: {
            var chosen = panel.store && panel.selected ? panel.store.optionsFor(panel.selected.id)[modelData.key] : undefined
            if (modelData.type === "enum") return modelData.options.indexOf(chosen) !== -1 ? chosen : modelData["default"]
            return typeof chosen === "boolean" ? chosen : modelData["default"]
          }
          spacing: 8
          Label { text: optionRow.modelData.label; width: 120; anchors.verticalCenter: parent.verticalCenter; color: panel.muted }
          Repeater {
            model: optionRow.modelData.type === "enum" ? optionRow.modelData.options : []
            Chip {
              required property string modelData
              text: modelData
              selected: optionRow.current === modelData
              onClicked: panel.store.setOption(panel.selected.id, optionRow.modelData.key, modelData)
            }
          }
          Toggle {
            visible: optionRow.modelData.type === "boolean"
            checked: optionRow.current === true
            onToggled: panel.store.setOption(panel.selected.id, optionRow.modelData.key, !checked)
          }
        }
      }

      Row {
        spacing: 10
        Button {
          text: "Preview fullscreen"
          primary: true
          onClicked: if (panel.selected) panel.runtime.previewFromPanel(panel.selected.id)
        }
        Button {
          visible: !!panel.selected && panel.settings.mode !== panel.selected.id
          text: "Always use this one"
          onClicked: panel.store.set("mode", panel.selected.id)
        }
        Button {
          visible: panel.settings.mode !== "random"
          text: "Back to random"
          onClicked: panel.store.set("mode", "random")
        }
        Label {
          anchors.verticalCenter: parent.verticalCenter
          text: panel.settings.mode === "random" ? "Random rotation" : "Always: " + (panel.catalog && panel.catalog.module(panel.settings.mode) ? panel.catalog.module(panel.settings.mode).name : panel.settings.mode)
          color: panel.muted
        }
      }
    }

    // Footer: the system-wide switches.
    Rectangle {
      id: footer
      anchors { left: parent.left; right: parent.right; bottom: parent.bottom; margins: 1 }
      height: 96
      radius: card.radius
      color: Qt.rgba(panel.fg.r, panel.fg.g, panel.fg.b, 0.04)

      Column {
        anchors { left: parent.left; right: parent.right; verticalCenter: parent.verticalCenter; leftMargin: 28; rightMargin: 28 }
        spacing: 12

        Row {
          spacing: 8
          Label { text: "Start after"; width: 104; anchors.verticalCenter: parent.verticalCenter }
          Chip {
            text: "Omarchy (" + (panel.runtime ? panel.idleLabel(panel.runtime.omarchyIdleSeconds) : "") + ")"
            selected: panel.settings.idleSeconds === 0
            onClicked: panel.store.set("idleSeconds", 0)
          }
          Repeater {
            model: [60, 120, 300, 600, 1200, 1800]
            Chip {
              required property int modelData
              text: panel.idleLabel(modelData)
              selected: panel.settings.idleSeconds === modelData
              onClicked: panel.store.set("idleSeconds", modelData)
            }
          }
        }

        Row {
          spacing: 32
          Toggle {
            text: "Live system data"
            checked: panel.settings.liveData === true
            onToggled: panel.store.set("liveData", !checked)
          }
          Label {
            anchors.verticalCenter: parent.verticalCenter
            text: "process names, CPU, connection counts; addresses masked"
            color: panel.muted
            font.pixelSize: 12
          }
          Toggle {
            text: "Replace Omarchy's screensaver"
            checked: panel.settings.replaceBuiltIn === true
            onToggled: panel.runtime.setReplaceBuiltIn(!checked)
          }
          Label {
            anchors.verticalCenter: parent.verticalCenter
            visible: panel.runtime && !panel.runtime.builtInOff
            text: "both will run"
            color: Color.urgent
            font.pixelSize: 12
          }
        }
      }
    }

    // First run: ask before touching Omarchy's own screensaver.
    Rectangle {
      anchors.fill: parent
      visible: panel.askingReplace
      radius: card.radius
      color: Qt.rgba(panel.bg.r, panel.bg.g, panel.bg.b, 0.94)

      MouseArea { anchors.fill: parent }

      Column {
        anchors.centerIn: parent
        width: 600
        spacing: 22

        PixelText {
          anchors.horizontalCenter: parent.horizontalCenter
          text: "AFTER DARK"
          color: panel.accent
          pixel: 6
        }
        Label {
          width: parent.width
          horizontalAlignment: Text.AlignHCenter
          text: "Make After Dark your screensaver?"
          font.pixelSize: 20
          font.bold: true
        }
        Label {
          width: parent.width
          horizontalAlignment: Text.AlignHCenter
          wrapMode: Text.WordWrap
          elide: Text.ElideNone
          color: panel.muted
          text: "Omarchy's own screensaver is on, so both would start when the machine goes idle. "
            + "After Dark can switch Omarchy's off with Omarchy's own toggle. "
            + "You can change this any time with Replace Omarchy's screensaver at the bottom of this panel."
        }
        Row {
          anchors.horizontalCenter: parent.horizontalCenter
          spacing: 10
          Button {
            text: "Replace Omarchy's screensaver"
            primary: true
            onClicked: panel.runtime.answerReplace(true)
          }
          Button {
            text: "Not now"
            onClicked: panel.runtime.answerReplace(false)
          }
        }
      }
    }
  }
}
