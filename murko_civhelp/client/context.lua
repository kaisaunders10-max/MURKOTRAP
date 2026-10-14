-- Scenario registry and the per-request context object every scenario works with.
--
-- A scenario is a table registered with RegisterScenario(id, def):
--   label      short name shown in notifications
--   request    what the civilian says when asking for help
--   setup(ctx) build the scene before the player accepts. Must call ctx:setContact(ped).
--              Return false to abort (e.g. a model failed to load).
--   start(ctx) the player accepted: spawn extra entities, set the objective
--   update(ctx) called every frame while active. Return 'success' or 'fail' (plus an
--              optional reason) to end the request, nil to keep going.
--   onEnd(ctx, outcome) optional, called before the scene is released

Scenarios = {}

function RegisterScenario(id, def)
    def.id = id
    Scenarios[id] = def
end

Ctx = {}
Ctx.__index = Ctx

function Ctx.new(id, def, spot)
    return setmetatable({
        id = id,
        def = def,
        cfg = Config.Scenarios[id] or {},
        coords = spot.coords,
        road = spot.road,
        heading = spot.heading,
        right = spot.right,
        forward = spot.forward,
        faceRoad = spot.faceRoad,
        peds = {},
        vehicles = {},
        objects = {},
        blips = {},
        fires = {},
        fireAreas = {},
        kept = {},
        holds = {},
        escorts = {},
        data = {},
        objective = nil,
        anchor = nil,
        factor = 1.0,
        startedAt = 0,
    }, Ctx)
end

-- ---------------------------------------------------------------------------
-- Spawning
-- ---------------------------------------------------------------------------

