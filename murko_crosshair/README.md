# murko_crosshair — Simple crosshair

A standalone FiveM resource. No framework, no database, no permissions needed.

Type **`/crosshair`** in chat to turn a crosshair on in the middle of your screen. Type it
again to turn it off. Every player can use it, and each player's choice is remembered
between sessions.

Works on any server. On QBCore it uses the QBCore notification for the on/off message.

## Installation

1. Copy the `murko_crosshair` folder into your server's `resources` directory.
   `fxmanifest.lua` must sit directly inside it: `resources/murko_crosshair/fxmanifest.lua`.
   (On QBCore you can put it in `resources/[standalone]/murko_crosshair` instead.)
2. Add `ensure murko_crosshair` to `server.cfg`. (Not needed in `[standalone]` on QBCore,
   because the QBCore `server.cfg` already has `ensure [standalone]`.)
3. Restart the server, or type `refresh` and then `ensure murko_crosshair` in the server console.

## Commands

| Command | What it does |
| --- | --- |
| `/crosshair` | Toggle the crosshair on/off |
| `/crosshair on` | Turn it on |
| `/crosshair off` | Turn it off |

## Config

Change the look in `config.lua`:

| Setting | Default | Meaning |
| --- | --- | --- |
| `Color` | white | `r`, `g`, `b` (0–255) and opacity `a` |
| `Length` | `6` | Length of each line in pixels (`0` = dot only) |
| `Thickness` | `2` | Line thickness in pixels |
| `Gap` | `3` | Space between the centre and each line |
| `CenterDot` | `true` | Draw a dot in the middle |
| `Outline` | `true` | Thin black border so it shows up on bright backgrounds |
| `HideDefaultReticle` | `true` | Hide GTA's own weapon dot while the crosshair is on |
| `DefaultOn` | `false` | Whether new players start with the crosshair on |

The crosshair hides itself while the pause menu is open.

## Nothing shows when I type /crosshair

1. **Server console**: after `ensure murko_crosshair` you should see `Started resource murko_crosshair`.
   If it says `Couldn't find resource murko_crosshair`, the folder is in the wrong place or is
   named differently. If you downloaded the zip, the `murko_crosshair` folder is *inside* the
   `MURKOTRAP-...` folder: copy just `murko_crosshair` into `resources`.
2. **F8 console in game**: you should see `[murko_crosshair] loaded - type /crosshair to toggle`.
   Each `/crosshair` also prints `[murko_crosshair] crosshair on` / `off`.
3. If F8 shows `crosshair on` but you see no crosshair, another resource may also use
   `/crosshair`. Check your other resources for a `crosshair` command.
