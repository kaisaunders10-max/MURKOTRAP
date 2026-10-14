local RESOURCE = GetCurrentResourceName()

local state = {
    phase = 'idle', -- idle | preparing | offered | starting | active
    ctx = nil,
    offerExpires = 0,
    lastEnd = 0,
    joinedAt = GetGameTimer(),
    karma = 0,
    enabled = GetResourceKvpString('murko_civhelp:enabled') ~= 'false',
}

local popup
local acceptToken = Utils.InputToken('civhelp_accept')
local declineToken = Utils.InputToken('civhelp_decline')

local blockedClasses = {}
for _, class in ipairs(Config.Trigger.BlockedVehicleClasses) do
    blockedClasses[class] = true
end

math.randomseed(GetGameTimer())

-- ---------------------------------------------------------------------------
-- Karma popup
-- ---------------------------------------------------------------------------

local function showKarmaPopup(delta, total)
    if delta > 0 then
        popup = { title = '+ Positive Karma', sub = ('+%d karma  (total %d)'):format(delta, total), r = 80, g = 220, b = 100 }
        PlaySoundFrontend(-1, 'CHALLENGE_UNLOCKED', 'HUD_AWARDS', true)
    else
        popup = { title = 'Bad Karma', sub = ('%d karma  (total %d)'):format(delta, total), r = 230, g = 60, b = 60 }
        PlaySoundFrontend(-1, 'LOSER', 'HUD_AWARDS', true)
    end
    popup.start = GetGameTimer()
end

local POPUP_DURATION = 4000

local function drawPopup()
    local elapsed = GetGameTimer() - popup.start
    if elapsed > POPUP_DURATION then
        popup = nil
        return
    end
    local alpha = 255
    if elapsed < 300 then
        alpha = math.floor(255 * elapsed / 300)
    elseif elapsed > POPUP_DURATION - 800 then
        alpha = math.floor(255 * (POPUP_DURATION - elapsed) / 800)
    end
    local y = 0.26 - 0.02 * (elapsed / POPUP_DURATION)
    Utils.DrawText2D(popup.title, 0.5, y, 1.1, popup.r, popup.g, popup.b, alpha, 7)
    Utils.DrawText2D(popup.sub, 0.5, y + 0.065, 0.5, 255, 255, 255, alpha, 4)
end

-- ---------------------------------------------------------------------------
-- Request lifecycle
-- ---------------------------------------------------------------------------

local function finish(outcome, reason)
    local ctx = state.ctx
    if not ctx then
        return
    end
    state.ctx = nil
    state.phase = 'idle'
    state.lastEnd = GetGameTimer()

    if ctx.def.onEnd then
        local ok, err = pcall(ctx.def.onEnd, ctx, outcome)
        if not ok then
            print(('[%s] onEnd of %s errored: %s'):format(RESOURCE, ctx.id, err))
        end
    end
    ctx:release()

    if reason then
        Utils.Notify(reason)
    end
    TriggerServerEvent('murko_civhelp:report', ctx.id, outcome, ctx.factor)
end

