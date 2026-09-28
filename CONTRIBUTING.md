# Contributing

Issues and pull requests are welcome. Every change lands through a pull
request that the maintainer reviews and merges; nobody pushes to `main`
directly.

New screensavers are especially welcome, either as a pull request that adds
one to `screensavers/`, or as your own repository that people copy into
`~/.config/mib-afterdark/screensavers/` (see [docs/MODULES.md](docs/MODULES.md)).

## Reporting a bug or asking for a feature

Open an [issue](https://github.com/mindows/mib-afterdark/issues/new). For
bugs, the shell log is the most useful thing to include:

```bash
qs log -p /usr/share/omarchy/shell | grep -i afterdark
```

and the output of:

```bash
omarchy-shell shell call io.github.mindows.mib-afterdark status ""
```

## Working on the plugin

1. Fork the repo and clone your fork.
2. Point Omarchy at your clone instead of an installed copy:

   ```bash
   ln -sfn "$PWD" ~/.config/omarchy/plugins/io.github.mindows.mib-afterdark
   omarchy plugin enable io.github.mindows.mib-afterdark
   ```

3. After each change, restart the shell with `omarchy-restart-shell`.
   `omarchy-shell shell rescanPlugins` can keep serving the cached copy of
   files it has already loaded, so it is not a reliable way to see an edit.
4. Look at your screensaver without waiting for idle:

   ```bash
   tools/snapshot.sh pong 5 /tmp/pong.png          # headless PNG
   tools/preview.sh plasma '{"palette":"fire"}'    # a window, shaders included
   omarchy-shell shell call io.github.mindows.mib-afterdark start pong
   ```

5. Check your work before opening the pull request:

   ```bash
   omarchy plugin validate .
   tools/build-shaders.sh        # if you changed a .frag
   ```

   and measure what your screensaver costs while it runs full screen:

   ```bash
   pid=$(pgrep -f "^quickshell -n -p /usr/share/omarchy/shell")
   a=$(awk '{print $14+$15}' /proc/$pid/stat); sleep 4
   b=$(awk '{print $14+$15}' /proc/$pid/stat); echo "$(( (b - a) * 100 / 400 ))% of one core"
   ```

   Aim for the range the bundled ones sit in (under about 16% on a 2018 laptop).

## Style

- Match the code around your change: its naming, layout, and how much it
  comments. Comments say why, in plain sentences.
- `textFormat: Text.PlainText` on every `Text`.
- Keep the README in step with behaviour.
- Commit messages: a short imperative subject ("Add a snow option to Pipes"),
  then a body that explains what changed and why.
- One topic per pull request.

## Privacy

Live system data is off by default and never leaves the machine. Changes that
read something new, or show something new on an idle screen, need to say so
in the pull request and the README, and should be off by default.

## License

By contributing, you agree that your contributions are licensed under the
[MIT License](LICENSE).
