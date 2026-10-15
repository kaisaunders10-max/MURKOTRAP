local KVP_KEY = 'murko_crosshair:enabled'

local saved = GetResourceKvpString(KVP_KEY)
local enabled = Config.DefaultOn
if saved then
    enabled = saved == 'true'
end

-- Uses the QBCore notification when qb-core is running, otherwise the GTA feed.
local function notify(message, kind)
    if GetResourceState('qb-core') == 'started' then
        TriggerEvent('QBCore:Notify', message, kind)
        return
    end
    BeginTextCommandThefeedPost('STRING')
    AddTextComponentSubstringPlayerName(message)
    EndTextCommandThefeedPostTicker(false, false)
end

local function setEnabled(value)
    enabled = value
    SetResourceKvp(KVP_KEY, tostring(enabled))
    notify(enabled and 'Crosshair on' or 'Crosshair off', enabled and 'success' or 'error')
    print(('[murko_crosshair] crosshair %s'):format(enabled and 'on' or 'off'))
end

-- Draws a rectangle centred on the screen centre plus an offset. Sizes are in
-- pixels on a 1080p screen and scale with the screen height.
local function rect(px, py, offsetX, offsetY, width, height, r, g, b, a)
    DrawRect(0.5 + offsetX * px, 0.5 + offsetY * py, width * px, height * py, r, g, b, a)
end

local function drawCrosshair()
    local aspect = GetAspectRatio(false)
    if not aspect or aspect <= 0 then
        aspect = 16 / 9
    end
    local py = 1.0 / 1080
    local px = py / aspect

    local c = Config.Color
    local len, thick, gap = Config.Length, Config.Thickness, Config.Gap
    local armOffset = gap + len / 2

    local function shape(grow, r, g, b, a)
        local t = thick + grow * 2
        if len > 0 then
            local l = len + grow * 2
            rect(px, py, -armOffset, 0, l, t, r, g, b, a) -- left
            rect(px, py, armOffset, 0, l, t, r, g, b, a)  -- right
            rect(px, py, 0, -armOffset, t, l, r, g, b, a) -- top
            rect(px, py, 0, armOffset, t, l, r, g, b, a)  -- bottom
        end
        if Config.CenterDot then
            rect(px, py, 0, 0, t, t, r, g, b, a)
        end
    end

    if Config.Outline then
        shape(1, 0, 0, 0, c.a)
    end
    shape(0, c.r, c.g, c.b, c.a)
end

CreateThread(function()
    while true do
        if enabled and not IsPauseMenuActive() then
            if Config.HideDefaultReticle then
                HideHudComponentThisFrame(14)
            end
            drawCrosshair()
            Wait(0)
        else
            Wait(250)
        end
    end
end)

RegisterCommand('crosshair', function(_, args)
    local arg = (args[1] or ''):lower()
    if arg == 'on' then
        setEnabled(true)
    elseif arg == 'off' then
        setEnabled(false)
    else
        setEnabled(not enabled)
    end
end, false)

TriggerEvent('chat:addSuggestion', '/crosshair', 'Turn your crosshair on or off', {
    { name = 'on|off', help = 'Optional. Leave empty to toggle' },
})

print('[murko_crosshair] loaded - type /crosshair to toggle')
