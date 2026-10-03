import QtQuick
import "../../lib"
import "../../lib/Util.js" as Util

// Starfield: flight through an endless field of stars, drawn on the GPU
// (starfield.frag). Cruise is the faithful minimal version; hyperspace is
// not. Every few minutes the ship jumps to warp on its own, and very
// occasionally something else is out there.
Item {
  id: root

  property var host: null
  property bool running: true

  readonly property string speedOption: host ? host.option("speed", "cruise") : "cruise"
  readonly property string density: host ? host.option("density", "normal") : "normal"
  readonly property bool preview: host ? host.preview : false

  readonly property real baseSpeed: speedOption === "hyperspace" ? 2.4 : (speedOption === "warp" ? 1.0 : 0.25)

  property real speed: baseSpeed
  // Surges: a warp jump ramps speed up and back down over a few seconds.
  property real surge: 0
  property real surgeClock: 90
  property real flash: 0

  function step(dt) {
    root.surgeClock -= dt
    if (root.surgeClock <= 0 && !root.preview) {
      root.surge = 1
      root.surgeClock = Util.rand(120, 300)
      if (root.speedOption === "hyperspace") root.flash = 1
    }
    var target = root.baseSpeed * (1 + root.surge * 5)
    root.speed += (target - root.speed) * Math.min(1, dt * 1.5)
    if (root.surge > 0) root.surge = Math.max(0, root.surge - dt / 7)
    if (root.flash > 0) root.flash = Math.max(0, root.flash - dt * 1.5)
    stars.travel += root.speed * dt * 0.25
    stars.hue = (stars.hue + dt * 0.03) % 1

    if (quattro.flying) quattro.advance(dt)
    else if (!root.preview && root.host && root.host.rare(60 * 60 * 3)) quattro.launch()
  }

  // Rendered at half resolution and scaled up: a quarter of the fragments,
  // which on integrated graphics is the difference that matters.
  ShaderEffect {
    id: stars
    width: Math.ceil(root.width / 2)
    height: Math.ceil(root.height / 2)
    scale: 2
    transformOrigin: Item.TopLeft
    smooth: true
    property real travel: 0
    property real speed: root.speed
    property real hyper: root.speedOption === "hyperspace" ? 1 : 0
    property real hue: 0.6
    property real density: root.density === "sparse" ? 120 : (root.density === "dense" ? 420 : 240)
    property vector2d resolution: Qt.vector2d(width, height)
    fragmentShader: Qt.resolvedUrl("starfield.frag.qsb")
  }

  Rectangle {
    anchors.fill: parent
    color: "white"
    opacity: root.flash * 0.6
    visible: opacity > 0
  }

  // Once in a long while a winged quattro comes the other way.
  Quattro {
    id: quattro
    property bool flying: false
    property real t: 0
    property real dx: 1
    property real dy: 0

    function launch() {
      flying = true
      t = 0
      dx = Util.rand(-1, 1)
      dy = Util.rand(-0.6, 0.6)
      visible = true
    }

    function advance(dt) {
      t += dt / 3.5
      if (t >= 1) { flying = false; visible = false; return }
      var zoom = Math.pow(t, 3)
      pixel = Math.max(0.5, zoom * root.height / 10)
      x = root.width / 2 + dx * zoom * root.width * 0.6 - width / 2
      y = root.height / 2 + dy * zoom * root.height * 0.6 - height / 2
    }

    visible: false
  }

  FrameAnimation {
    running: root.running && root.visible
    onTriggered: root.step(Math.min(frameTime, 0.05))
  }
}
