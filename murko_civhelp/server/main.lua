-- Karma persistence and validation. Karma is stored with resource KVP keyed by the
-- player's license identifier, so no database is needed.

local RESOURCE = GetCurrentResourceName()

local active = {}     -- [src] = { id = scenarioId, offeredAt = os.time() }
local lastReward = {} -- [src] = os.time() of the last positive karma

local function getIdentifier(src)
    local id = GetPlayerIdentifierByType(src, 'license')
    if id then
        return id
    end
    for _, identifier in ipairs(GetPlayerIdentifiers(src)) do
        if identifier:sub(1, 8) == 'license:' then
            return identifier
        end
    end
    return nil
end

local function kvpKey(identifier)
    return 'karma:' .. identifier
end

local function GetKarma(src)
    local identifier = getIdentifier(src)
    if not identifier then
        return 0
    end
    return GetResourceKvpInt(kvpKey(identifier))
end

local function SetKarma(src, value)
    local identifier = getIdentifier(src)
    if not identifier then
        return 0
    end
    value = math.floor(tonumber(value) or 0)
    SetResourceKvpInt(kvpKey(identifier), value)
    Player(src).state:set('karma', value, true)
    return value
end

local function AddKarma(src, delta, reason)
    delta = math.floor(tonumber(delta) or 0)
    local total = SetKarma(src, GetKarma(src) + delta)
    TriggerEvent('murko_civhelp:karmaChanged', src, total, delta, reason)
    if Config.Debug then
        print(('[%s] %s (%d) karma %+d -> %d (%s)'):format(RESOURCE, GetPlayerName(src), src, delta, total, reason or '?'))
    end
    return total
end

exports('GetKarma', GetKarma)
exports('SetKarma', function(src, value)
    local total = SetKarma(src, value)
    TriggerClientEvent('murko_civhelp:karmaSync', src, total, false)
    return total
end)
exports('AddKarma', function(src, delta, reason)
    local total = AddKarma(src, delta, reason)
    TriggerClientEvent('murko_civhelp:karmaResult', src, 'external', math.floor(tonumber(delta) or 0), total)
    return total
end)
exports('GetKarmaRank', function(src)
    return GetKarmaRank(GetKarma(src))
end)

RegisterNetEvent('murko_civhelp:requestKarma', function(announce)
    local src = source
    local total = GetKarma(src)
    Player(src).state:set('karma', total, true)
    TriggerClientEvent('murko_civhelp:karmaSync', src, total, announce == true)
end)

RegisterNetEvent('murko_civhelp:offered', function(id)
    local src = source
    if type(id) ~= 'string' or not Config.Scenarios[id] then
        return
    end
    active[src] = { id = id, offeredAt = os.time() }
end)

RegisterNetEvent('murko_civhelp:report', function(id, outcome, factor)
    local src = source
    local entry = active[src]
    if not entry or entry.id ~= id then
        return
    end
    active[src] = nil

    local now = os.time()
    local delta
    if outcome == 'success' then
        if now - entry.offeredAt < Config.Karma.MinScenarioSeconds then
            return
        end
        if lastReward[src] and now - lastReward[src] < Config.Karma.MinSecondsBetweenRewards then
            return
        end
        factor = math.max(0.25, math.min(1.0, tonumber(factor) or 1.0))
        delta = math.max(1, math.floor((Config.Scenarios[id].karma or 10) * factor + 0.5))
        lastReward[src] = now
    elseif outcome == 'ignored' then
        delta = Config.Karma.Ignored
    elseif outcome == 'abandoned' then
        delta = Config.Karma.Abandoned
    elseif outcome == 'failed' then
        delta = Config.Karma.Failed
    else
        return -- 'cancelled' and anything unknown: no karma change
    end

    local total = AddKarma(src, delta, ('%s:%s'):format(outcome, id))
    TriggerClientEvent('murko_civhelp:karmaResult', src, outcome, delta, total)
end)

AddEventHandler('playerDropped', function()
    active[source] = nil
    lastReward[source] = nil
end)

-- Admin/testing: /civhelp_test [scenario]. Restricted: grant it with
--   add_ace group.admin command.civhelp_test allow
RegisterCommand('civhelp_test', function(src, args)
    if src == 0 then
        print('Run this command in-game.')
        return
    end
    local id = args[1]
    if id and not Config.Scenarios[id] then
        local ids = {}
        for scenarioId in pairs(Config.Scenarios) do
            ids[#ids + 1] = scenarioId
        end
        table.sort(ids)
        TriggerClientEvent('chat:addMessage', src, { args = { 'civhelp', 'Unknown scenario. Options: ' .. table.concat(ids, ', ') } })
        return
    end
    TriggerClientEvent('murko_civhelp:force', src, id)
end, true)

-- Console: civhelp_setkarma <playerId> <value>
RegisterCommand('civhelp_setkarma', function(src, args)
    local target, value = tonumber(args[1]), tonumber(args[2])
    if not target or not value or not GetPlayerName(target) then
        print('Usage: civhelp_setkarma <playerId> <value>')
        return
    end
    local total = SetKarma(target, value)
    TriggerClientEvent('murko_civhelp:karmaSync', target, total, true)
    print(('Set karma of %s to %d'):format(GetPlayerName(target), total))
end, true)
