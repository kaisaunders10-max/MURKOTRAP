# murko_crosshair — Simple crosshair

A standalone FiveM resource. No framework, no database, no permissions needed.

Type **`/crosshair`** in chat to turn a crosshair on in the middle of your screen. Type it
again to turn it off. Every player can use it, and each player's choice is remembered
between sessions.

## Installation

1. Copy the `murko_crosshair` folder into your server's `resources` directory.
2. Add `ensure murko_crosshair` to `server.cfg`.

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
