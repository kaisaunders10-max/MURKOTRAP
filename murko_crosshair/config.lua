Config = {}

-- Crosshair colour (0-255) and opacity.
Config.Color = { r = 255, g = 255, b = 255, a = 230 }

-- Sizes are in screen pixels.
Config.Length = 6      -- length of each of the four lines (0 = dot only)
Config.Thickness = 2   -- line thickness
Config.Gap = 3         -- empty space between the centre and each line
Config.CenterDot = true

-- Thin black border so the crosshair stays visible on bright backgrounds.
Config.Outline = true

-- Hide GTA's own white weapon dot while the custom crosshair is on.
Config.HideDefaultReticle = true

-- Is the crosshair on the first time a player joins? After that, the
-- player's own /crosshair choice is remembered.
Config.DefaultOn = false
