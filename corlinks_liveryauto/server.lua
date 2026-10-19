-- corlinks_liveryauto v1.4 · every Apex Vehicle Studio pack in [Corlink_Liverys] is live for EVERYONE.
--  * finds packs through FiveM itself (no shell commands - those are blocked on this host)
--  * a new export appears  -> refresh + start it
--  * an export is updated  -> upgrade + restart it
--  * every pack is upgraded so the livery shows on every car, for every player, with no restarts,
--    and liveries picked in the VIP editor stay on the car
--  * v1.4: every pack gets its OWN texture names (two exports with the same internal name used to
--    overwrite each other), and packs are matched to the car's real spawn name via vehicles.meta
local FOLDER = '[Corlinks_Liverys]'  -- shown in messages; ANY bracket folder with 'liver' in its name counts
-- (the server's folder is [Corlinks_Liverys], the PC backup's is [Corlink_Liverys] - both match)
local function inLiveryFolder(path) return path:find('/%[[^/%]]*liver[^/%]]*%]/') ~= nil end
local EVERY  = 15                     -- seconds between checks

local RUNTIME = [==[
-- corlinks-livery v8 · rewritten by corlinks_liveryauto from the Apex Vehicle Studio export
-- (the original is kept next to it as client.lua.apex). Re-attaches the textures every time a car
-- of this model streams in, so everyone sees the livery without restarting anything.
%s

%s

-- texture dictionary -> the car spawn names that use it (read from vehicles.meta by corlinks_liveryauto)
local ALIASES = %s

local models, liveries, applied = {}, {}, {}
for _, e in ipairs(REPLACEMENTS) do
    for _, p in ipairs(e.pairs) do
        local names = { p.txd }
        for _, m in ipairs(ALIASES[p.txd:lower()] or {}) do names[#names + 1] = m end
        local n = tostring(p.txn):match('_sign_(%%d+)$')
        for _, nm in ipairs(names) do
            local h = GetHashKey(nm)
            models[h] = models[h] or {}
            table.insert(models[h], { txd = p.txd, txn = p.txn, rt = e.rt })
            if n then liveries[h] = tonumber(n) - 1 end
        end
    end
end

local txd
local function build()
    txd = txd or CreateRuntimeTxd(RT_TXD)
    if not txd or txd == 0 then txd = nil; return false end
    for _, e in ipairs(REPLACEMENTS) do
        if not e.made then
            local t = CreateRuntimeTextureFromImage(txd, e.rt, e.file)
            e.made = t ~= nil and t ~= 0
        end
    end
    return true
end

-- The game ignores a texture swap registered while the car's texture dictionary is not loaded yet
-- (that is why a pack used to need a restart after the first car spawned). So: load the car's
-- dictionary first and keep it loaded, then (re)register the swap.
local loadedTxd = {}
local function preload(t)
    if loadedTxd[t] then return true end
    if not RequestStreamedTextureDict then return false end
    RequestStreamedTextureDict(t, false)
    local s = GetGameTimer()
    while not HasStreamedTextureDictLoaded(t) and GetGameTimer() - s < 5000 do Wait(50) end
    loadedTxd[t] = HasStreamedTextureDictLoaded(t)
    return loadedTxd[t]
end

local function attach(h, force)
    for _, r in ipairs(models[h] or {}) do
        if force then
            -- exactly what a pack restart does (the only thing that reliably worked):
            -- take the swap off, give the game a moment, put it back while the car is loaded
            RemoveReplaceTexture(r.txd, r.txn)
            RemoveReplaceTexture(r.txd .. '+hi', r.txn)
        end
    end
    if force then Wait(0) end   -- one frame: no visible flash
    for _, r in ipairs(models[h] or {}) do
        AddReplaceTexture(r.txd, r.txn, RT_TXD, r.rt)
        AddReplaceTexture(r.txd .. '+hi', r.txn, RT_TXD, r.rt)   -- close-up textures
        applied[r.txd] = r
    end
end

-- /liveryfix (corlinks_liveryauto) re-applies every pack on cars around you, no restart needed
AddEventHandler('corlinks_liveryauto:force', function()
    for h in pairs(models) do attach(h, true) end
end)

CreateThread(function()
    while not NetworkIsSessionStarted() do Wait(500) end
    Wait(1500)
    while not build() do Wait(1000) end
    local done = {}
    for _, list in pairs(models) do
        for _, r in ipairs(list) do
            if not done[r.txd] then done[r.txd] = true; preload(r.txd) end
        end
    end
    for h in pairs(models) do attach(h, true) end
    print(('^2[%%s]^7 livery textures ready'):format(GetCurrentResourceName()))
    local seen, last, pend, had = {}, {}, {}, {}
    while true do
        Wait(500)
        local now, me, present, here = GetGameTimer(), GetEntityCoords(PlayerPedId()), {}, {}
        for _, veh in ipairs(GetGamePool('CVehicle')) do
            local h = GetEntityModel(veh)
            if models[h] then
                present[veh] = true
                here[h] = true
                if not seen[veh] and not had[h] and not pend[h] then
                    -- first car of this model around you: re-apply ONCE after it has loaded
                    -- (cars that appear while one is already showing the design inherit it - nothing to do)
                    pend[h] = { now + 1500 }
                elseif now - (last[h] or 0) > 4000 and #(GetEntityCoords(veh) - me) < 150.0 then
                    attach(h); last[h] = now
                end
                -- never change which livery a car uses: that is the player's choice (VIP editor / garage),
                -- this pack only provides the design for its own slot
            end
        end
        for h, times in pairs(pend) do
            if times[1] and now >= times[1] then
                table.remove(times, 1)
                for _, r in ipairs(models[h]) do loadedTxd[r.txd] = nil; preload(r.txd) end
                attach(h, true); last[h] = GetGameTimer()
            end
            if #times == 0 then pend[h] = nil end
        end
        seen, had = present, here
    end
end)

AddEventHandler('onResourceStop', function(res)
    if res ~= GetCurrentResourceName() then return end
    for _, r in pairs(applied) do
        RemoveReplaceTexture(r.txd, r.txn)
        RemoveReplaceTexture(r.txd .. '+hi', r.txn)
    end
    for t in pairs(loadedTxd) do SetStreamedTextureDictAsNoLongerNeeded(t) end
end)
]==]

-- ─── vehicles.meta: which car spawn names use which texture dictionary ───────────────
-- (an export names the TEXTURE dictionary, e.g. albany_killer; the car can be spawned under
--  another name, so the VIP editor and the auto-livery need this map)
local txdMap, txdAt = {}, -1e9
local function readMeta(res, path, out)
    local xml = LoadResourceFile(res, path)
    if not xml or xml == '' then return end
    for item in xml:gmatch('<[Ii]tem>(.-)</[Ii]tem>') do
        local m = item:match('<modelName>%s*([^<%s]+)%s*</modelName>')
        local t = item:match('<txdName>%s*([^<%s]+)%s*</txdName>')
        if m and t then
            t, m = t:lower(), m:lower()
            out[t] = out[t] or {}
            local dup = false
            for _, x in ipairs(out[t]) do if x == m then dup = true end end
            if not dup then table.insert(out[t], m) end
        end
    end
end
local COMMON = { 'vehicles.meta', 'data/vehicles.meta', 'meta/vehicles.meta', 'stream/vehicles.meta', 'data/vehicles/vehicles.meta' }
local function buildTxdMap()
    local out = {}
    for i = 0, GetNumResources() - 1 do
        local res = GetResourceByFindIndex(i)
        if res then
            local man = (LoadResourceFile(res, 'fxmanifest.lua') or '') .. '\n' .. (LoadResourceFile(res, '__resource.lua') or '')
            local tried = {}
            for path in man:gmatch("['\"]VEHICLE_METADATA_FILE['\"]%s*,?%s*['\"]([^'\"]+)['\"]") do
                if not path:find('*', 1, true) then tried[path] = true; readMeta(res, path, out) end
            end
            if man:find('VEHICLE_METADATA_FILE', 1, true) then
                for _, path in ipairs(COMMON) do if not tried[path] then readMeta(res, path, out) end end
            end
        end
    end
    return out
end
local function TxdModels()
    if GetGameTimer() - txdAt > 300000 then txdMap, txdAt = buildTxdMap(), GetGameTimer() end
    return txdMap
end
exports('TxdModels', TxdModels)

local function luaList(t)
    local parts = {}
    for k, list in pairs(t) do
        local q = {}
        for _, m in ipairs(list) do q[#q + 1] = ('%q'):format(m) end
        parts[#parts + 1] = ('[%q] = { %s }'):format(k, table.concat(q, ', '))
    end
    return '{ ' .. table.concat(parts, ', ') .. ' }'
end

local MARK = 'corlinks-livery v7'

-- REPLACEMENTS block of a pack script (original Apex export or one we already rewrote)
local function block(src)
    local s1 = src:find('local%s+REPLACEMENTS%s*=%s*{')
    local e1 = s1 and src:find('\n}', s1, true)
    if not s1 or not e1 or not src:find('local%s+RT_TXD%s*=') then return nil end
    return src:sub(s1, e1 + 1)
end

-- every "<something>_sign_N" surface a pack paints: { key = 'txd|base', txd, base, n }
local function signs(b)
    local out = {}
    for txd, txn in b:gmatch('txd%s*=%s*"([^"]+)"%s*,%s*txn%s*=%s*"([^"]+)"') do
        local base, n = txn:match('^(.-_sign_)(%d+)$')
        if base then out[#out + 1] = { key = txd:lower() .. '|' .. base:lower(), txd = txd, base = base, n = tonumber(n) } end
    end
    return out
end

-- build the pack script: own runtime names, real car names, and the livery slot this pack was given
local function makeRuntime(name, src, slots)
    local b = block(src)
    if not b then return nil end
    local id = name:lower():gsub('[^%w_]', '_')
    local k = 0
    b = b:gsub('rt%s*=%s*"[^"]*"', function() k = k + 1; return ('rt = "%s_%d"'):format(id, k) end)
    b = b:gsub('(txd%s*=%s*")([^"]+)("%s*,%s*txn%s*=%s*")([^"]+)(")', function(a, txd, c, txn, e)
        local base = txn:match('^(.-_sign_)%d+$')
        local want = base and slots and slots[txd:lower() .. '|' .. base:lower()]
        return a .. txd .. c .. (want and (base .. want) or txn) .. e
    end)
    local map, used = TxdModels(), {}
    for t in b:gmatch('txd%s*=%s*"([^"]+)"') do
        local l = t:lower()
        if map[l] then
            local keep = {}
            for _, m in ipairs(map[l]) do if m ~= l then keep[#keep + 1] = m end end
            if #keep > 0 then used[l] = keep end
        end
    end
    return RUNTIME:format(("local RT_TXD = 'corlinks_liv_%s'"):format(id), b, luaList(used))
end

local function packs()
    local out = {}
    for i = 0, GetNumResources() - 1 do
        local n = GetResourceByFindIndex(i)
        if n then
            local p = (GetResourcePath(n) or ''):gsub('\\', '/'):lower()
            if inLiveryFolder(p) and (LoadResourceFile(n, 'client.lua') or ''):find('AddReplaceTexture', 1, true) then
                out[#out + 1] = n
            end
        end
    end
    table.sort(out, function(a, b) return a:lower() < b:lower() end)
    return out
end

-- cheap fingerprint of a pack: its original script + the size of every texture it uses
local function stamp(n, src)
    local parts = { #src, (src:gsub('%s', '')):sub(-300) }
    local dir = GetResourcePath(n)
    for file in src:gmatch("file%s*=%s*['\"]([^'\"]+)['\"]") do
        local f = io and io.open and io.open(dir .. '/' .. file, 'rb')
        if f then parts[#parts + 1] = f:seek('end'); f:close() else parts[#parts + 1] = 'x' end
    end
    return table.concat(parts, '|')
end

-- write straight to disk (and read it back from disk) so a cached copy can never fool us
local function diskWrite(n, file, data)
    local path = (GetResourcePath(n) or '') .. '/' .. file
    local f, err = io.open(path, 'wb')
    if not f then return false, err end
    f:write(data); f:close()
    local r = io.open(path, 'rb')
    if not r then return false, 'could not read back ' .. path end
    local back = r:read('a'); r:close()
    if back ~= data then return false, 'file on disk did not change: ' .. path end
    return true
end

local function save(n, cur, new)
    local dir = GetResourcePath(n) or ''
    local a = io.open(dir .. '/client.lua.apex', 'rb')
    if a then a:close() elseif not cur:find('corlinks-livery', 1, true) then
        diskWrite(n, 'client.lua.apex', cur)                          -- keep the untouched Apex export
    end
    local ok, err = diskWrite(n, 'client.lua', new)
    if not ok then
        -- fall back to FiveM's own writer
        SaveResourceFile(n, 'client.lua', new, -1)
        local r = io.open(dir .. '/client.lua', 'rb')
        local back = r and r:read('a'); if r then r:close() end
        if back == new then return true end
        print(('^1[liveryauto] could NOT save %s/client.lua: %s^7'):format(n, tostring(err)))
        return false
    end
    return true
end

-- FiveM can't write files on this host, so the packs are converted by /root/corlinks_liverys.py (cron, every minute).
-- This side only watches: a pack whose client.lua changed is restarted for everyone, a new pack is started.
local function readDisk(n, f)
    local h = io.open((GetResourcePath(n) or '') .. '/' .. f, 'rb')
    if not h then return nil end
    local d = h:read('a'); h:close(); return d
end

local seen = {}
local busy, scans = false, 0
local function scan(manual)
    if busy then return end
    busy = true
    scans = scans + 1
    if manual or scans == 1 or scans % 4 == 0 then   -- brand-new export folders: every ~1 min (refresh causes a short hitch)
        ExecuteCommand('refresh')
        Wait(500)
    end
    local list, changed, rows = packs(), 0, {}
    for _, n in ipairs(list) do
        local cur = readDisk(n, 'client.lua') or LoadResourceFile(n, 'client.lua') or ''
        local ready = cur:find('corlinks-livery', 1, true) ~= nil
        local key = #cur .. ':' .. (cur:gsub('%s', '')):sub(-400)
        local state = GetResourceState(n)
        if ready then
            if state ~= 'started' then
                ExecuteCommand('ensure ' .. n); changed = changed + 1
                print(('^2[liveryauto]^7 livery pack ^5%s^7 is now live for everyone'):format(n))
            elseif (seen[n] and seen[n] ~= key) or (not seen[n] and scans == 1) then
                -- changed on disk, or first look after liveryauto (re)started: the running copy may be an old version
                ExecuteCommand('restart ' .. n); changed = changed + 1
                print(('^2[liveryauto]^7 livery pack ^5%s^7 updated for everyone'):format(n))
            end
            seen[n] = key
        end
        local sl = {}
        for txd, txn in cur:gmatch('txd%s*=%s*"([^"]+)"%s*,%s*txn%s*=%s*"([^"]+)"') do
            local num = txn:match('_sign_(%d+)$'); if num then sl[#sl + 1] = txd .. ' livery ' .. num end
        end
        rows[#rows + 1] = ('   %-32s %s%s'):format(n, #sl > 0 and table.concat(sl, ', ') or '(full texture pack)', ready and '' or '   (waiting for the converter - up to 1 min)')
    end
    if changed > 0 then TriggerClientEvent('corlinks_liveryauto:refresh', -1) end
    if manual then
        print(('^2[liveryauto]^7 %d livery pack(s) in %s:'):format(#list, FOLDER))
        for _, r in ipairs(rows) do print(r) end
    end
    busy = false
end

CreateThread(function()
    Wait(10000)
    while true do
        local ok, err = pcall(scan)
        if not ok then busy = false; print('^1[liveryauto]^7 ' .. tostring(err)) end
        Wait(EVERY * 1000)
    end
end)

RegisterCommand('liveryscan', function(src) if src == 0 then scan(true) end end, true)