local function pickScenario(coords)
    local isCity = Utils.IsCity(coords)
    local pool, total = {}, 0
    for id in pairs(Scenarios) do
        local cfg = Config.Scenarios[id]
        if cfg and cfg.enabled and (cfg.area == 'any' or (cfg.area == 'city') == isCity) then
            local weight = cfg.weight or 1
            pool[#pool + 1] = { id = id, weight = weight }
            total = total + weight
        end
    end
    if total <= 0 then
        return nil
    end
    local roll = math.random() * total
    for _, entry in ipairs(pool) do
        roll = roll - entry.weight
        if roll <= 0 then
            return entry.id
        end
    end
    return pool[#pool].id
end

local function offerScenario(forcedId)
    if state.phase ~= 'idle' then
        return false, 'You are already dealing with a request.'
    end
    state.phase = 'preparing'

    local inVehicle = IsPedInAnyVehicle(PlayerPedId(), false)
    local range = Config.Trigger.SpawnDistance
    local spot = inVehicle and Utils.FindRoadsideSpot(range.min, range.max) or Utils.FindRoadsideSpot(25.0, 60.0)
    if not spot then
        state.phase = 'idle'
        return false, 'No suitable roadside spot nearby.'
    end

    local id = forcedId or pickScenario(spot.coords)
    if not id or not Scenarios[id] then
        state.phase = 'idle'
        return false, 'No scenario available here.'
    end

    local ctx = Ctx.new(id, Scenarios[id], spot)
    local ok, res = pcall(ctx.def.setup, ctx)
    if not ok or res == false or not ctx.contact then
        if not ok then
            print(('[%s] setup of %s errored: %s'):format(RESOURCE, id, res))
        end
        ctx:destroy()
        state.phase = 'idle'
        return false, 'Could not set up the scene here.'
    end

    ctx.contactBlip = ctx:addEntityBlip(ctx.contact, 280, 3, 'Civilian in need')
    SetBlipFlashes(ctx.contactBlip, true)

    state.ctx = ctx
    state.offerExpires = GetGameTimer() + Config.DecisionTime * 1000
    state.phase = 'offered'

    Utils.Notify(ctx.def.request, 'Civilian in Need', ctx.def.label, 'CHAR_CHAT_CALL')
    PlaySoundFrontend(-1, 'Text_Arrive_Tone', 'Phone_SoundSet_Default', true)
    TriggerServerEvent('murko_civhelp:offered', id)
    Utils.Debug('offered', id)
    return true
end

local function accept()
    if state.phase ~= 'offered' then
        return
    end
    local ctx = state.ctx
    state.phase = 'starting'
    ctx:removeBlip(ctx.contactBlip)
    ctx.contactBlip = nil
    Utils.Speech(ctx.contact, 'GENERIC_HI')

    CreateThread(function()
        local ok, res = pcall(ctx.def.start, ctx)
        if state.ctx ~= ctx then
            return -- ended while starting (resource stop, cancel)
        end
        if not ok or res == false then
            if not ok then
                print(('[%s] start of %s errored: %s'):format(RESOURCE, ctx.id, res))
            end
            finish('cancelled', 'The situation resolved itself before you got there.')
            return
        end
        ctx.startedAt = GetGameTimer()
        state.phase = 'active'
    end)
end

local function decline()
    if state.phase ~= 'offered' then
        return
    end
    local ctx = state.ctx
    if DoesEntityExist(ctx.contact) and not IsPedDeadOrDying(ctx.contact, true) then
        PlayPedAmbientSpeechNative(ctx.contact, 'GENERIC_CURSE_MED', 'SPEECH_PARAMS_FORCE_SHOUTED')
    end
    finish('ignored')
end

local function canTrigger()
    local now = GetGameTimer()
    if now - state.joinedAt < Config.Trigger.FirstDelay * 1000 then
        return false
    end
    if state.lastEnd > 0 and now - state.lastEnd < Config.Trigger.Cooldown * 1000 then
        return false
    end
    local ped = PlayerPedId()
    if IsEntityDead(ped) or GetPlayerWantedLevel(PlayerId()) > 0 or GetInteriorFromEntity(ped) ~= 0 then
        return false
    end
    local veh = GetVehiclePedIsIn(ped, false)
    if veh == 0 or GetPedInVehicleSeat(veh, -1) ~= ped or blockedClasses[GetVehicleClass(veh)] then
        return false
    end
    return GetEntitySpeed(veh) * 3.6 >= Config.Trigger.MinSpeedKmh
end

-- ---------------------------------------------------------------------------
-- Per-frame handling
-- ---------------------------------------------------------------------------

local function tickOffer()
    local ctx = state.ctx
    if ctx:isDead(ctx.contact) then
        finish('failed', 'The civilian was hurt before anyone could help.')
        return
    end
    local remaining = math.ceil((state.offerExpires - GetGameTimer()) / 1000)
    if remaining <= 0 then
        finish('ignored', 'You drove past someone who needed help.')
        return
    end
    Utils.Help(('~b~Civilian in need:~s~ %s~n~%s Help   %s Ignore   ~c~(%ds)~s~')
        :format(ctx.def.label, acceptToken, declineToken, remaining))
end

local function tickActive()
    local ctx = state.ctx
    local player = PlayerPedId()

    if IsEntityDead(player) then
        finish('failed', 'You were taken out before you could finish helping.')
        return
    end

    local ok, result, reason = pcall(ctx.def.update, ctx)
    if not ok then
        print(('[%s] update of %s errored: %s'):format(RESOURCE, ctx.id, result))
        finish('cancelled')
        return
    end
    if result == 'success' then
        finish('success', 'You helped a civilian in need.')
        return
    elseif result == 'fail' then
        finish('failed', reason)
        return
    end

    if ctx.cfg.timeLimit and ctx:elapsed() > ctx.cfg.timeLimit then
        finish('failed', 'You took too long to help.')
        return
    end

    local dist = #(GetEntityCoords(player) - ctx:getAnchorCoords())
    if dist > Config.AbandonDistance then
        finish('abandoned', 'You abandoned the civilian you promised to help.')
        return
    elseif dist > Config.AbandonWarnDistance then
        Utils.Help('~r~You\'re leaving the civilian behind!~s~ Turn back or you\'ll lose karma.')
    end

    if ctx.objective then
        Utils.DrawText2D(ctx.objective, 0.5, 0.94, 0.42, 255, 255, 255, 235, 4)
    end
end

CreateThread(function()
    while true do
        local sleep = 500
        if state.phase == 'offered' then
            sleep = 0
            tickOffer()
        elseif state.phase == 'active' then
            sleep = 0
            tickActive()
        end
        if popup then
            sleep = 0
            drawPopup()
        end
        Wait(sleep)
    end
end)

CreateThread(function()
    while true do
        Wait(Config.Trigger.CheckInterval * 1000)
        if Config.Trigger.Enabled and state.enabled and state.phase == 'idle' and canTrigger()
            and math.random() < Config.Trigger.Chance then
            offerScenario()
        end
    end
end)

-- ---------------------------------------------------------------------------
-- Commands, key bindings and events
-- ---------------------------------------------------------------------------

RegisterCommand('civhelp_accept', accept, false)
RegisterCommand('civhelp_decline', decline, false)
RegisterKeyMapping('civhelp_accept', 'Civilian help: accept request', 'keyboard', Config.Keys.Accept)
RegisterKeyMapping('civhelp_decline', 'Civilian help: ignore request', 'keyboard', Config.Keys.Decline)

RegisterCommand('karma', function()
    TriggerServerEvent('murko_civhelp:requestKarma', true)
end, false)

RegisterCommand('civhelp', function(_, args)
    local arg = (args[1] or 'toggle'):lower()
    if arg == 'cancel' then
        if state.phase == 'offered' then
            decline()
        elseif state.phase == 'active' then
            finish('abandoned', 'You gave up on the civilian.')
        else
            Utils.Notify('You are not helping anyone right now.')
        end
        return
    end
    if arg == 'on' then
        state.enabled = true
    elseif arg == 'off' then
        state.enabled = false
    else
        state.enabled = not state.enabled
    end
    SetResourceKvp('murko_civhelp:enabled', tostring(state.enabled))
    Utils.Notify(('Random civilian requests are now %s.'):format(state.enabled and '~g~on~s~' or '~r~off~s~'))
end, false)

TriggerEvent('chat:addSuggestion', '/karma', 'Show your karma and rank')
TriggerEvent('chat:addSuggestion', '/civhelp', 'Civilian help requests', {
    { name = 'on|off|cancel', help = 'Turn random requests on/off, or give up on the current one' },
})

RegisterNetEvent('murko_civhelp:karmaResult', function(_, delta, total)
    state.karma = total
    if delta ~= 0 then
        showKarmaPopup(delta, total)
    end
end)

RegisterNetEvent('murko_civhelp:karmaSync', function(total, announce)
    state.karma = total
    if announce then
        Utils.Notify(('Karma: ~b~%d~s~~n~Rank: ~y~%s~s~'):format(total, GetKarmaRank(total)), 'Karma', 'Your reputation', 'CHAR_DEFAULT')
    end
end)

-- Sent by the server's /civhelp_test admin command.
RegisterNetEvent('murko_civhelp:force', function(id)
    CreateThread(function()
        local ok, err = offerScenario(id)
        if not ok then
            Utils.Notify('~r~Could not start a request:~s~ ' .. err)
        end
    end)
end)

AddEventHandler('onResourceStop', function(resource)
    if resource == RESOURCE and state.ctx then
        state.ctx:destroy()
        state.ctx = nil
    end
end)

CreateThread(function()
    TriggerServerEvent('murko_civhelp:requestKarma', false)
end)

-- ---------------------------------------------------------------------------
-- Exports
-- ---------------------------------------------------------------------------

exports('GetKarma', function()
    return state.karma
end)

exports('IsBusy', function()
    return state.phase ~= 'idle'
end)

exports('SetEnabled', function(enabled)
    state.enabled = enabled and true or false
end)

exports('TriggerRequest', function(id)
    return offerScenario(id)
end)
