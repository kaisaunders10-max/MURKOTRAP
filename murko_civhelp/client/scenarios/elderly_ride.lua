-- An elderly civilian with heavy shopping needs a ride home. Drive gently: speeding
-- and crashes scare them, which lowers the karma you get (or ends the ride).

RegisterScenario('elderly_ride', {
    label = 'Elderly civilian',
    request = '"Excuse me, dear... my bus never came. Could you drive me home?"',

    setup = function(ctx)
        local elder = ctx:spawnPed(Utils.Pick(Config.Models.Elderly), ctx.coords, ctx.faceRoad)
        if not elder then
            return false
        end
        Utils.Wave(elder)

        local bags = {}
        bags[#bags + 1] = ctx:spawnObject('prop_shopping_bags02', ctx.coords + ctx.forward * 0.8, ctx.heading)
        bags[#bags + 1] = ctx:spawnObject('prop_shopping_bags01', ctx.coords + ctx.forward * -0.8 + ctx.right * 0.3, ctx.heading)
        ctx.data.bags = bags

        ctx.data.elder = elder
        ctx:setContact(elder)
    end,

    start = function(ctx)
        local d = ctx.data
        ClearPedTasks(d.elder)
        TaskStartScenarioInPlace(d.elder, 'WORLD_HUMAN_STAND_IMPATIENT', 0, true)
        d.dest = Utils.PickDestination(Config.ResidentialDestinations, ctx.coords, ctx.cfg.minDistance or 400.0, ctx.cfg.maxDistance or 3000.0)
        d.comfort = 100.0
        d.lastHit = 0
        d.lastComplaint = 0
        ctx.anchor = d.elder
        Utils.Notify(('"Oh, thank you! I live at ~y~%s~s~. Please don\'t drive too fast."'):format(d.dest.label), 'Elderly civilian', 'Ride request')
    end,

    update = function(ctx)
        local d = ctx.data
        if ctx:isDead(d.elder) then
            return 'fail', 'Your passenger was badly hurt.'
        end

        if d.arrivedAt then
            if GetGameTimer() - d.arrivedAt > 2500 then
                return 'success'
            end
            return
        end

        local status = ctx:ride(d.elder, d.dest.coords, d.dest.label)

        if status == 'riding' then
            if d.bags then
                for _, bag in ipairs(d.bags) do
                    ctx:deleteObject(bag)
                end
                d.bags = nil
            end

            local now = GetGameTimer()
            local veh = GetVehiclePedIsIn(d.elder, false)
            local kmh = GetEntitySpeed(veh) * 3.6
            local scared = false
            if kmh > (ctx.cfg.maxSpeedKmh or 90.0) then
                d.comfort = d.comfort - 6.0 * GetFrameTime()
                scared = true
            end
            if HasEntityCollidedWithAnything(veh) and now - d.lastHit > 1500 then
                d.comfort = d.comfort - 10.0
                d.lastHit = now
                scared = true
            end
            if scared and now - d.lastComplaint > 7000 then
                Utils.Speech(d.elder, 'GENERIC_FRIGHTENED_MED')
                d.lastComplaint = now
            end

            d.comfort = math.max(0.0, d.comfort)
            ctx.factor = math.max(0.25, d.comfort / 100.0)
            if d.comfort <= 0.0 then
                return 'fail', 'Your passenger was so frightened they asked to be let out.'
            end

            local colour = d.comfort > 66 and '~g~' or (d.comfort > 33 and '~y~' or '~r~')
            ctx:setObjective(('Drive your passenger home to ~y~%s~s~ carefully. Comfort: %s%d%%~s~')
                :format(d.dest.label, colour, math.floor(d.comfort)))
        elseif status == 'arrived' then
            d.arrivedAt = GetGameTimer()
            Utils.Speech(d.elder, 'GENERIC_THANKS')
            ctx:setObjective('Home safe and sound.')
        end
    end,
})
