# CLAUDE.md

This file provides guidance to Claude Code (claude.ai/code) when working with code in this repository.

## What this is

Azeroth Stillframe is a World of Warcraft add-on (targeting the "WoW: Forever" client, `## Interface: 16001`) that provides a photography mode: hide the UI and names, draw composition guides, and take clean screenshots. It is the renamed successor of "Azeroth Darkroom", and keeps backward-compatible aliases for it.

## Build / test

There is no build system, linter config, or test suite. The add-on is plain Lua 5.1 loaded directly by the game client. To install, copy the repo contents into `World of Warcraft/_forever_/Interface/AddOns/AzerothStillframe/` (the folder name must match the `.toc` name, and the old `AzerothDarkroom` folder must be removed).

No Lua tooling is installed locally. If you add a syntax check, `luac -p *.lua` (Lua 5.1) is the right shape. v0.4.2 has been verified in game by the author, but there are no automated tests, so after a change testing comes down to the "First test" checklist in README.md: each guide renders, cycling and orientation work, screenshots contain no guide lines, nameplates are restored, and the UI comes back after exiting. The import of old Darkroom settings has not been confirmed in game.

`docs/images/` holds example screenshots for the README. WoW never loads it, so leave it out of the add-on zip.

## Architecture

The load order in `AzerothStillframe.toc` matters: `Overlays.lua` → `Names.lua` → `Core.lua` → `Bindings.xml`. The modules talk to each other only through globals. `Core.lua` stores `AzerothStillframeOverlayAPI` and `AzerothStillframeNamesAPI` in locals when it loads, so both must already be defined by then.

- **Overlays.lua**: a canvas frame parented to `WorldFrame`, not `UIParent`, so guides stay visible while `UIParent` is hidden. The geometry uses normalized 0–1 coordinates with the origin at top-left, and `segment()` converts them to pixels. Line objects are pooled in `stroke` and reused, and any extras are hidden after each `draw()`. `add()` applies `orientation` (0–3: none, horizontal flip, vertical flip, both). Only the asymmetric guides (triangle, spiral) use `add()`; thirds and phi call `segment()` directly. The guides redraw on `OnSizeChanged`. The triangle perpendiculars are computed in pixel space so they stay perpendicular on ultrawide screens.
- **Names.lua**: hides floating names and nameplates by setting CVars to `"0"`. It only calls CVar APIs, through `pcall` and with a `C_CVar`/legacy fallback, never protected frame APIs. In `previous` it records only the CVars it actually changed. On restore it writes a CVar back only if the value is still `"0"`, so changes made by the user or another add-on survive. `UnitNameHostleNPC` is Blizzard's own misspelling; do not "fix" it.
- **Core.lua**: the state machine (`active`, `capturePending`, `captureSerial`), slash commands, keybinding functions, and SavedVariables. `syncGuide()` is the single place that decides whether the overlay is visible: shown only when `active and not capturePending`. A capture hides the guides, takes `Screenshot()` after 0.15s, and restores after another 0.5s. `captureSerial` cancels pending timers when the user leaves photo mode in the middle of a capture. Photo mode refuses to start in combat and exits automatically on `PLAYER_REGEN_DISABLED` and on logout.

## Conventions and compatibility constraints

- Global functions `AzerothStillframe_Toggle/Capture/Cycle/Orient` are called from `Bindings.xml`. The `BINDING_*` strings are set at the top of `Core.lua`. Renaming any of them breaks users' keybindings.
- Slash aliases `/as`, `/stillframe`, `/ad`, and `/darkroom` must all keep working.
- SavedVariables: `AzerothStillframeDB` (`guide`, `orientation`, `hideNamesEnabled`, `migratedFromDarkroom`). `AzerothDarkroomDB` is also listed in the `.toc` so that old settings can be imported once on `PLAYER_LOGIN`.
- Adding a guide mode means updating the `modes` list in `Core.lua`, the `overlay <name>` whitelist in `command()`, the help text, `draw()` in `Overlays.lua`, and the README command list.
- When releasing, bump `## Version` in the `.toc` and the README.
