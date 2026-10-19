-- corlinks_vipgarage · client: showroom camera + full vehicle editor (liveries, respray, every mod slot)
local QBCore = exports['qb-core']:GetCoreObject()
local open, veh, cam, original = false, 0, nil, nil
local yaw, pitch, dist, focusZ = 200.0, 12.0, 6.5, 0.4

local MOD_NAMES = {
    [0] = 'Spoiler', [1] = 'Front Bumper', [2] = 'Rear Bumper', [3] = 'Side Skirts', [4] = 'Exhaust', [5] = 'Roll Cage', [6] = 'Grille',
    [7] = 'Hood', [8] = 'Left Fender', [9] = 'Right Fender', [10] = 'Roof', [11] = 'Engine', [12] = 'Brakes', [13] = 'Transmission',
    [14] = 'Horn', [15] = 'Suspension', [16] = 'Armour', [23] = 'Rims', [24] = 'Rear Rims (bikes)', [25] = 'Plate Holder',
    [26] = 'Vanity Plate', [27] = 'Trim', [28] = 'Ornaments', [29] = 'Dashboard', [30] = 'Dials', [31] = 'Door Speakers', [32] = 'Seats',
    [33] = 'Steering Wheel', [34] = 'Shifter', [35] = 'Plaques', [36] = 'Speakers', [37] = 'Trunk', [38] = 'Hydraulics', [39] = 'Engine Block',
    [40] = 'Air Filter', [41] = 'Struts', [42] = 'Arch Covers', [43] = 'Aerials', [44] = 'Trim B', [45] = 'Fuel Tank', [46] = 'Windows', [48] = 'Livery (mod)',
}
local GROUP = { [11] = 'perf', [12] = 'perf', [13] = 'perf', [15] = 'perf', [16] = 'perf', [23] = 'wheels', [24] = 'wheels', [48] = 'livery' }
local WHEEL_TYPES = { [0] = 'Sport', [1] = 'Muscle', [2] = 'Lowrider', [3] = 'SUV', [4] = 'Offroad', [5] = 'Tuner', [6] = 'Bike', [7] = 'High End',
    [8] = "Benny's Original", [9] = "Benny's Bespoke", [10] = 'Open Wheel', [11] = 'Street', [12] = 'Track' }

local function notify(msg, typ) lib.notify({ title = 'VIP Garage', description = msg, type = typ or 'inform' }) end
local function label(txt, fallback)
    if not txt or txt == '' or txt == 'NULL' then return fallback end
    local l = GetLabelText(txt)
    if l == 'NULL' or l == '' then return fallback end
    return l
end

