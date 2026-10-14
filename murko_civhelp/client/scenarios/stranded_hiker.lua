-- A hiker is thumbing for a lift out in Blaine County. Drive them where they need to go.

RegisterScenario('stranded_hiker', {
    label = 'Stranded hiker',
    request = '"Hey! My ride bailed on me. Any chance you could give me a lift?"',

    setup = function(ctx)
        local hiker = ctx:spawnPed(Utils.Pick(Config.Models.Hikers), ctx.coords, ctx.faceRoad)
        if not hiker then
            return false
        end
        if not Utils.PlayAnim(hiker, 'random@hitch_lift', 'idle_f', 1) then
            Utils.Wave(hiker)
        end

        -- Gear dumped next to the road.
        ctx.data.bag = ctx:spawnObject('prop_cs_heist_bag_02', ctx.coords + ctx.forward * 0.9, ctx.heading)
        ctx:spawnObject('prop_skid_sleepbag_1', ctx.coords + ctx.forward * -1.2 + ctx.right * 0.6, ctx.heading)

        ctx.data.hiker = hiker
        ctx:setContact(hiker)
    end,

    start = function(ctx)
        local d = ctx.data
        ClearPedTasks(d.hiker)
        d.dest = Utils.PickDestination(Config.HikerDestinations, ctx.coords, ctx.cfg.minDistance or 700.0, ctx.cfg.maxDistance or 4500.0)
        ctx.anchor = d.hiker
        Utils.Notify(('"Thanks a lot! I\'m heading to ~y~%s~s~."'):format(d.dest.label), 'Stranded hiker', 'Ride request')
    end,

    update = function(ctx)
        local d = ctx.data
        if ctx:isDead(d.hiker) then
            return 'fail', 'The hiker was badly hurt.'
        end

        if d.arrivedAt then
            if GetGameTimer() - d.arrivedAt > 2500 then
                return 'success'
            end
            return
        end

        local status = ctx:ride(d.hiker, d.dest.coords, d.dest.label)
        if status == 'riding' and d.bag then
            ctx:deleteObject(d.bag) -- they took their bag with them
            d.bag = nil
        elseif status == 'arrived' then
            d.arrivedAt = GetGameTimer()
            Utils.Speech(d.hiker, 'GENERIC_THANKS')
            ctx:setObjective('Your passenger made it. Safe travels!')
        end
    end,
})
