import QtQuick
import "../../lib"
import "../../lib/Sprites.js" as Sprites
import "../../lib/Util.js" as Util

// Omarchy Invaders: an autonomous alien-invasion cabinet. Waves rotate
// through a package swarm, a dependency attack (every enemy depends on the
// one above it, so a hit cascades down the column), a boss, and a Quattro
// bonus stage. The defender plays itself.
Item {
  id: root

  property var host: null
  property bool running: true

  readonly property bool frantic: (host ? host.option("pace", "arcade") : "arcade") === "frantic"
  readonly property real unit: Math.max(0.5, height / 1080)
  readonly property real px: 4 * unit
  readonly property real cellW: 64 * unit
  readonly property real cellH: 54 * unit
  readonly property int rows: 5
  readonly property int cols: 10
  readonly property real groundY: height - 70 * unit
  readonly property real shipY: groundY - 8 * px - 10 * unit
  readonly property real shotSpeed: 720 * unit
  readonly property real marchStep: 12 * unit

  readonly property var kindArt: ({ bug: Sprites.enemyBug, dependency: Sprites.enemyDependency, package: Sprites.enemyPackage })
  readonly property var kindColors: ({
    bug: { B: "#8bdc5a", K: "#0b0d0b" },
    dependency: { B: "#57c7ff", K: "#08101a" },
    package: { B: "#c89b5a", S: "#f2c230", K: "#1a1208" }
  })
  readonly property var kindPoints: ({ bug: 30, dependency: 20, package: 10 })

  readonly property var waveOrder: ["swarm", "dependency", "boss", "swarm", "bonus"]
  property int waveIndex: -1
  property string waveKind: "swarm"
  property int level: 0

  property var enemies: []
  property real formX: 0
  property real formY: 0
  property int formDir: 1
  property real stepClock: 0
  property int animFrame: 0
  property var cascade: []

  property var ship: freshShip(0)
  property var shots: []
  property var bombs: []
  property var sparks: []
  property var bonusCars: []
  property int carSerial: 0
  property var capsule: null
  property var boss: null
  property real fireClock: 1
  property real bonusClock: 0

  property int score: 0
  property int hiScore: 0
  property int lives: 3
  property string banner: ""
  property real bannerTime: 0
  property bool started: false

  function showBanner(text, seconds) {
    root.banner = text
    root.bannerTime = seconds
  }

  function aliveEnemies() {
    var n = 0
    for (var i = 0; i < root.enemies.length; i++) if (root.enemies[i].alive) n++
    return n
  }

  // The defender, at `x`, with nothing in mind yet.
  function freshShip(x) {
    return { x: x, vx: 0, alive: true, respawn: 0, cooldown: 0, power: 0, decide: 0, targetKey: "", trackKey: "", trackX: 0, trackV: 0, aimError: 0, leadSkill: 1, pace: 1, wander: -1 }
  }

  function nextWave() {
    // Targets are named by column or "boss", names the next wave reuses, so
    // the defender starts it with nothing in mind.
    root.ship.targetKey = ""
    root.ship.trackKey = ""
    root.waveIndex = (root.waveIndex + 1) % root.waveOrder.length
    if (root.waveIndex === 0) root.level++
    root.waveKind = root.waveOrder[root.waveIndex]
    root.enemies = []
    root.boss = null
    root.bonusCars = []
    root.cascade = []
    root.bombs = []
    if (root.waveKind === "swarm") {
      buildFormation(["bug", "dependency", "dependency", "package", "package"], false)
      showBanner(root.level > 1 && Util.chance(2) ? "PACKAGE SWARM " + root.level : "PACKAGE SWARM", 2.2)
    } else if (root.waveKind === "dependency") {
      buildFormation(["dependency", "dependency", "dependency", "dependency", "dependency"], true)
      showBanner("DEPENDENCY ATTACK", 2.2)
    } else if (root.waveKind === "boss") {
      // A long enough uptime brings out the penguin instead of the kernel.
      var longUptime = root.host && root.host.uptime > 7 * 86400
      var tux = root.host ? root.host.rare(longUptime ? 2 : 6) : Util.chance(6)
      root.boss = {
        kind: tux ? "tux" : "kernel",
        x: root.width / 2, y: root.height * 0.22, vx: 160 * root.unit,
        hp: 40 + root.level * 10, maxHp: 40 + root.level * 10, fire: 1.5, hurt: 0
      }
      showBanner(tux ? "GIANT TUX BOSS" : "KERNEL BOSS", 2.5)
    } else {
      root.bonusClock = 14
      showBanner("QUATTRO BONUS STAGE", 2.5)
    }
  }

  function buildFormation(rowKinds, linked) {
    var list = []
    for (var r = 0; r < root.rows; r++)
      for (var c = 0; c < root.cols; c++)
        list.push({ row: r, col: c, kind: rowKinds[r], alive: true, linked: linked })
    root.enemies = list
    root.formX = (root.width - root.cols * root.cellW) / 2
    root.formY = root.height * 0.14
    root.formDir = 1
  }

  function enemyX(e) { return root.formX + e.col * root.cellW + (root.cellW - 11 * root.px) / 2 }
  function enemyY(e) { return root.formY + e.row * root.cellH }

  // A run dismissed before GAME OVER keeps its high score too. SaverHost
  // unloads a module before switching its host to the next one.
  Component.onDestruction: if (root.score > root.hiScore && root.host) root.host.set("hiscore", root.score)

  function newGame() {
    if (root.score > root.hiScore) {
      root.hiScore = root.score
      if (root.host) root.host.set("hiscore", root.hiScore)
    }
    root.score = 0
    root.lives = 3
    root.level = 0
    root.waveIndex = -1
    root.ship = freshShip(root.width / 2)
    nextWave()
  }

  function spark(x, y, color, count) {
    for (var i = 0; i < count && root.sparks.length < 120; i++) {
      var a = Math.random() * Math.PI * 2
      var v = Util.rand(60, 260) * root.unit
      root.sparks.push({ x: x, y: y, vx: Math.cos(a) * v, vy: Math.sin(a) * v, life: Util.rand(0.3, 0.8), color: color })
    }
  }

  function killEnemy(e, byShot) {
    if (!e.alive) return
    e.alive = false
    root.score += root.kindPoints[e.kind] || 10
    spark(enemyX(e) + 5.5 * root.px, enemyY(e) + 4 * root.px, root.kindColors[e.kind].B, 10)
    if (byShot && !root.capsule && (root.host ? root.host.rare(22) : Util.chance(22)))
      root.capsule = { x: enemyX(e), y: enemyY(e), vy: 140 * root.unit }
    if (e.linked) {
      // Everything below it in the column depended on it.
      for (var i = 0; i < root.enemies.length; i++) {
        var d = root.enemies[i]
        if (d.alive && d.col === e.col && d.row > e.row) root.cascade.push({ enemy: d, at: (d.row - e.row) * 0.09 })
      }
    }
  }

  function loseLife() {
    var s = root.ship
    s.alive = false
    s.respawn = 1.8
    s.power = 0
    root.lives--
    spark(s.x, root.shipY + 4 * root.px, "#ffffff", 40)
  }

  // Whether the way from `from` to `to` (a spot already clear) passes
  // under no bomb but the ones already over `from`.
  function pathOpen(falling, from, to, reach) {
    var a = Math.min(from, to), z = Math.max(from, to)
    for (var i = 0; i < falling.length; i++) {
      var x = falling[i].x
      if (Math.abs(x - from) >= reach && x > a - reach && x < z + reach) return false
    }
    return true
  }

  // Whether `x` is out of reach of every bomb in `falling`.
  function clearOf(falling, x, reach) {
    for (var i = 0; i < falling.length; i++) if (Math.abs(falling[i].x - x) < reach) return false
    return true
  }

  // Everything that can hit the defender, as { x, y, vy }.
  function threats() {
    return root.bombs
  }

  // The defender plays like a person rather than a turret: it settles on a
  // target for a moment before choosing again (usually the nearest, not
  // always), aims a little off and misjudges the march, drifts about now and
  // then, and speeds up and slows down instead of snapping into place.
  // Dodging stays a reflex.
  function think(dt, m) {
    var s = root.ship
    var shipW = 13 * root.px
    var center = s.x
    var speed = root.width * (root.frantic ? 0.6 : 0.42)

    // Dodge first: a bomb that will land on us soon. A bomb stays a threat
    // until it has fallen past the bottom of the ship, not just its top.
    var lo = shipW / 2 + 10 * root.unit, hi = root.width - shipW / 2 - 10 * root.unit
    var list = threats()
    var falling = []
    for (var i = 0; i < list.length; i++) {
      var b = list[i]
      var t = (root.shipY + 8 * root.px - b.y) / Math.max(1, b.vy)
      if (t > 0 && t < 0.7) falling.push(b)
    }
    // Under a bomb, head for the nearest spot clear of all of them, so bombs
    // on both sides (a boss volley) never cancel out into standing still,
    // preferring one it can reach without passing under another. With no
    // clear spot in reach, get away from the nearest bomb.
    // A bomb hits within 6 art pixels of the ship's centre; keep a little
    // more than that from it, not a whole ship's width.
    var reach = 6 * root.px + 8 * root.unit
    var dodge = 0
    var escape = -1
    if (!clearOf(falling, center, reach)) {
      var escapeOpen = false, nearest = null
      for (var g = 0; g < falling.length; g++) {
        var bx = falling[g].x
        if (!nearest || Math.abs(bx - center) < Math.abs(nearest.x - center)) nearest = falling[g]
        for (var side = -1; side <= 1; side += 2) {
          var x = bx + side * (reach + 4 * root.unit)
          if (x < lo || x > hi || !clearOf(falling, x, reach)) continue
          var open = pathOpen(falling, center, x, reach)
          if (escape < 0 || (open && !escapeOpen) || (open === escapeOpen && Math.abs(x - center) < Math.abs(escape - center))) {
            escape = x
            escapeOpen = open
          }
        }
      }
      if (escape >= 0) dodge = escape < center ? -1 : 1
      else dodge = nearest.x < center ? 1 : -1
    }

    // A fresh aim, pace and mood every so often.
    s.decide -= dt
    if (s.decide <= 0) {
      s.decide = Util.rand(0.25, 0.7)
      s.aimError = Util.rand(-22, 22) * root.unit
      s.pace = Util.rand(0.55, 1)
      s.wander = Util.chance(14) ? Util.rand(0.15, 0.85) * root.width : -1
    }

    // Where each possible target will be when a shot gets there, and how
    // fast that point is moving.
    var targets = []
    if (root.boss) {
      var bossFlight = (root.shipY - root.boss.y) / root.shotSpeed
      targets.push({ key: "boss", x: root.boss.x + root.boss.vx * bossFlight, v: root.boss.vx })
    } else if (root.waveKind === "bonus") {
      for (var q = 0; q < root.bonusCars.length; q++) {
        var car = root.bonusCars[q]
        var fx = car.x + car.w / 2 + car.vx * (root.shipY - car.y) / root.shotSpeed
        if (fx > 0 && fx < root.width) targets.push({ key: car.key, x: fx, v: car.vx })
      }
    } else if (m) {
      // The lowest enemy of each column.
      var lowest = {}
      for (var e = 0; e < root.enemies.length; e++) {
        var en = root.enemies[e]
        if (en.alive && (!lowest[en.col] || lowest[en.col].row < en.row)) lowest[en.col] = en
      }
      var marchV = root.formDir * root.marchStep / m.interval
      for (var c in lowest)
        targets.push({ key: "col:" + c, x: enemyX(lowest[c]) + 5.5 * root.px, lead: marchLead(root.shipY - enemyY(lowest[c]), m), v: marchV })
    }
    // Keep after the chosen target until it is shot at or gone. A new one is
    // usually the nearest, sometimes another one not far off.
    for (var l = 0; l < targets.length; l++) if (targets[l].lead !== undefined) targets[l].x += targets[l].lead
    targets.sort(function(a, z) { return Math.abs(a.x - center) - Math.abs(z.x - center) })
    var target = null
    for (var k = 0; k < targets.length; k++) if (targets[k].key === s.targetKey) target = targets[k]
    if (!target && targets.length) {
      var near = targets.filter(function(o) { return Math.abs(o.x - center) < root.width * 0.3 })
      target = near.length > 1 && Math.random() < 0.2 ? Util.pick(near.slice(1)) : targets[0]
      s.targetKey = target.key
      // How well it will judge this one's march, settled once per target.
      s.leadSkill = Util.rand(0.75, 1.15)
    }
    if (target && target.lead !== undefined) target.x += (s.leadSkill - 1) * target.lead
    var wandering = s.wander >= 0 || !target
    var goalX = s.wander >= 0 ? s.wander : (target ? target.x + s.aimError : center)
    // How fast the aim point really moves (it stops short of the edge where
    // the formation turns), judged from the last moments.
    if (target && target.key === s.trackKey)
      s.trackV += ((target.x - s.trackX) / Math.max(dt, 0.001) - s.trackV) * Math.min(1, dt / 0.25)
    else if (target) {
      s.trackKey = target.key
      s.trackV = target.v
    }
    if (target) s.trackX = target.x
    var goalV = wandering ? 0 : s.trackV

    // Steer with some inertia, keeping up with a moving target.
    // A dodge steers to its clear spot and stops there, so a narrow gap
    // between bombs is not overshot into the next one.
    var want = 0
    if (escape >= 0) want = Util.clamp((escape - center) * 14, -speed, speed)
    else if (dodge !== 0) want = dodge > 0 ? speed : -speed
    else want = Util.clamp(goalV + (goalX - center) * 5, -speed * s.pace, speed * s.pace)
    var accel = speed * (dodge !== 0 ? 14 : 5)
    s.vx += Util.clamp(want - s.vx, -accel * dt, accel * dt)
    // Wait beside a falling bomb rather than slide back under it.
    if (dodge === 0 && !clearOf(falling, center + s.vx * dt, reach)) s.vx = 0
    s.x = Util.clamp(s.x + s.vx * dt, lo, hi)
    if (s.x === lo || s.x === hi) s.vx = 0

    s.cooldown -= dt
    var maxShots = s.power > 0 ? 9 : 2
    if (!wandering && dodge === 0 && Math.abs(goalX - s.x) < 10 * root.unit && s.cooldown <= 0 && root.shots.length < maxShots) {
      var y = root.shipY
      root.shots.push({ x: s.x, y: y, vx: 0 })
      if (s.power > 0) {
        root.shots.push({ x: s.x, y: y, vx: -160 * root.unit })
        root.shots.push({ x: s.x, y: y, vx: 160 * root.unit })
      }
      s.cooldown = s.power > 0 ? 0.18 : Util.rand(0.28, 0.55)
      if (Math.random() < 0.3) s.targetKey = ""
    }
  }

  // The formation's march as it stands, from one look at the enemies: how
  // many are left, the seconds between steps (fewer enemies, faster march:
  // the classic panic), how many steps it can take before it reaches the
  // edge and turns, and how low it has come. Worked out once a frame.
  function march() {
    var alive = 0, minX = 1e9, maxX = -1e9, maxY = 0
    for (var i = 0; i < root.enemies.length; i++) {
      var e = root.enemies[i]
      if (!e.alive) continue
      alive++
      minX = Math.min(minX, enemyX(e))
      maxX = Math.max(maxX, enemyX(e) + 11 * root.px)
      maxY = Math.max(maxY, enemyY(e) + 8 * root.px)
    }
    var room = root.formDir > 0 ? root.width - 20 * root.unit - maxX : minX - 20 * root.unit
    var interval = Math.max(0.05, 0.62 * alive / (root.rows * root.cols)) * (root.frantic ? 0.6 : 1) / (1 + root.level * 0.15)
    return { alive: alive, interval: interval, stepsLeft: Math.max(0, Math.floor(room / root.marchStep)), maxY: maxY }
  }

  // How far the formation will have marched sideways by the time a shot
  // fired now climbs `distance`, stopping at the edge where it turns.
  function marchLead(distance, m) {
    var steps = Math.floor((root.stepClock + distance / root.shotSpeed) / m.interval)
    if (steps <= 0) return 0
    return root.formDir * root.marchStep * Math.min(steps, m.stepsLeft)
  }

  function stepFormation(dt, m) {
    if (m.alive === 0) return
    root.stepClock += dt
    if (root.stepClock < m.interval) return
    root.stepClock = 0
    root.animFrame = 1 - root.animFrame
    if (m.stepsLeft < 1) {
      root.formY += root.cellH * 0.4
      root.formDir = -root.formDir
    } else {
      root.formX += root.marchStep * root.formDir
    }
    if (m.maxY >= root.shipY) {
      // They landed.
      showBanner("SYSTEM COMPROMISED", 3)
      root.lives = 0
      loseLife()
    }
  }

  function step(dt) {
    if (root.width <= 0) return
    if (!root.started) {
      root.started = true
      root.hiScore = root.host ? Number(root.host.get("hiscore", 0)) || 0 : 0
      newGame()
    }
    if (root.bannerTime > 0) root.bannerTime -= dt
    var s = root.ship
    if (s.power > 0) s.power -= dt

    var formation = root.waveKind === "swarm" || root.waveKind === "dependency"
    var marching = formation ? march() : null
    if (s.alive) think(dt, marching)
    else {
      s.respawn -= dt
      if (s.respawn <= 0) {
        if (root.lives <= 0) {
          // After newGame(), whose first wave would replace it.
          newGame()
          showBanner("GAME OVER", 3)
          return
        }
        root.ship = freshShip(root.width / 2)
        s = root.ship
        root.bombs = []
      }
    }

    if (formation) stepFormation(dt, marching)

    // Cascading dependency failures.
    var pending = []
    for (var c = 0; c < root.cascade.length; c++) {
      var job = root.cascade[c]
      job.at -= dt
      if (job.at <= 0) killEnemy(job.enemy, false)
      else pending.push(job)
    }
    root.cascade = pending

    // Enemy fire.
    root.fireClock -= dt
    if (root.fireClock <= 0 && s.alive && root.enemies.length) {
      var shooters = {}
      for (var e = 0; e < root.enemies.length; e++) {
        var en = root.enemies[e]
        if (en.alive && (!shooters[en.col] || shooters[en.col].row < en.row)) shooters[en.col] = en
      }
      var keys = Object.keys(shooters)
      if (keys.length) {
        var shooter = shooters[Util.pick(keys)]
        root.bombs.push({ x: enemyX(shooter) + 5.5 * root.px, y: enemyY(shooter) + 8 * root.px, vy: 300 * root.unit })
      }
      root.fireClock = Util.rand(0.5, 1.3) / (1 + root.level * 0.2) * (root.frantic ? 0.6 : 1)
    }

    // The boss.
    if (root.boss) {
      var bossItem = root.boss
      bossItem.x += bossItem.vx * dt
      var half = bossW(bossItem.kind) / 2
      if (bossItem.x < half + 20 * root.unit || bossItem.x > root.width - half - 20 * root.unit) bossItem.vx = -bossItem.vx
      bossItem.x = Util.clamp(bossItem.x, half + 20 * root.unit, root.width - half - 20 * root.unit)
      bossItem.hurt = Math.max(0, bossItem.hurt - dt)
      bossItem.fire -= dt
      if (bossItem.fire <= 0 && s.alive) {
        for (var k = -2; k <= 2; k++)
          root.bombs.push({ x: bossItem.x + k * 30 * root.unit, y: bossItem.y + bossH(bossItem.kind) / 2, vy: (260 + Math.abs(k) * 30) * root.unit })
        bossItem.fire = Util.rand(1.2, 2.2)
      }
    }

    // Quattro bonus stage.
    if (root.waveKind === "bonus") {
      root.bonusClock -= dt
      if (root.bonusClock > 2 && root.bonusCars.length < 5 && Util.chance(40)) {
        var left = Math.random() < 0.5
        var cw = Sprites.quattroColumns * root.px * 0.7
        root.bonusCars.push({ key: "car:" + (++root.carSerial), x: left ? -cw : root.width, y: Util.rand(0.12, 0.45) * root.height, vx: (left ? 1 : -1) * Util.rand(220, 380) * root.unit, w: cw, left: !left, hit: false })
      }
      var keptCars = []
      for (var q = 0; q < root.bonusCars.length; q++) {
        var car = root.bonusCars[q]
        car.x += car.vx * dt
        if (!car.hit && car.x > -car.w * 2 && car.x < root.width + car.w) keptCars.push(car)
      }
      root.bonusCars = keptCars
      if (root.bonusClock <= 0) nextWave()
    }

    // Shots.
    var keptShots = []
    for (var i = 0; i < root.shots.length; i++) {
      var shot = root.shots[i]
      shot.y -= root.shotSpeed * dt
      shot.x += shot.vx * dt
      var spent = shot.y < 0
      for (var j = 0; !spent && j < root.enemies.length; j++) {
        var target = root.enemies[j]
        if (!target.alive) continue
        var tx = enemyX(target), ty = enemyY(target)
        if (shot.x >= tx && shot.x <= tx + 11 * root.px && shot.y >= ty && shot.y <= ty + 8 * root.px) {
          killEnemy(target, true)
          spent = true
        }
      }
      if (!spent && root.boss && Math.abs(shot.x - root.boss.x) < bossW(root.boss.kind) / 2 && Math.abs(shot.y - root.boss.y) < bossH(root.boss.kind) / 2) {
        root.boss.hp--
        root.boss.hurt = 0.08
        spent = true
        if (root.boss.hp <= 0) {
          root.score += root.boss.kind === "tux" ? 10000 : 2500
          spark(root.boss.x, root.boss.y, "#ffffff", 90)
          showBanner(root.boss.kind === "tux" ? "THE PENGUIN RETREATS" : "KERNEL PANIC", 2.5)
          root.boss = null
        }
      }
      for (var b = 0; !spent && b < root.bonusCars.length; b++) {
        var bc = root.bonusCars[b]
        if (!bc.hit && shot.x >= bc.x && shot.x <= bc.x + bc.w && shot.y >= bc.y && shot.y <= bc.y + Sprites.quattroRows * root.px * 0.7) {
          bc.hit = true
          root.score += 500
          spark(bc.x + bc.w / 2, bc.y, "#f2c230", 30)
          spent = true
        }
      }
      if (!spent) keptShots.push(shot)
    }
    root.shots = keptShots

    // Bombs.
    var keptBombs = []
    for (var m = 0; m < root.bombs.length; m++) {
      var bomb = root.bombs[m]
      bomb.y += bomb.vy * dt
      if (bomb.y > root.groundY) continue
      if (s.alive && Math.abs(bomb.x - s.x) < 6 * root.px && bomb.y > root.shipY && bomb.y < root.shipY + 8 * root.px) {
        loseLife()
        continue
      }
      keptBombs.push(bomb)
    }
    root.bombs = keptBombs

    // The root capsule: triple shot for ten seconds.
    if (root.capsule) {
      root.capsule.y += root.capsule.vy * dt
      if (s.alive && root.capsule.y > root.shipY - 10 * root.unit && Math.abs(root.capsule.x + 20 * root.unit - s.x) < 50 * root.unit) {
        s.power = 10
        root.capsule = null
        showBanner("ROOT GRANTED", 1.5)
      } else if (root.capsule.y > root.groundY) {
        root.capsule = null
      }
    }

    var keptSparks = []
    for (var p = 0; p < root.sparks.length; p++) {
      var sp = root.sparks[p]
      sp.life -= dt
      if (sp.life <= 0) continue
      sp.x += sp.vx * dt
      sp.y += sp.vy * dt
      keptSparks.push(sp)
    }
    root.sparks = keptSparks

    if ((root.waveKind === "swarm" || root.waveKind === "dependency") && aliveEnemies() === 0 && root.cascade.length === 0) nextWave()
    if (root.waveKind === "boss" && !root.boss) nextWave()
    sync()
  }

  // The boss's size, for drawing it and for hitting it alike.
  function bossW(kind) { return kind === "tux" ? 12 * root.px * 3 : 180 * root.unit }
  function bossH(kind) { return kind === "tux" ? 12 * root.px * 3 : 150 * root.unit }

  // The ship, boss and capsule change in place, which no binding sees, so
  // they are placed here every frame like everything else.
  function sync() {
    var s = root.ship
    shipItem.visible = s.alive
    shipItem.x = s.x - shipItem.width / 2
    shipItem.powered = s.power > 0
    var boss = root.boss
    bossItem.visible = !!boss
    if (boss) {
      bossItem.kind = boss.kind
      bossItem.x = boss.x - bossItem.width / 2
      bossItem.y = boss.y - bossItem.height / 2
      bossItem.opacity = boss.hurt > 0 ? 0.55 : 1
      bossItem.health = boss.hp / boss.maxHp
    }
    capsuleItem.visible = !!root.capsule
    if (root.capsule) {
      capsuleItem.x = root.capsule.x
      capsuleItem.y = root.capsule.y
    }
    for (var i = 0; i < root.rows * root.cols; i++) {
      var item = enemyRepeater.itemAt(i)
      if (!item) continue
      var e = root.enemies[i]
      if (!e || !e.alive) { item.visible = false; continue }
      item.kind = e.kind
      item.x = enemyX(e)
      item.y = enemyY(e)
      item.visible = true
    }
    // The links only move with the formation or when an enemy dies.
    var linkKey = root.waveKind === "dependency" ? root.formX + ":" + root.formY + ":" + aliveEnemies() : ""
    if (linkKey !== links.drawnKey) {
      links.drawnKey = linkKey
      links.requestPaint()
    }
    for (var n = 0; n < 12; n++) {
      var shotItem = shotRepeater.itemAt(n)
      if (!shotItem) continue
      var shot = root.shots[n]
      shotItem.visible = !!shot
      if (shot) { shotItem.x = shot.x - shotItem.width / 2; shotItem.y = shot.y }
    }
    for (var b = 0; b < 24; b++) {
      var bombItem = bombRepeater.itemAt(b)
      if (!bombItem) continue
      var bomb = root.bombs[b]
      bombItem.visible = !!bomb
      if (bomb) { bombItem.x = bomb.x - bombItem.width / 2; bombItem.y = bomb.y; bombItem.rotation = (bomb.y / (10 * root.unit)) % 2 < 1 ? 20 : -20 }
    }
    for (var p = 0; p < 120; p++) {
      var sparkItem = sparkRepeater.itemAt(p)
      if (!sparkItem) continue
      var sp = root.sparks[p]
      sparkItem.visible = !!sp
      if (sp) { sparkItem.x = sp.x; sparkItem.y = sp.y; sparkItem.color = sp.color; sparkItem.opacity = Math.min(1, sp.life * 2) }
    }
    for (var q = 0; q < 5; q++) {
      var carItem = carRepeater.itemAt(q)
      if (!carItem) continue
      var car = root.bonusCars[q]
      carItem.visible = !!car
      if (car) { carItem.x = car.x; carItem.y = car.y; carItem.facingLeft = car.left }
    }
  }

  // ------------------------------------------------------------------ scene

  Rectangle { anchors.fill: parent; color: "#020203" }

  Repeater {
    model: 60
    Rectangle {
      required property int index
      readonly property real seed: Math.sin(index * 78.233) * 43758.5453
      x: (seed - Math.floor(seed)) * root.width
      y: ((seed * 3.7) - Math.floor(seed * 3.7)) * root.groundY
      width: Math.max(1, root.unit * 2)
      height: width
      color: "#9aa5c8"
      opacity: 0.2 + (index % 4) * 0.1
    }
  }

  Rectangle {
    x: 0
    y: root.groundY
    width: root.width
    height: Math.max(2, 3 * root.unit)
    color: "#3fbf5f"
  }

  // Dependency links between enemies in the same column.
  Canvas {
    id: links
    property string drawnKey: "none"
    anchors.fill: parent
    visible: root.waveKind === "dependency"
    onPaint: {
      var ctx = getContext("2d")
      ctx.clearRect(0, 0, width, height)
      if (root.waveKind !== "dependency") return
      ctx.strokeStyle = "rgba(87,199,255,0.45)"
      ctx.lineWidth = Math.max(1, 2 * root.unit)
      ctx.beginPath()
      var byCell = {}
      for (var i = 0; i < root.enemies.length; i++) {
        var e = root.enemies[i]
        if (e.alive) byCell[e.row + ":" + e.col] = e
      }
      for (var key in byCell) {
        var a = byCell[key]
        var below = byCell[(a.row + 1) + ":" + a.col]
        if (!below) continue
        var x = root.enemyX(a) + 5.5 * root.px
        ctx.moveTo(x, root.enemyY(a) + 8 * root.px)
        ctx.lineTo(x, root.enemyY(below))
      }
      ctx.stroke()
    }
  }

  Repeater {
    id: enemyRepeater
    model: root.rows * root.cols
    PixelSprite {
      property string kind: "bug"
      visible: false
      rows: (root.kindArt[kind] || Sprites.enemyBug)[root.animFrame]
      colors: root.kindColors[kind] || root.kindColors.bug
      pixel: root.px
    }
  }

  // Boss: the kernel, drawn as a chip; or, rarely, a giant penguin.
  Item {
    id: bossItem
    property string kind: "kernel"
    property real health: 1
    visible: false
    width: root.bossW(kind)
    height: root.bossH(kind)

    Rectangle {
      visible: bossItem.kind === "kernel"
      anchors.centerIn: parent
      width: parent.width * 0.78
      height: parent.height * 0.78
      color: "#1c2330"
      border.color: "#8fa3c7"
      border.width: Math.max(2, 3 * root.unit)
      Repeater {
        model: 8
        Rectangle {
          required property int index
          x: (index + 0.5) * parent.width / 8 - width / 2
          y: -height
          width: 6 * root.unit
          height: 14 * root.unit
          color: "#c9a44a"
        }
      }
      Repeater {
        model: 8
        Rectangle {
          required property int index
          x: (index + 0.5) * parent.width / 8 - width / 2
          y: parent.height
          width: 6 * root.unit
          height: 14 * root.unit
          color: "#c9a44a"
        }
      }
      PixelText {
        anchors.centerIn: parent
        text: "LINUX"
        color: "#e8433a"
        pixel: 4 * root.unit
      }
      Row {
        anchors { horizontalCenter: parent.horizontalCenter; top: parent.top; topMargin: parent.height * 0.18 }
        spacing: parent.width * 0.22
        Repeater {
          model: 2
          Rectangle { width: 16 * root.unit; height: 16 * root.unit; color: "#e8433a" }
        }
      }
    }
    PixelSprite {
      visible: bossItem.kind === "tux"
      rows: Sprites.tux
      colors: Sprites.tuxPalette
      pixel: root.px * 3
    }
    Rectangle {
      anchors { horizontalCenter: parent.horizontalCenter; top: parent.bottom; topMargin: 18 * root.unit }
      width: parent.width
      height: 6 * root.unit
      color: "#30333a"
      Rectangle {
        width: parent.width * bossItem.health
        height: parent.height
        color: "#e8433a"
      }
    }
  }

  Repeater {
    id: carRepeater
    model: 5
    Quattro {
      visible: false
      livery: 3
      pixel: root.px * 0.7
    }
  }

  PixelSprite {
    id: shipItem
    property bool powered: false
    visible: false
    rows: Sprites.ship
    colors: ({ K: "#0b0b0d", W: powered ? "#f2c230" : "#e8e8e8", Y: "#e8433a" })
    pixel: root.px
    y: root.shipY
  }

  Repeater {
    id: shotRepeater
    model: 12
    Rectangle { visible: false; width: 3 * root.unit; height: 16 * root.unit; color: "#ffffff" }
  }

  Repeater {
    id: bombRepeater
    model: 24
    Rectangle { visible: false; width: 4 * root.unit; height: 14 * root.unit; color: "#ff6a4d" }
  }

  Repeater {
    id: sparkRepeater
    model: 120
    Rectangle { visible: false; width: 3 * root.unit; height: 3 * root.unit }
  }

  Rectangle {
    id: capsuleItem
    visible: false
    width: capsuleText.width + 12 * root.unit
    height: capsuleText.height + 8 * root.unit
    radius: height / 2
    color: "#f2c230"
    PixelText {
      id: capsuleText
      anchors.centerIn: parent
      text: "ROOT"
      color: "#1a1208"
      pixel: 2.5 * root.unit
    }
  }

  PixelText {
    x: 30 * root.unit
    y: 26 * root.unit
    text: "SCORE " + Util.pad(root.score, 6, "0")
    color: "#e8e8e8"
    pixel: 4 * root.unit
  }
  PixelText {
    anchors.horizontalCenter: parent.horizontalCenter
    y: 26 * root.unit
    text: "HI " + Util.pad(Math.max(root.hiScore, root.score), 6, "0")
    color: "#e8e8e8"
    opacity: 0.7
    pixel: 4 * root.unit
  }
  Row {
    anchors { right: parent.right; rightMargin: 30 * root.unit }
    y: 22 * root.unit
    spacing: 10 * root.unit
    Repeater {
      model: Math.max(0, root.lives)
      PixelSprite { rows: Sprites.ship; colors: ({ K: "#0b0b0d", W: "#e8e8e8", Y: "#e8433a" }); pixel: 2.4 * root.unit }
    }
  }

  PixelText {
    anchors { horizontalCenter: parent.horizontalCenter; verticalCenter: parent.verticalCenter; verticalCenterOffset: root.height * 0.08 }
    visible: root.bannerTime > 0
    opacity: Math.min(1, root.bannerTime * 2)
    text: root.banner
    color: "#f2c230"
    pixel: 7 * root.unit
  }

  FrameAnimation {
    running: root.running && root.visible
    onTriggered: root.step(Math.min(frameTime, 0.05))
  }
}