function Ctx:spawnPed(model, coords, heading, pedType)
    local hash = Utils.LoadModel(model)
    if not hash then
        return nil
    end
    local ped = CreatePed(pedType or 4, hash, coords.x, coords.y, coords.z, heading or 0.0, Config.NetworkedEntities, true)
    SetModelAsNoLongerNeeded(hash)
    if not ped or ped == 0 then
        return nil
    end
    SetEntityAsMissionEntity(ped, true, true)
    SetBlockingOfNonTemporaryEvents(ped, true)
    SetPedFleeAttributes(ped, 0, false)
    SetPedKeepTask(ped, true)
    self.peds[#self.peds + 1] = ped
    return ped
end

function Ctx:spawnVehicle(model, coords, heading)
    local hash = Utils.LoadModel(model)
    if not hash then
        return nil
    end
    local veh = CreateVehicle(hash, coords.x, coords.y, coords.z, heading or 0.0, Config.NetworkedEntities, false)
    SetModelAsNoLongerNeeded(hash)
    if not veh or veh == 0 then
        return nil
    end
    SetEntityAsMissionEntity(veh, true, true)
    SetVehicleOnGroundProperly(veh)
    SetVehicleHasBeenOwnedByPlayer(veh, false)
    SetVehicleNeedsToBeHotwired(veh, false)
    self.vehicles[#self.vehicles + 1] = veh
    return veh
end

-- Props are cosmetic: if the model is missing the scene still works without it.
function Ctx:spawnObject(model, coords, heading, placeOnGround)
    local hash = Utils.LoadModel(model)
    if not hash then
        return nil
    end
    local obj = CreateObject(hash, coords.x, coords.y, coords.z, Config.NetworkedEntities, false, false)
    SetModelAsNoLongerNeeded(hash)
    if not obj or obj == 0 then
        return nil
    end
    SetEntityHeading(obj, heading or 0.0)
    if placeOnGround ~= false then
        PlaceObjectOnGroundProperly(obj)
    end
    self.objects[#self.objects + 1] = obj
    return obj
end

function Ctx:attachObject(model, ped, bone, offset, rot)
    local obj = self:spawnObject(model, GetEntityCoords(ped), 0.0, false)
    if obj then
        AttachEntityToEntity(obj, ped, GetPedBoneIndex(ped, bone), offset.x, offset.y, offset.z, rot.x, rot.y, rot.z,
            true, true, false, true, 1, true)
    end
    return obj
end

function Ctx:deleteObject(obj)
    for i, o in ipairs(self.objects) do
        if o == obj then
            table.remove(self.objects, i)
            break
        end
    end
    Utils.DeleteEntity(obj)
end

function Ctx:startFire(coords, maxChildren)
    local handle = StartScriptFire(coords.x, coords.y, coords.z, maxChildren or 2, false)
    self.fires[#self.fires + 1] = handle
    self.fireAreas[#self.fireAreas + 1] = coords
    return handle
end

-- ---------------------------------------------------------------------------
-- Blips
-- ---------------------------------------------------------------------------

local function nameBlip(blip, label)
    BeginTextCommandSetBlipName('STRING')
    AddTextComponentSubstringPlayerName(label)
    EndTextCommandSetBlipName(blip)
end

function Ctx:addBlip(coords, sprite, colour, label, route)
    local blip = AddBlipForCoord(coords.x, coords.y, coords.z)
    SetBlipSprite(blip, sprite or 1)
    SetBlipColour(blip, colour or 5)
    SetBlipScale(blip, 0.9)
    SetBlipAsShortRange(blip, false)
    nameBlip(blip, label or 'Civilian help')
    if route then
        SetBlipRoute(blip, true)
        SetBlipRouteColour(blip, colour or 5)
    end
    self.blips[#self.blips + 1] = blip
    return blip
end

function Ctx:addEntityBlip(entity, sprite, colour, label)
    local blip = AddBlipForEntity(entity)
    SetBlipSprite(blip, sprite or 1)
    SetBlipColour(blip, colour or 5)
    SetBlipScale(blip, 0.85)
    SetBlipAsShortRange(blip, false)
    nameBlip(blip, label or 'Civilian help')
    self.blips[#self.blips + 1] = blip
    return blip
end

function Ctx:addRadiusBlip(coords, radius, colour)
    local blip = AddBlipForRadius(coords.x, coords.y, coords.z, radius)
    SetBlipColour(blip, colour or 5)
    SetBlipAlpha(blip, 90)
    self.blips[#self.blips + 1] = blip
    return blip
end

function Ctx:removeBlip(blip)
    if not blip then
        return
    end
    for i, b in ipairs(self.blips) do
        if b == blip then
            table.remove(self.blips, i)
            break
        end
    end
    if DoesBlipExist(blip) then
        RemoveBlip(blip)
    end
end

-- ---------------------------------------------------------------------------
-- State helpers
-- ---------------------------------------------------------------------------

function Ctx:setContact(ped)
    self.contact = ped
end

function Ctx:setObjective(text)
    self.objective = text
end

-- The entity (or coords) the player must stay near; defaults to the scene origin.
function Ctx:getAnchorCoords()
    local anchor = self.anchor
    if type(anchor) == 'number' and DoesEntityExist(anchor) then
        return GetEntityCoords(anchor)
    elseif type(anchor) == 'vector3' then
        return anchor
    end
    return self.coords
end

function Ctx:isDead(ped)
    return not ped or not DoesEntityExist(ped) or IsPedDeadOrDying(ped, true)
end

-- Keep the ped's current task when the scene is released instead of making it wander.
function Ctx:keepTask(ped)
    self.kept[ped] = true
end

function Ctx:elapsed()
    return (GetGameTimer() - self.startedAt) / 1000.0
end

-- ---------------------------------------------------------------------------
-- Interaction helpers (call these every frame from update)
-- ---------------------------------------------------------------------------

function Ctx:marker(coords, r, g, b)
    if #(GetEntityCoords(PlayerPedId()) - coords) < 80.0 then
        Utils.Marker(coords, r, g, b)
    end
end

function Ctx:markerOn(entity, height)
    if DoesEntityExist(entity) then
        self:marker(GetEntityCoords(entity) + vector3(0.0, 0.0, height or 1.3))
    end
end

-- Single key press near coords, on foot. Returns true the frame E is pressed.
function Ctx:interact(coords, radius, label)
    local player = PlayerPedId()
    if IsPedInAnyVehicle(player, false) or #(GetEntityCoords(player) - coords) > radius then
        return false
    end
    Utils.Help(('Press ~INPUT_CONTEXT~ to %s.'):format(label))
    return IsControlJustReleased(0, 38)
end

-- Hold E near coords, on foot, until the progress bar fills. Progress is kept if
-- the player lets go. Returns true once complete.
--   opts = { help = 'repair the engine', progress = 'Repairing', duration = ms, anim = { dict, name } }
function Ctx:hold(key, coords, radius, opts)
    local h = self.holds[key]
    if not h then
        h = { progress = 0.0 }
        self.holds[key] = h
    end
    if h.done then
        return true
    end

    local player = PlayerPedId()
    local inRange = not IsPedInAnyVehicle(player, false) and #(GetEntityCoords(player) - coords) <= radius
    local anim = opts.anim

    if inRange and IsControlPressed(0, 38) then
        if anim and not h.animating then
            local pos = GetEntityCoords(player)
            SetEntityHeading(player, GetHeadingFromVector_2d(coords.x - pos.x, coords.y - pos.y))
            Utils.PlayAnim(player, anim[1], anim[2], 1)
            h.animating = true
        end
        h.progress = h.progress + GetFrameTime() * 1000.0
        Utils.DrawProgress(opts.progress, h.progress / opts.duration)
        if h.progress >= opts.duration then
            h.done = true
            if h.animating then
                StopAnimTask(player, anim[1], anim[2], 1.0)
            end
            return true
        end
    else
        if h.animating then
            StopAnimTask(player, anim[1], anim[2], 1.0)
            h.animating = false
        end
        if inRange then
            Utils.Help(('Hold ~INPUT_CONTEXT~ to %s.'):format(opts.help))
            if h.progress > 0 then
                Utils.DrawProgress(opts.progress, h.progress / opts.duration)
            end
        end
    end
    return false
end

local function exitVehicle(ped, veh, st, opts)
    if st.exiting then
        return
    end
    st.exiting = true
    if opts.warp then
        -- Animals can't use the exit animations; teleport them out on the kerb side.
        local pos = GetOffsetFromEntityInWorldCoords(veh, 2.2, 0.0, 0.0)
        ClearPedTasksImmediately(ped)
        SetEntityCoords(ped, pos.x, pos.y, pos.z, false, false, false, false)
    else
        TaskLeaveVehicle(ped, veh, 0)
    end
end

-- Moves a ped to dest together with the player, on foot (if opts.follow) or as a
-- passenger in the player's vehicle. Returns a status string:
--   'arrived'   the ped is on foot within opts.radius of dest
--   'riding'    the ped is a passenger in the player's vehicle
--   'boarding'  the ped is getting in
--   'exiting'   the ped is getting out
--   'waiting'   the player is in a vehicle but has not stopped next to the ped
--   'parked'    the ped is in a vehicle the player has left
--   'following' the ped follows the player on foot
--   'onfoot'    both on foot and the ped does not follow (rides only)
-- opts = { follow = bool, warp = bool, radius = number }
function Ctx:escort(ped, dest, opts)
    opts = opts or {}
    local st = self.escorts[ped]
    if not st then
        st = {}
        self.escorts[ped] = st
    end

    local now = GetGameTimer()
    local player = PlayerPedId()
    local pveh = GetVehiclePedIsIn(player, false)
    local pedVeh = GetVehiclePedIsIn(ped, false)
    local radius = opts.radius or 10.0

    if pedVeh ~= 0 then
        st.boardingSince = nil
        st.following = false
        if pveh == pedVeh then
            local speed = GetEntitySpeed(pveh)
            if Utils.Dist2D(GetEntityCoords(pveh), dest) <= radius then
                if speed < 1.0 then
                    exitVehicle(ped, pedVeh, st, opts)
                    return 'exiting'
                end
                Utils.Help('Stop the vehicle to let your passenger out.')
            end
            if speed > 2.0 then
                st.exiting = false -- drove off mid-exit; allow another attempt later
            end
            return 'riding'
        end
        if pveh ~= 0 or opts.follow then
            -- The player switched vehicles, or left it and the ped should follow.
            exitVehicle(ped, pedVeh, st, opts)
            return 'exiting'
        end
        return 'parked'
    end

    st.exiting = false

    if Utils.Dist2D(GetEntityCoords(ped), dest) <= radius then
        if st.following then
            ClearPedTasks(ped)
            st.following = false
        end
        return 'arrived'
    end

    if pveh ~= 0 then
        if st.following then
            ClearPedTasks(ped)
            st.following = false
        end
        local close = #(GetEntityCoords(ped) - GetEntityCoords(pveh)) <= 12.0
        if st.boardingSince then
            if not close then
                st.boardingSince = nil
            elseif now - st.boardingSince > 12000 then
                -- Stuck trying to get in (blocked door, odd vehicle): just seat them.
                local seat = Utils.GetFreePassengerSeat(pveh)
                if seat then
                    SetPedIntoVehicle(ped, pveh, seat)
                end
                st.boardingSince = nil
            end
            return 'boarding'
        end
        if close and GetEntitySpeed(pveh) < 1.5 then
            local seat = Utils.GetFreePassengerSeat(pveh)
            if not seat then
                Utils.Help('Your vehicle has no free passenger seat.')
                return 'waiting'
            end
            if opts.warp then
                SetPedIntoVehicle(ped, pveh, seat)
            else
                TaskEnterVehicle(ped, pveh, 12000, seat, 2.0, 1, 0)
                st.boardingSince = now
            end
            return 'boarding'
        end
        return 'waiting'
    end

    st.boardingSince = nil
    if opts.follow then
        local far = #(GetEntityCoords(ped) - GetEntityCoords(player)) > 5.0
        if not st.following or (far and now - (st.lastFollow or 0) > 8000) then
            TaskFollowToOffsetOfEntity(ped, player, 0.6, -1.2, 0.0, 2.0, -1, 1.5, true)
            st.following = true
            st.lastFollow = now
        end
        return 'following'
    end
    return 'onfoot'
end

-- Give a civilian a ride to dest. Handles the objective text and the route blip.
-- Returns the escort status; 'arrived' means they got out at the destination.
function Ctx:ride(ped, dest, destLabel)
    local r = self.data.ride
    if not r or r.ped ~= ped then
        r = { ped = ped, dest = dest, label = destLabel }
        self.data.ride = r
    end

    -- Destinations are snapped to the road once the player is near enough for the
    -- path nodes there to be loaded.
    if not r.snapped and #(GetEntityCoords(PlayerPedId()) - r.dest) < 300.0 then
        r.dest = Utils.SnapToRoad(r.dest, 40.0)
        r.snapped = true
        if r.blip and DoesBlipExist(r.blip) then
            SetBlipCoords(r.blip, r.dest.x, r.dest.y, r.dest.z)
        end
    end

    local status = self:escort(ped, r.dest, { follow = false, radius = 25.0 })

    if status == 'riding' or status == 'exiting' then
        if not r.blip then
            r.blip = self:addBlip(r.dest, 1, 5, destLabel, true)
        end
        self:setObjective(('Drive your passenger to ~y~%s~s~.'):format(destLabel))
    elseif status == 'boarding' then
        self:setObjective('Your passenger is getting in...')
    elseif status == 'waiting' then
        self:setObjective('Pull up next to the civilian and ~y~stop~s~ so they can get in.')
    elseif status == 'parked' then
        self:setObjective('Get back in the vehicle.')
    elseif status == 'onfoot' then
        self:setObjective('Get in a vehicle and pull up next to the civilian to give them a ride.')
    end
    return status
end

-- ---------------------------------------------------------------------------
-- Cleanup
-- ---------------------------------------------------------------------------

function Ctx:clearFires()
    for _, handle in ipairs(self.fires) do
        RemoveScriptFire(handle)
    end
    for _, pos in ipairs(self.fireAreas) do
        StopFireInRange(pos.x, pos.y, pos.z, 15.0)
    end
    self.fires, self.fireAreas = {}, {}
end

local function removeBlips(self)
    for _, blip in ipairs(self.blips) do
        if DoesBlipExist(blip) then
            RemoveBlip(blip)
        end
    end
    self.blips = {}
end

-- Ends the scene gracefully: props and fires go, peds and vehicles are handed back
-- to the game so they wander off and despawn naturally.
function Ctx:release()
    removeBlips(self)
    self:clearFires()
    for _, obj in ipairs(self.objects) do
        Utils.DeleteEntity(obj)
    end
    self.objects = {}

    local pveh = GetVehiclePedIsIn(PlayerPedId(), false)
    for _, ped in ipairs(self.peds) do
        if DoesEntityExist(ped) then
            if not IsPedDeadOrDying(ped, true) then
                SetBlockingOfNonTemporaryEvents(ped, false)
                SetPedMoveRateOverride(ped, 1.0)
                local veh = GetVehiclePedIsIn(ped, false)
                if veh ~= 0 and veh == pveh then
                    TaskLeaveVehicle(ped, veh, 0)
                elseif veh == 0 and not self.kept[ped] then
                    ClearPedTasks(ped)
                    TaskWanderStandard(ped, 10.0, 10)
                end
            end
            SetEntityAsNoLongerNeeded(ped)
        end
    end
    for _, veh in ipairs(self.vehicles) do
        if DoesEntityExist(veh) then
            SetEntityAsNoLongerNeeded(veh)
        end
    end
    self.peds, self.vehicles = {}, {}
end

-- Deletes everything immediately (setup failure, resource stop).
function Ctx:destroy()
    removeBlips(self)
    self:clearFires()
    for _, list in ipairs({ self.objects, self.peds, self.vehicles }) do
        for _, entity in ipairs(list) do
            Utils.DeleteEntity(entity)
        end
    end
    self.objects, self.peds, self.vehicles = {}, {}, {}
end