-- ─── read the car ─────────────────────────────────────────────────────────
local function build()
    SetVehicleModKit(veh, 0)
    local model = GetEntityModel(veh)
    local mname = GetDisplayNameFromVehicleModel(model)
    local d = { name = label(mname, mname), model = mname, plate = GetVehicleNumberPlateText(veh) }
    -- the game's display names are cut to 11 letters ("ALBANY KILL"): use the real spawn name when we can
    local arch = GetEntityArchetypeName and GetEntityArchetypeName(veh) or ''
    if arch ~= '' then
        d.spawn = arch
        d.name = (arch:gsub('_', ' '):gsub('(%a)([%w]*)', function(a, b) return a:upper() .. b:lower() end))
    end

    -- liveries: the car's own + Apex Studio packs painted onto its slots
    local packs = lib.callback.await('corlinks_vipgarage:packs', false, model) or {}
    local ln = GetVehicleLiveryCount(veh)
    d.liveries = {}
    if ln and ln > 0 then
        for i = 0, ln - 1 do
            local pk = packs[i] or packs[tostring(i)]
            d.liveries[#d.liveries + 1] = { i = i, label = pk and pk.label or label(GetLiveryName(veh, i), 'Livery ' .. (i + 1)),
                apex = pk and true or false, pack = pk and pk.pack or nil, live = pk and pk.state == 'started' or nil,
                img = pk and pk.img and ('https://cfx-nui-%s/%s'):format(pk.pack, pk.img) or nil, tex = pk and pk.tex or nil }
        end
    end
    -- packs that were given a slot this car doesn't have yet (needs <name>_sign_N added to the car's .ytd)
    for k, pk in pairs(packs) do
        local i = tonumber(k)
        if i and i >= (ln or 0) then
            d.liveries[#d.liveries + 1] = { i = i, label = pk.label, apex = true, noslot = true, live = pk.state == 'started',
                img = pk.img and ('https://cfx-nui-%s/%s'):format(pk.pack, pk.img) or nil, tex = pk.tex, txd = pk.txd }
        end
    end
    table.sort(d.liveries, function(a, b) return a.i < b.i end)
    d.livery = GetVehicleLivery(veh)
    local ml = GetNumVehicleMods(veh, 48)
    d.modLiveries = {}
    for i = -1, ml - 1 do
        d.modLiveries[#d.modLiveries + 1] = { i = i, label = i == -1 and 'None' or label(GetModTextLabel(veh, 48, i), 'Livery ' .. (i + 1)) }
    end
    d.modLivery = GetVehicleMod(veh, 48)
    d.liveryOnly = (ln or 0) <= 0 and ml <= 0

    -- paint
    local pt, pc, _ = GetVehicleModColor_1(veh)
    local st = GetVehicleModColor_2(veh)
    local r1, g1, b1 = GetVehicleCustomPrimaryColour(veh)
    local r2, g2, b2 = GetVehicleCustomSecondaryColour(veh)
    local pearl, wheel = GetVehicleExtraColours(veh)
    d.paint = { primaryType = pt, secondaryType = st, p = { r1, g1, b1 }, s = { r2, g2, b2 }, pearl = pearl, wheel = wheel,
        interior = GetVehicleInteriorColor(veh), dash = GetVehicleDashboardColor(veh), tint = GetVehicleWindowTint(veh) }

    -- every mod slot this car actually has
    d.mods = {}
    for t = 0, 48 do
        local n = MOD_NAMES[t] and GetNumVehicleMods(veh, t) or 0
        if n > 0 and t ~= 48 then
            local opts = { { i = -1, label = (GROUP[t] == 'perf') and 'Stock' or 'Stock / None' } }
            for i = 0, n - 1 do opts[#opts + 1] = { i = i, label = label(GetModTextLabel(veh, t, i), (GROUP[t] == 'perf' and ('Level ' .. (i + 1)) or (MOD_NAMES[t] .. ' ' .. (i + 1)))) } end
            d.mods[#d.mods + 1] = { t = t, name = MOD_NAMES[t], group = GROUP[t] or 'body', cur = GetVehicleMod(veh, t), opts = opts }
        end
    end
    d.toggles = { turbo = IsToggleModOn(veh, 18), smoke = IsToggleModOn(veh, 20), xenon = IsToggleModOn(veh, 22) }
    d.wheelType = GetVehicleWheelType(veh)
    d.wheelTypes = {}
    for k, v in pairs(WHEEL_TYPES) do d.wheelTypes[#d.wheelTypes + 1] = { i = k, label = v } end
    table.sort(d.wheelTypes, function(a, b) return a.i < b.i end)
    d.customTyres = GetVehicleModVariation(veh, 23)
    d.xenonColor = GetVehicleXenonLightsColor(veh)
    local nr, ng, nb = GetVehicleNeonLightsColour(veh)
    d.neon = { on = IsVehicleNeonLightEnabled(veh, 0) or IsVehicleNeonLightEnabled(veh, 2), rgb = { nr, ng, nb } }
    local sr, sg, sb = GetVehicleTyreSmokeColor(veh)
    d.smoke = { sr, sg, sb }
    d.extras = {}
    for e = 0, 20 do if DoesExtraExist(veh, e) then d.extras[#d.extras + 1] = { i = e, on = IsVehicleExtraTurnedOn(veh, e) } end end
    d.plateIndex = GetVehicleNumberPlateTextIndex(veh)

    -- workshop extras (the stuff a normal mod shop never shows you)
    d.dirt = math.floor((GetVehicleDirtLevel(veh) or 0) + 0.5)
    d.drift = GetDriftTyresEnabled and GetDriftTyresEnabled(veh) or false
    d.bpTyres = not GetVehicleTyresCanBurst(veh)
    local rc = GetVehicleRoofLiveryCount and GetVehicleRoofLiveryCount(veh) or 0
    d.roof = { count = rc or 0, cur = (rc or 0) > 0 and GetVehicleRoofLivery(veh) or -1 }
    d.neonSides = {}
    for i = 0, 3 do d.neonSides[i + 1] = IsVehicleNeonLightEnabled(veh, i) end
    d.doors = {}
    local DOOR = { [0] = 'Front left', [1] = 'Front right', [2] = 'Rear left', [3] = 'Rear right', [4] = 'Hood', [5] = 'Trunk' }
    for i = 0, 5 do
        if GetIsDoorValid(veh, i) and not IsVehicleDoorDamaged(veh, i) then
            d.doors[#d.doors + 1] = { i = i, name = DOOR[i], open = GetVehicleDoorAngleRatio(veh, i) > 0.1 }
        end
    end
    d.engineOn = GetIsVehicleEngineRunning(veh)
    local _, lo, hi = GetVehicleLightsState(veh)
    d.lightsOn = lo == 1 or hi == 1
    d.class = GetLabelText('VEH_CLASS_' .. GetVehicleClass(veh))
    d.health = { body = math.floor(GetVehicleBodyHealth(veh) / 10), engine = math.floor(GetVehicleEngineHealth(veh) / 10) }
    -- live performance read-out (changes as you fit engine / brakes / gearbox / turbo / tyres)
    local function pct(v, max) return math.max(0, math.min(100, math.floor((v or 0) / max * 100 + 0.5))) end
    d.stats = {
        speed = pct(GetVehicleEstimatedMaxSpeed(veh), 60.0), kmh = math.floor((GetVehicleEstimatedMaxSpeed(veh) or 0) * 3.6 + 0.5),
        accel = pct(GetVehicleAcceleration(veh), 0.5), brake = pct(GetVehicleMaxBraking(veh), 1.6), grip = pct(GetVehicleMaxTraction(veh), 3.5),
    }
    return d
end

-- ─── camera ──────────────────────────────────────────────────────────────
local function placeCam()
    if not cam or not DoesEntityExist(veh) then return end
    local c = GetEntityCoords(veh)
    local h = math.rad(yaw + GetEntityHeading(veh)); local p = math.rad(pitch)
    local x = c.x + math.cos(h) * math.cos(p) * dist
    local y = c.y + math.sin(h) * math.cos(p) * dist
    local z = c.z + focusZ + math.sin(p) * dist
    SetCamCoord(cam, x, y, z)
    PointCamAtCoord(cam, c.x, c.y, c.z + focusZ)
end

local VIEWS = { front = { 90, 8, 5.5, .35 }, rear = { 270, 10, 5.8, .4 }, left = { 180, 6, 5.2, .3 }, right = { 0, 6, 5.2, .3 },
    top = { 200, 70, 7.5, 0 }, wheel = { 150, 2, 2.8, -.25 }, hero = { 200, 12, 6.5, .4 } }

-- ─── open / close ────────────────────────────────────────────────────────
-- apex_hud is hidden while the editor is open (handled by apex_hud/client/cl_corlinks_mapsync.lua)
local function hud(hide) TriggerEvent('corlinks:hideHud', hide) end

local function close(revert)
    if not open then return end
    open = false
    SetNuiFocus(false, false)
    SendNUIMessage({ a = 'close' })
    hud(false)
    if DoesEntityExist(veh) then SetVehicleDoorsShut(veh, false); SetVehicleLights(veh, 0) end
    if revert and original and DoesEntityExist(veh) then lib.setVehicleProperties(veh, original) end
    if DoesEntityExist(veh) then FreezeEntityPosition(veh, false) end
    if cam then RenderScriptCams(false, true, 600, true, true); DestroyCam(cam, false); cam = nil end
    veh, original = 0, nil
end

local function openEditor()
    if open then return end
    if not lib.callback.await('corlinks_vipgarage:allowed', false) then return notify('This is a VIP / admin feature.', 'error') end
    local ped = cache.ped
    local v = GetVehiclePedIsIn(ped, false)
    if v == 0 then v = lib.getClosestVehicle(GetEntityCoords(ped), Config.Range, true) or 0 end
    if v == 0 then return notify('Sit in a vehicle or stand next to one.', 'error') end
    NetworkRequestControlOfEntity(v)
    local t = GetGameTimer(); while not NetworkHasControlOfEntity(v) and GetGameTimer() - t < 1500 do Wait(0); NetworkRequestControlOfEntity(v) end
    veh, open = v, true
    original = lib.getVehicleProperties(veh)
    FreezeEntityPosition(veh, true)
    SetVehicleEngineOn(veh, true, true, false)
    yaw, pitch, dist, focusZ = 200.0, 12.0, 6.5, 0.4
    cam = CreateCam('DEFAULT_SCRIPTED_CAMERA', true)
    SetCamFov(cam, 45.0); placeCam(); RenderScriptCams(true, true, 700, true, true)
    SetNuiFocus(true, true)
    hud(true)
    SendNUIMessage({ a = 'open', d = build() })
    CreateThread(function()
        while open do
            HideHudAndRadarThisFrame()
            DisableAllControlActions(0)
            placeCam()
            if not DoesEntityExist(veh) then close(false) end
            Wait(0)
        end
    end)
end
RegisterCommand(Config.Command, openEditor, false)
TriggerEvent('chat:addSuggestion', '/' .. Config.Command, 'VIP / admin: premium vehicle editor (liveries, respray, every mod)')

-- ─── NUI ─────────────────────────────────────────────────────────────────
RegisterNUICallback('cam', function(d, cb)
    if d.view and VIEWS[d.view] then local v = VIEWS[d.view]; yaw, pitch, dist, focusZ = v[1], v[2], v[3], v[4]
    else
        yaw = (yaw - (tonumber(d.dx) or 0) * 0.35) % 360
        pitch = math.max(-5.0, math.min(75.0, pitch + (tonumber(d.dy) or 0) * 0.25))
        dist = math.max(2.2, math.min(14.0, dist + (tonumber(d.dz) or 0) * 0.006))
    end
    cb(1)
end)

local function rgb(t) return math.floor(tonumber(t[1]) or 0), math.floor(tonumber(t[2]) or 0), math.floor(tonumber(t[3]) or 0) end

RegisterNUICallback('set', function(d, cb)
    if not open or not DoesEntityExist(veh) then return cb({}) end
    NetworkRequestControlOfEntity(veh)
    SetVehicleModKit(veh, 0)
    local op, v = d.op, d.v
    if op == 'livery' then
        SetVehicleLivery(veh, v)
        Entity(veh).state:set('livery_lock', v, true)  -- Apex packs leave this car's choice alone
    elseif op == 'modLivery' then SetVehicleMod(veh, 48, v, false)
    elseif op == 'mod' then
        if d.t == 23 then SetVehicleMod(veh, 23, v, GetVehicleModVariation(veh, 23)) else SetVehicleMod(veh, d.t, v, false) end
        if d.t == 23 or d.t == 24 then yaw, pitch, dist, focusZ = 150, 2, 2.8, -.25 end
    elseif op == 'toggle' then ToggleVehicleMod(veh, ({ turbo = 18, smoke = 20, xenon = 22 })[d.k], v == true)
    elseif op == 'primary' then local r, g, b = rgb(v); SetVehicleCustomPrimaryColour(veh, r, g, b)
    elseif op == 'secondary' then local r, g, b = rgb(v); SetVehicleCustomSecondaryColour(veh, r, g, b)
    elseif op == 'paintType' then
        local _, c1 = GetVehicleModColor_1(veh); local _, c2 = GetVehicleModColor_2(veh)
        if d.which == 'secondary' then SetVehicleModColor_2(veh, v, c2 or 0) else SetVehicleModColor_1(veh, v, c1 or 0, 0) end
        -- keep the custom colour on top of the new finish
        local r1, g1, b1 = GetVehicleCustomPrimaryColour(veh); local r2, g2, b2 = GetVehicleCustomSecondaryColour(veh)
        SetVehicleCustomPrimaryColour(veh, r1, g1, b1); SetVehicleCustomSecondaryColour(veh, r2, g2, b2)
    elseif op == 'pearl' then local _, w = GetVehicleExtraColours(veh); SetVehicleExtraColours(veh, v, w)
    elseif op == 'wheelColor' then local p = GetVehicleExtraColours(veh); SetVehicleExtraColours(veh, p, v)
    elseif op == 'interior' then SetVehicleInteriorColor(veh, v)
    elseif op == 'dash' then SetVehicleDashboardColor(veh, v)
    elseif op == 'tint' then SetVehicleWindowTint(veh, v)
    elseif op == 'wheelType' then SetVehicleWheelType(veh, v); SetVehicleMod(veh, 23, -1, false)
    elseif op == 'tyres' then SetVehicleMod(veh, 23, GetVehicleMod(veh, 23), v == true)
    elseif op == 'xenonColor' then ToggleVehicleMod(veh, 22, true); SetVehicleXenonLightsColor(veh, v)
    elseif op == 'neon' then for i = 0, 3 do SetVehicleNeonLightEnabled(veh, i, v == true) end
    elseif op == 'neonColor' then local r, g, b = rgb(v); SetVehicleNeonLightsColour(veh, r, g, b)
    elseif op == 'smokeColor' then ToggleVehicleMod(veh, 20, true); local r, g, b = rgb(v); SetVehicleTyreSmokeColor(veh, r, g, b)
    elseif op == 'extra' then SetVehicleExtra(veh, d.e, v and 0 or 1)
    elseif op == 'plateIndex' then SetVehicleNumberPlateTextIndex(veh, v)
    elseif op == 'repair' then SetVehicleFixed(veh); SetVehicleDirtLevel(veh, 0.0)
    elseif op == 'dirt' then SetVehicleDirtLevel(veh, math.max(0.0, math.min(15.0, (tonumber(v) or 0) + 0.0)))
    elseif op == 'drift' then if SetDriftTyresEnabled then SetDriftTyresEnabled(veh, v == true) end
    elseif op == 'bpTyres' then SetVehicleTyresCanBurst(veh, v ~= true)
    elseif op == 'roof' then SetVehicleRoofLivery(veh, v)
    elseif op == 'neonSide' then SetVehicleNeonLightEnabled(veh, d.i, v == true)
    elseif op == 'door' then
        if v then SetVehicleDoorOpen(veh, d.i, false, false) else SetVehicleDoorShut(veh, d.i, false) end
        if d.i == 4 then yaw, pitch, dist, focusZ = 90, 25, 5.0, .5 elseif d.i == 5 then yaw, pitch, dist, focusZ = 270, 22, 5.2, .5 end
    elseif op == 'doorsAll' then
        for i = 0, 5 do if v then SetVehicleDoorOpen(veh, i, false, false) else SetVehicleDoorShut(veh, i, false) end end
    elseif op == 'engine' then SetVehicleEngineOn(veh, v == true, true, true)
    elseif op == 'lightsPreview' then SetVehicleLights(veh, v and 2 or 1)
    elseif op == 'horn' then StartVehicleHorn(veh, 900, GetHashKey("HELDDOWN"), false)
    elseif op == 'wash' then SetVehicleDirtLevel(veh, 0.0); WashDecalsFromVehicle(veh, 1.0)
    elseif op == 'reset' then
        for t = 0, 48 do if MOD_NAMES[t] then SetVehicleMod(veh, t, -1, false) end end
        for _, k in ipairs({ 18, 20, 22 }) do ToggleVehicleMod(veh, k, false) end
        ClearVehicleCustomPrimaryColour(veh); ClearVehicleCustomSecondaryColour(veh)
        SetVehicleWindowTint(veh, 0); for i = 0, 3 do SetVehicleNeonLightEnabled(veh, i, false) end
    end
    cb({ d = build() })
end)

RegisterNUICallback('save', function(_, cb)
    if not open then return cb({}) end
    local props = lib.getVehicleProperties(veh)
    local r = lib.callback.await('corlinks_vipgarage:save', false, props) or {}
    notify(r.saved and 'Saved to this car - it will look like this from the garage too.' or 'Applied. (Not an owned car, so it will not be saved to a garage.)', 'success')
    original = props
    close(false)
    cb(r)
end)
RegisterNUICallback('cancel', function(_, cb) close(true); cb(1) end)

AddEventHandler('onResourceStop', function(r) if r == GetCurrentResourceName() then close(true) end end)
