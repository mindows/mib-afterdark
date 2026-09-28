import QtQuick
import "../../lib"

// Plasma: the demo-scene classic, computed per pixel on the GPU (plasma.frag),
// with a sine scroller sending greetings along the bottom.
Item {
  id: root

  property var host: null
  property bool running: true

  readonly property string paletteName: host ? host.option("palette", "demo") : "demo"
  readonly property bool scroller: host ? host.option("scroller", true) === true : true

  // Cosine palettes: color = a + b * cos(2pi * (c * t + d)).
  readonly property var palettes: ({
    demo:  [[0.5, 0.5, 0.5], [0.5, 0.5, 0.5], [1.0, 1.0, 1.0], [0.00, 0.33, 0.67]],
    fire:  [[0.5, 0.25, 0.08], [0.5, 0.3, 0.1], [1.0, 1.0, 1.0], [0.00, 0.10, 0.20]],
    ocean: [[0.1, 0.35, 0.5], [0.1, 0.3, 0.4], [1.0, 1.0, 1.0], [0.25, 0.35, 0.45]],
    acid:  [[0.5, 0.5, 0.5], [0.5, 0.5, 0.5], [2.0, 1.0, 0.0], [0.50, 0.20, 0.25]]
  })

  function vec(list) { return Qt.vector4d(list[0], list[1], list[2], 0) }

  // The theme palette swings between the Omarchy background and accent,
  // with the foreground at the crest.
  readonly property var themed: {
    var bg = host ? host.background : Qt.rgba(0, 0, 0, 1)
    var ac = host ? host.accent : Qt.rgba(0.5, 0.6, 1, 1)
    var fg = host ? host.foreground : Qt.rgba(1, 1, 1, 1)
    var mid = [(bg.r + ac.r) / 2, (bg.g + ac.g) / 2, (bg.b + ac.b) / 2]
    var amp = [(ac.r - bg.r) / 2 + (fg.r - ac.r) * 0.2, (ac.g - bg.g) / 2 + (fg.g - ac.g) * 0.2, (ac.b - bg.b) / 2 + (fg.b - ac.b) * 0.2]
    return [mid, amp, [1, 1, 1], [0, 0.05, 0.1]]
  }

  readonly property var palette: paletteName === "theme" ? themed : (palettes[paletteName] || palettes.demo)

  // Half resolution, scaled up: plasma is soft anyway, and it quarters the
  // work for integrated graphics.
  ShaderEffect {
    id: plasma
    width: Math.ceil(root.width / 2)
    height: Math.ceil(root.height / 2)
    scale: 2
    transformOrigin: Item.TopLeft
    smooth: true
    property real time: 0
    property real scanlines: 1
    property vector2d resolution: Qt.vector2d(width, height)
    property vector4d pa: root.vec(root.palette[0])
    property vector4d pb: root.vec(root.palette[1])
    property vector4d pc: root.vec(root.palette[2])
    property vector4d pd: root.vec(root.palette[3])
    fragmentShader: Qt.resolvedUrl("plasma.frag.qsb")
  }

  // ------------------------------------------------------------- scroller

  readonly property string message: "      GREETINGS TO EVERY OMARCHY USER ... OMARCHY AFTER DARK ... "
    + "CODE BY MIB ... NO TOASTERS WERE HARMED ... ALL QUATTROS ARE FLYING ... "
    + "HELLO TO THE ARCH CREW, THE HYPRLAND CREW AND EVERYONE STILL AT THE KEYBOARD AT THIS HOUR ... "
    + "PRESS ANY KEY TO RETURN TO REALITY ...      "
  readonly property real glyphPixel: Math.max(3, height / 140)
  readonly property real advance: glyphPixel * 4
  property real scroll: 0

  Item {
    id: scrollerLayer
    anchors.fill: parent
    visible: root.scroller

    // A fixed row of glyph slots slides left and hands each slot the next
    // character as it wraps, so only the slots on screen do any work.
    Repeater {
      id: letters
      model: root.scroller ? Math.ceil(root.width / root.advance) + 2 : 0
      PixelText {
        required property int index
        readonly property int first: Math.floor(root.scroll / root.advance)
        x: index * root.advance - (root.scroll - first * root.advance) - root.advance
        y: root.height * 0.8 + Math.sin(x / root.width * 9 + plasma.time * 3) * root.height * 0.05
        text: root.message.charAt((first + index) % root.message.length)
        pixel: root.glyphPixel
        color: "white"
        // A drop shadow, as every scroller had.
        PixelText {
          x: parent.pixel * 0.6
          y: parent.pixel * 0.6
          z: -1
          text: parent.text
          pixel: parent.pixel
          color: Qt.rgba(0, 0, 0, 0.55)
        }
      }
    }
  }

  FrameAnimation {
    running: root.running && root.visible
    onTriggered: {
      var dt = Math.min(frameTime, 0.05)
      plasma.time += dt
      root.scroll += dt * root.height * 0.18
    }
  }
}
