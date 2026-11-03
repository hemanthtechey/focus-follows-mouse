#!/bin/bash
# Builds Focus Follows Mouse.app from source and installs it in /Applications.  Uninstall: ./install.sh --uninstall
set -euo pipefail

APP="Focus Follows Mouse.app"
ID=local.focus-follows-mouse
BASE=https://raw.githubusercontent.com/hemanthtechey/focus-follows-mouse/main

# Remove the older LaunchAgent-based version so two copies never run at once.
launchctl bootout "gui/$(id -u)/$ID" 2>/dev/null || true
rm -rf "$HOME/Library/LaunchAgents/$ID.plist" "$HOME/Library/Application Support/focus-follows-mouse"

if [ "${1:-}" = "--uninstall" ]; then
  pkill -x FocusFollowsMouse || true
  rm -rf "/Applications/$APP"
  tccutil reset Accessibility "$ID" >/dev/null 2>&1 || true
  echo "Removed Focus Follows Mouse."
  exit 0
fi

if ! xcode-select -p >/dev/null 2>&1; then
  xcode-select --install || true
  echo "Install the Command Line Tools from the dialog, then run this again."
  exit 1
fi

# Use the files next to this script when run from a clone; otherwise download them.
HERE="$(cd "$(dirname "${BASH_SOURCE[0]:-$0}")" 2>/dev/null && pwd || true)"
if [ -n "$HERE" ] && [ -f "$HERE/focus.swift" ] && [ -f "$HERE/build.sh" ]; then
  SRC="$HERE"
else
  SRC="$(mktemp -d)"; trap 'rm -rf "$SRC"' EXIT
  for f in focus.swift make-icon.swift build.sh; do curl -fsSL "$BASE/$f" -o "$SRC/$f"; done
fi
sh "$SRC/build.sh" --install
