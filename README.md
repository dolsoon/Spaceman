<div align="center">

# Spaceman — Agentic Era Edition

**A macOS menu bar app that shows your Spaces — upgraded for the age of AI multitasking.**

[![macOS](https://img.shields.io/badge/macOS-15%2B-blue)](https://www.apple.com/macos/)
[![Swift](https://img.shields.io/badge/Swift-5.9-orange)](https://swift.org/)
[![License: MIT](https://img.shields.io/badge/License-MIT-green)](LICENSE)
[![Fork of Spaceman](https://img.shields.io/badge/Fork%20of-Jaysce%2FSpaceman-lightgrey)](https://github.com/Jaysce/Spaceman)

</div>

---

Modern AI workflows mean you're constantly juggling multiple context windows — Claude, your terminal, a browser tab for docs, and an IDE — all at once. Losing track of *which Space you're in* breaks flow.

**Spaceman — Agentic Era Edition** adds a full-screen overlay that fires instantly when you switch Spaces, so your brain always knows where it is.

---

## What's New (vs. original Spaceman)

### Space Switch Overlay
When you switch Spaces, a centered HUD appears for 1.5 seconds:

```
◀ Terminal           Code ▶
         AI Dev
    ○  ○  ●  ○  ○
```

- **Current Space** shown in large type (52pt)
- **Adjacent spaces** with arrows on left/right
- **All spaces** shown as indicator chips below
- **Hover** over the HUD to keep it visible
- **Click the pencil icon** to rename the space inline → opens a rename dialog

### Better Space Names
- Names are no longer capped at 3 characters — store the full name (e.g. `AI Dev`, `Research`, `Claude`)
- Menu bar still shows a 3-character abbreviation so it stays compact

---

## Installation

### Build from source

Requirements: macOS 15+, Xcode 16+

```bash
git clone https://github.com/dolsoon/Spaceman.git
cd Spaceman
./run.sh          # builds and launches automatically
```

`run.sh` kills any existing Spaceman instance, builds in Debug mode, and opens the new binary.

---

## Usage

1. Launch the app — a `⬛⬜` icon appears in your menu bar
2. Switch Spaces with **Control + Arrow** (or Mission Control)
3. The overlay fires immediately on every switch
4. To rename a Space: hover over the HUD, click **✏** → type a new name → **Enter**
5. To configure display style: click the menu bar icon → **Preferences**

---

## Roadmap

> Contributions welcome. The goal: make Spaceman a first-class citizen in AI-assisted developer workflows.

- [ ] **Claude Code hook integration** — trigger a space switch automatically when a Claude Code session starts or ends a task (`PostToolUse` / `Stop` hooks)
- [ ] **Terminal shell integration** — `spaceman switch "AI Dev"` CLI command; auto-switch Space when `cd`-ing into a project directory
- [ ] **URL scheme** — `spaceman://switch/AI%20Dev` for Raycast, Alfred, Shortcuts automation
- [ ] **Named Space presets** — save and restore sets of apps per Space (e.g. "AI Dev" always opens Claude + terminal + browser)
- [ ] **Notification** when a background agent (Claude, Copilot, etc.) finishes a long task in another Space
- [ ] **Hammerspoon / Karabiner binding** support via socket API
- [ ] **tmux window ↔ Space sync** — name your tmux windows to match Space names
- [ ] **Scriptable REST API** (localhost) for any tool to read/set the active Space

---

## Why fork?

The [original Spaceman](https://github.com/Jaysce/Spaceman) is a clean, well-built app. This fork adds UX that matters specifically for developers running multi-agent AI workflows, where context-switching speed and spatial awareness are critical.

---

## Credits

Built on top of [Spaceman by Jaysce](https://github.com/Jaysce/Spaceman) — MIT License.  
Original copyright © 2020 Sasindu Jayasinghe.

---

## License

MIT — see [LICENSE](LICENSE).
