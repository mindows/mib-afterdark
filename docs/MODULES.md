# Writing an After Dark screensaver

A screensaver module is a folder:

```
~/.config/mib-afterdark/screensavers/
  my-saver/
    module.json
    Saver.qml
    ...anything else it needs (more QML, images, shaders)
```

After Dark watches that folder: a new module appears in the control panel
within a second, an edited `module.json` is read again, and a removed folder
disappears. The ten bundled screensavers use exactly the same format, in
`screensavers/` in this repository; they are the best reference.

[examples/bouncing-logo](examples/bouncing-logo) is a complete module to copy.

## module.json

```json
{
  "id": "my-saver",
  "name": "My Saver",
  "description": "One or two sentences for the control panel.",
  "categories": ["retro", "calm"],
  "entry": "Saver.qml",
  "system": false,
  "options": [
    { "key": "speed", "type": "enum", "label": "Speed", "options": ["slow", "fast"], "default": "slow" },
    { "key": "stars", "type": "boolean", "label": "Stars", "default": true }
  ]
}
```

| Field | Rules |
|---|---|
| `id` | Must equal the folder name. Lowercase letters, digits and `-`, up to 41 characters. A module cannot take a bundled screensaver's id. |
| `name` | Up to 40 characters. |
| `description` | Up to 400 characters. |
| `categories` | Any of `omarchy`, `arcade`, `retro`, `system`, `weird`, `calm`, `chaotic`. Random mode picks a module when any of its categories is checked. |
| `entry` | A plain `.qml` file name in the module folder. Defaults to `Saver.qml`. |
| `system` | `true` if the module can use live system data (`host.system`). |
| `options` | Up to 8. `enum` (up to 12 values, each letters, digits, space, `_`, `.`, `-`, up to 30 characters) or `boolean`. The control panel draws them; the chosen values reach the module as `host.options`. |

Anything that breaks a rule is dropped, with a warning in the shell log
(`qs log -p /usr/share/omarchy/shell | grep afterdark`).

## The entry point

The root item fills the screen (or the preview). After Dark sets two
properties on it before `Component.onCompleted` runs:

```qml
import QtQuick

Item {
  id: root
  property var host: null        // the API below
  property bool running: true    // false while locked or hidden: stop animating

  FrameAnimation {
    running: root.running && root.visible
    onTriggered: { /* advance by frameTime */ }
  }
}
```

The item's size can arrive after `Component.onCompleted`; set up anything
that depends on `width` and `height` on the first frame instead.

## host

| Member | What it is |
|---|---|
| `option(key, fallback)` | The value of one of your options. `options` is the whole object. |
| `system` | Live telemetry, or `null` when live system data is off or `system` is not set in `module.json`. Always handle `null`. |
| `preview` | `true` in the control panel's small preview: keep it light, and `set()` does nothing. |
| `elapsed` | Seconds this screensaver has been on screen, for things that should escalate. |
| `uptime` | Seconds since boot, for events that only long uptimes unlock. |
| `userName`, `hostName` | For display. |
| `foreground`, `background`, `accent` | The Omarchy theme's colors. |
| `get(key, fallback)`, `set(key, value)` | Values kept across runs, per module, in `~/.local/state/mib-afterdark/state.json`. Keys are letters, digits and `_`; values are numbers, booleans, or strings up to 200 characters. Read again before adding to a counter: another screen may be running the same module. |
| `rare(n)` | `true` about once in `n` calls. |
| `random(lo, hi)`, `randomInt(lo, hi)`, `pick(list)` | Small helpers. |

### host.system

| Member | What it is |
|---|---|
| `live` | `true` (the simulation in Matrix Operator has the same shape and says `false`). |
| `cpu`, `mem` | 0 to 1. |
| `load1` | One-minute load average. |
| `rxRate`, `txRate` | Network bytes per second, all interfaces but loopback. |
| `battery` | 0 to 1, or -1 without a battery. |
| `uptime` | Seconds. |
| `processCount` | Number of processes. |
| `processes` | The 24 busiest: `{ pid, name, cpu, mem }`. |
| `connections` | Up to 40 established connections: `{ proto, state, local, peer, port, process }`. `peer` is already masked. |
| `sshSessions` | Established connections to or from port 22. |
| `event(kind, text)` | A signal: `spawn`, `exit`, `journal`, `package`, or `net`. |

```qml
Connections {
  target: root.host ? root.host.system : null
  function onEvent(kind, text) { console.log(kind, text) }
}
```

## Staying cheap

A screensaver may run for hours on a laptop. Things that keep the CPU cost low:

- Move items; don't repaint canvases. An `Image`, `Rectangle`, `Text` or
  `Shape` that only changes position, rotation, scale or opacity costs the GPU
  a transform. A `Canvas` repainted every frame costs a quarter of a CPU core
  at 1080p whatever it draws.
- For per-pixel effects use a `ShaderEffect`, and consider drawing it at half
  size with `scale: 2`. Shaders must be compiled to `.qsb` with `qsb` from
  `qt6-shadertools`: see `tools/build-shaders.sh`.
- Stop your `FrameAnimation` and timers when `running` is false.
- Keep `preview` light.

Measured on the reference laptop (Intel UHD 620, 1080p), the bundled
screensavers cost 2% to 16% of one core.

## Rules

- A module runs inside `omarchy-shell`, with the same access as the plugin.
  Don't run commands, touch files, or make network requests; everything a
  screensaver needs comes through `host`.
- Put `textFormat: Text.PlainText` on every `Text` that shows anything that
  did not come from your own code (process names, events, option values).
- Artwork should be your own or properly licensed.
