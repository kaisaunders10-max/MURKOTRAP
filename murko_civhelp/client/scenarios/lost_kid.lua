-- A worried parent lost their kid. Search the area, find the kid and bring them back.

RegisterScenario('lost_kid', {
    label = 'Lost child',
    request = '"Please, my kid wandered off and I can\'t find them anywhere!"',

    setup = function(ctx)
        local parent = ctx:spawnPed(Utils.Pick(Config.Models.Civilians), ctx.coords, ctx.faceRoad)
        if not parent then
            return false
        end
        Utils.Wave(parent)

        -- The kid's teddy bear, dropped on the pavement.
        ctx:spawnObject('prop_mr_raspberry_01', ctx.coords + ctx.forward * 1.2, ctx.heading)

        ctx.data.parent = parent
        ctx:setContact(parent)
    end,

    start = function(ctx)
        local d = ctx.data
        local kidPos = Utils.FindSpotAround(ctx.coords, 45.0, 90.0)
        local kid = ctx:spawnPed(Utils.Pick(Config.Models.Kids), kidPos, math.random() * 360.0)
        if not kid then
            return false
        end
        TaskStartScenarioInPlace(kid, 'WORLD_HUMAN_PICNIC', 0, true)
        d.kid = kid

        ClearPedTasks(d.parent)
        TaskStartScenarioInPlace(d.parent, 'WORLD_HUMAN_STAND_IMPATIENT', 0, true)

        -- Search area that contains the kid without giving away the exact spot.
        local angle = math.random() * math.pi * 2.0
        local center = kidPos + vector3(math.cos(angle), math.sin(angle), 0.0) * (math.random() * 18.0)
        d.areaBlip = ctx:addRadiusBlip(center, 45.0, 5)
        d.areaCenterBlip = ctx:addBlip(center, 280, 5, 'Search area')
        ctx:setObjective('Search the ~y~highlighted area~s~ for the missing child.')
    end,

    update = function(ctx)
        local d = ctx.data
        if ctx:isDead(d.kid) or ctx:isDead(d.parent) then
            return 'fail', 'Something terrible happened...'
        end

        local playerPos = GetEntityCoords(PlayerPedId())
        local kidPos = GetEntityCoords(d.kid)

        if not d.found then
            local dist = #(playerPos - kidPos)
            if dist < 25.0 and not d.kidBlip then
                d.kidBlip = ctx:addEntityBlip(d.kid, 280, 2, 'Lost child')
                ctx:setObjective('There they are! Go and talk to the ~g~child~s~.')
            end
            if d.kidBlip then
                ctx:markerOn(d.kid, 1.2)
            end
            if ctx:interact(kidPos, 2.2, 'tell the child you\'ll take them back to their parent') then
                d.found = true
                ClearPedTasks(d.kid)
                Utils.Speech(d.kid, 'GENERIC_THANKS')
                ctx:removeBlip(d.areaBlip)
                ctx:removeBlip(d.areaCenterBlip)
                d.parentBlip = ctx:addEntityBlip(d.parent, 280, 3, 'Parent')
                ctx.anchor = d.kid
            end
            return
        end

        if d.reunitedAt then
            if #(kidPos - GetEntityCoords(d.parent)) < 1.6 or GetGameTimer() - d.reunitedAt > 8000 then
                Utils.Speech(d.parent, 'GENERIC_THANKS')
                return 'success'
            end
            return
        end

        local status = ctx:escort(d.kid, GetEntityCoords(d.parent), { follow = true, radius = 8.0 })
        if status == 'arrived' then
            d.reunitedAt = GetGameTimer()
            TaskGoToEntity(d.kid, d.parent, -1, 1.0, 2.0, 0, 0)
            ClearPedTasks(d.parent)
            TaskTurnPedToFaceEntity(d.parent, d.kid, -1)
            ctx:setObjective('Reunited!')
        elseif status == 'riding' then
            ctx:setObjective('Drive the child back to their ~b~parent~s~.')
        elseif status == 'waiting' or status == 'boarding' then
            ctx:setObjective('Stop next to the child so they can get in, or walk them back.')
        else
            ctx:setObjective('Lead the child back to their ~b~parent~s~.')
        end
    end,

    onEnd = function(ctx, outcome)
        local d = ctx.data
        if outcome == 'success' and DoesEntityExist(d.kid) and DoesEntityExist(d.parent) then
            ClearPedTasks(d.parent)
            TaskWanderStandard(d.parent, 10.0, 10)
            TaskFollowToOffsetOfEntity(d.kid, d.parent, 0.7, -0.6, 0.0, 1.0, -1, 1.0, true)
            ctx:keepTask(d.parent)
            ctx:keepTask(d.kid)
        end
    end,
})
