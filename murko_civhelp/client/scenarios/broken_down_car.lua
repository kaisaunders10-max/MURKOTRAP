-- A motorist's car has died at the side of the road. Fix the engine and they drive off.

local REPAIR_ANIM = { 'mini@repair', 'fixing_a_player' }

RegisterScenario('broken_down_car', {
    label = 'Broken-down vehicle',
    request = '"My car just died on me! Could you take a look at the engine?"',

    setup = function(ctx)
        local veh = ctx:spawnVehicle(Utils.Pick(Config.Models.BrokenCars), ctx.road + ctx.right * 3.0, ctx.heading)
        if not veh then
            return false
        end
        SetVehicleEngineOn(veh, false, true, true)
        SetVehicleEngineHealth(veh, 150.0) -- low enough to smoke
        SetVehicleUndriveable(veh, true)
        SetVehicleDoorOpen(veh, 4, false, false)
        SetVehicleIndicatorLights(veh, 0, true)
        SetVehicleIndicatorLights(veh, 1, true)

        local driver = ctx:spawnPed(Utils.Pick(Config.Models.Civilians), GetOffsetFromEntityInWorldCoords(veh, 2.2, -1.2, 0.0), ctx.faceRoad)
        if not driver then
            return false
        end
        Utils.Wave(driver)

        ctx.data.veh = veh
        ctx.data.driver = driver
        ctx:setContact(driver)
    end,

    start = function(ctx)
        local d = ctx.data
        Utils.LoadAnimDict(REPAIR_ANIM[1])
        ClearPedTasks(d.driver)
        TaskStartScenarioInPlace(d.driver, 'WORLD_HUMAN_STAND_IMPATIENT', 0, true)

        local _, max = GetModelDimensions(GetEntityModel(d.veh))
        d.hoodOffset = max.y + 0.5
        ctx:addEntityBlip(d.veh, 225, 5, 'Broken-down vehicle')
        ctx.anchor = d.veh
        ctx:setObjective('Get out and fix the ~y~engine~s~ of the broken-down car.')
    end,

    update = function(ctx)
        local d = ctx.data
        if ctx:isDead(d.driver) then
            return 'fail', 'The driver was badly hurt.'
        end
        if not DoesEntityExist(d.veh) then
            return 'fail', 'The broken-down car is gone.'
        end

        if not d.fixedAt then
            local hood = GetOffsetFromEntityInWorldCoords(d.veh, 0.0, d.hoodOffset, 0.0)
            ctx:marker(hood + vector3(0.0, 0.0, 1.0))
            local done = ctx:hold('repair', hood, 1.8, {
                help = 'repair the engine',
                progress = 'Repairing engine',
                duration = 10000,
                anim = REPAIR_ANIM,
            })
            if done then
                d.fixedAt = GetGameTimer()
                SetVehicleEngineHealth(d.veh, 1000.0)
                SetVehicleUndriveable(d.veh, false)
                SetVehicleDoorShut(d.veh, 4, false)
                SetVehicleIndicatorLights(d.veh, 0, false)
                SetVehicleIndicatorLights(d.veh, 1, false)
                Utils.Speech(d.driver, 'GENERIC_THANKS')
                ClearPedTasks(d.driver)
                TaskEnterVehicle(d.driver, d.veh, 10000, -1, 1.0, 1, 0)
                ctx:setObjective('The engine runs again! The driver is getting back in.')
            end
            return
        end

        if IsPedInVehicle(d.driver, d.veh, false) or GetGameTimer() - d.fixedAt > 10000 then
            return 'success'
        end
    end,

    onEnd = function(ctx, outcome)
        local d = ctx.data
        if outcome == 'success' and DoesEntityExist(d.driver) and IsPedInVehicle(d.driver, d.veh, false) then
            SetVehicleEngineOn(d.veh, true, false, true)
            TaskVehicleDriveWander(d.driver, d.veh, 15.0, 786603)
            ctx:keepTask(d.driver)
        end
    end,
})
