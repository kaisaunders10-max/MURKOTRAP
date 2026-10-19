-- corlinks_vipgarage · server: permission, Apex livery pack list, saving
local QBCore = exports['qb-core']:GetCoreObject()

local function staffGroups(src)
    local ids = {}
    for _, t in ipairs({ 'license', 'license2' }) do
        local v = GetPlayerIdentifierByType(src, t)
        if v then ids[#ids + 1] = v; ids[#ids + 1] = (v:gsub('^license2?:', '')) end
    end
    if #ids == 0 then return {} end
    local ok, rows = pcall(MySQL.query.await, ('SELECT group_name FROM apex_staff WHERE license IN (%s)'):format(('?,'):rep(#ids):sub(1, -2)), ids)
    return ok and rows or {}
end

-- returns true/false plus the reason (shown in the server console)
local function check(src)
    if IsPlayerAceAllowed(src, Config.Ace) then return true, 'ace ' .. Config.Ace end
    for _, a in ipairs(Config.AdminAces or {}) do
        if IsPlayerAceAllowed(src, a) then return true, 'ace ' .. a end
    end
    for _, p in ipairs(Config.QBPerms or {}) do
        local ok, has = pcall(QBCore.Functions.HasPermission, src, p)
        if ok and has then return true, 'qb ' .. p end
    end
    for _, r in ipairs(staffGroups(src)) do
        local g = tostring(r.group_name or ''):lower()
        for _, want in ipairs(Config.StaffGroups or {}) do
            if g:find(want, 1, true) then return true, 'staff group ' .. g end
        end
    end
    return false, 'no admin ace, qb permission or staff group'
end
local function allowed(src) return (check(src)) end

lib.callback.register('corlinks_vipgarage:allowed', function(src)
    local ok, why = check(src)
    print(('[corlinks_vipgarage] %s /%s -> %s (%s)'):format(GetPlayerName(src) or src, Config.Command, ok and 'ALLOWED' or 'DENIED', why))
    return ok
end)
-- console: vipcheck <id>   shows why someone can / can't open the editor
RegisterCommand('vipcheck', function(src, args)
    if src ~= 0 then return end
    local id = tonumber(args[1] or '')
    if not id or not GetPlayerName(id) then return print('usage: vipcheck <server id>') end
    local ok, why = check(id)
    print(('[corlinks_vipgarage] %s -> %s (%s)'):format(GetPlayerName(id), ok and 'ALLOWED' or 'DENIED', why))
end, true)

-- ─── Apex Vehicle Studio packs: which livery slot of which car each pack paints ──
local function nice(name) return (name:gsub('^[Oo]ld_', ''):gsub('^[Vv]eh_', ''):gsub('_', ' '):gsub('(%a)([%w]*)', function(a, b) return a:upper() .. b end)) end

local function scanPacks()
    -- found through FiveM itself (shell commands are blocked on this host)
    local out, want = {}, Config.LiveryFolder:lower()
    local aliases = {}
    if GetResourceState('corlinks_liveryauto') == 'started' then
        local ok, m = pcall(function() return exports.corlinks_liveryauto:TxdModels() end)
        if ok and type(m) == 'table' then aliases = m end
    end
    for i = 0, GetNumResources() - 1 do
        local pack = GetResourceByFindIndex(i)
        local path = pack and (GetResourcePath(pack) or ''):gsub('\\', '/'):lower() or ''
        -- any bracket folder with 'liver' in the name: server = [Corlinks_Liverys], PC backup = [Corlink_Liverys]
        if path:find('/' .. want .. '/', 1, true) or path:find('/%[[^/%]]*liver[^/%]]*%]/') then
            local src = LoadResourceFile(pack, 'client.lua') or ''
            -- each REPLACEMENTS entry: { file = 'tex_1.png', rt = ..., pairs = { { txd = .., txn = .._sign_N }, ... } }
            for file, body in src:gmatch("file%s*=%s*['\"]([^'\"]+)['\"](.-)}%s*}") do
              for txd, txn in body:gmatch('txd%s*=%s*"([^"]+)"%s*,%s*txn%s*=%s*"([^"]+)"') do
                local base, n = txn:match('^(.-_sign_)(%d+)$')
                if n then
                    -- keyed by model hash. The export names the TEXTURE dictionary (e.g. albany_killer);
                    -- the car can spawn under another name, so also key it by every spawn name that
                    -- uses that dictionary (vehicles.meta, via corlinks_liveryauto)
                    local names = { txd }
                    for _, m in ipairs(aliases[txd:lower()] or {}) do names[#names + 1] = m end
                    for _, nm in ipairs(names) do
                        local model = GetHashKey(nm)
                        out[model] = out[model] or {}
                        out[model][tonumber(n) - 1] = { pack = pack, label = nice(pack), state = GetResourceState(pack),
                            img = file, tex = base, txd = txd }
                    end
                end
              end
            end
        end
    end
    return out
end
lib.callback.register('corlinks_vipgarage:packs', function(src, model)
    if not allowed(src) then return {} end
    local all = scanPacks()
    return all[tonumber(model) or GetHashKey(tostring(model or ''))] or {}
end)

-- ─── save the look onto an owned car ──────────────────────────────────────
lib.callback.register('corlinks_vipgarage:save', function(src, props)
    if not allowed(src) or type(props) ~= 'table' or not props.plate then return { ok = false, err = 'Not allowed.' } end
    if not Config.SaveOwned then return { ok = true, saved = false } end
    local plate = tostring(props.plate):gsub('^%s+', ''):gsub('%s+$', '')
    local row = MySQL.single.await('SELECT plate, mods FROM player_vehicles WHERE plate = ? OR plate = ? LIMIT 1', { plate, props.plate })
    if not row then return { ok = true, saved = false } end
    local old = type(row.mods) == 'string' and (json.decode(row.mods) or {}) or {}
    for k, v in pairs(props) do old[k] = v end
    MySQL.update.await('UPDATE player_vehicles SET mods = ? WHERE plate = ?', { json.encode(old), row.plate })
    print(('[corlinks_vipgarage] %s saved the look of %s'):format(GetPlayerName(src), row.plate))
    return { ok = true, saved = true }
end)
