# focus-follows-mouse

Rest the pointer on a window and it gets keyboard focus. No click needed.
A small, dependency-free replacement for AutoRaise-style tools on macOS.

## Install

```bash
curl -fsSL https://raw.githubusercontent.com/hemanthtechey/focus-follows-mouse/main/install.sh | bash
```

Then turn on **focus-follows-mouse** in the Accessibility list that opens
(System Settings → Privacy & Security → Accessibility). It starts automatically at login.

If the Command Line Tools aren't installed yet, the script opens the installer for you. Run the command again once they're installed.

## Manual install (step by step)

```bash
# 1. Get the code
git clone https://github.com/hemanthtechey/focus-follows-mouse.git
cd focus-follows-mouse

# 2. Build it
mkdir -p ~/Library/Application\ Support/focus-follows-mouse
swiftc -O focus.swift -o ~/Library/Application\ Support/focus-follows-mouse/focus-follows-mouse

# 3. Start it now and at every login
sed "s|__HOME__|$HOME|" local.focus-follows-mouse.plist > ~/Library/LaunchAgents/local.focus-follows-mouse.plist
launchctl bootstrap gui/$(id -u) ~/Library/LaunchAgents/local.focus-follows-mouse.plist
```

4. Go to **System Settings → Privacy & Security → Accessibility** and turn on **focus-follows-mouse**.

Stop it: `launchctl bootout gui/$(id -u)/local.focus-follows-mouse`

## Uninstall

```bash
curl -fsSL https://raw.githubusercontent.com/hemanthtechey/focus-follows-mouse/main/install.sh | bash -s -- --uninstall
```

## How it works

`focus.swift` checks the pointer every 100 ms. When it rests over a normal app window for about 200 ms,
that window is raised and its app activated, using the Accessibility API.

It deliberately stays out of the way:
- **Drags:** nothing happens while a mouse button is held.
- **Menu bar, Dock and desktop:** ignored.
- **Popups:** it never steals focus from launchers, Spotlight or dialogs. Apps are judged by their activation
  policy rather than by window subrole, because some apps (e.g. recent iTerm2 builds) report normal windows
  as `AXSystemDialog`.

It's built from source on your Mac, so there's no prebuilt binary to trust.

## Notes

- Log: `/tmp/focus-follows-mouse.log`
- If you rebuild or reinstall, macOS sees a new binary, so you may need to turn it on again in Accessibility.

## Licence

MIT, see [LICENSE](LICENSE).
