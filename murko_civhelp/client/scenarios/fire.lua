-- A dumpster fire is spreading next to the pavement. Grab an extinguisher and put it out.

local EXTINGUISHER = GetHashKey('WEAPON_FIREEXTINGUISHER')

local FIRE_OFFSETS = {
    vector3(0.0, 0.0, 0.0),
    vector3(1.6, 0.4, 0.0),
    vector3(-1.4, 0.6, 0.0),
    vector3(0.3, 1.8, 0.0),
}

RegisterScenario('fire', {
    label = 'Fire',
    request = '"Fire! There\'s a fire and it\'s spreading, please help!"',

    setup = function(ctx)
        local center = ctx.coords + ctx.right * 1.5
        ctx.data.center = center

        ctx:spawnObject('prop_dumpster_01a', center, ctx.heading)
        ctx:spawnObject('prop_rub_binbag_01', center + ctx.forward * 1.8, math.random() * 360.0)
        ctx:spawnObject('prop_rub_binbag_04', center + ctx.forward * -1.8 + ctx.right * 0.5, math.random() * 360.0)

        for _, offset in ipairs(FIRE_OFFSETS) do
            local pos = center + ctx.forward * offset.y + ctx.right * offset.x
            local found, groundZ = GetGroundZFor_3dCoord(pos.x, pos.y, pos.z + 3.0, false)
            ctx:startFire(vector3(pos.x, pos.y, found and groundZ or pos.z), 2)
        end

        local civilian = ctx:spawnPed(Utils.Pick(Config.Models.Civilians), ctx.coords + ctx.forward * 9.0, ctx.faceRoad)
        if not civilian then
            return false
        end
        SetEntityProofs(civilian, false, true, false, false, false, false, false, false)
        Utils.Wave(civilian)
        ctx.data.civilian = civilian
        ctx:setContact(civilian)

        -- Make sure the fire actually caught.
        Wait(500)
        if GetNumberOfFiresInRange(center.x, center.y, center.z, 8.0) == 0 then
            return false
        end
    end,

    start = function(ctx)
        local d = ctx.data
        local player = PlayerPedId()
        if not HasPedGotWeapon(player, EXTINGUISHER, false) then
            GiveWeaponToPed(player, EXTINGUISHER, 2000, false, true)
            d.gaveExtinguisher = true
            Utils.Notify('You grabbed a ~y~fire extinguisher~s~ from your vehicle.')
        else
            SetCurrentPedWeapon(player, EXTINGUISHER, true)
        end

        ClearPedTasks(d.civilian)
        TaskStartScenarioInPlace(d.civilian, 'WORLD_HUMAN_STAND_MOBILE', 0, true)
        ctx:addBlip(d.center, 436, 1, 'Fire')
    end,

    update = function(ctx)
        local d = ctx.data
        if ctx:isDead(d.civilian) then
            return 'fail', 'The civilian was badly hurt.'
        end

        local c = d.center
        local fires = GetNumberOfFiresInRange(c.x, c.y, c.z, 10.0)
        if fires > 0 then
            d.outSince = nil
            ctx:setObjective(('Put out the ~r~fire~s~ with the extinguisher. (%d burning)'):format(fires))
            return
        end

        d.outSince = d.outSince or GetGameTimer()
        ctx:setObjective('Making sure it\'s really out...')
        if GetGameTimer() - d.outSince > 2500 then
            Utils.Speech(d.civilian, 'GENERIC_THANKS')
            return 'success'
        end
    end,

    onEnd = function(ctx)
        if ctx.data.gaveExtinguisher and ctx.cfg.removeExtinguisher ~= false then
            RemoveWeaponFromPed(PlayerPedId(), EXTINGUISHER)
        end
    end,
})
