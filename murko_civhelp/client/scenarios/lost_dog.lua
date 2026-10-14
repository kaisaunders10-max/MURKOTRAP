-- A dog slipped its leash. Find it, call it over and bring it back to its owner.

local WHISTLE_ANIM = { 'rcmnigel1c', 'hailing_whistle_waive_a' }

RegisterScenario('lost_dog', {
    label = 'Lost dog',
    request = '"Have you seen my dog? He slipped his leash and ran off!"',

    setup = function(ctx)
        local owner = ctx:spawnPed(Utils.Pick(Config.Models.Civilians), ctx.coords, ctx.faceRoad)
        if not owner then
            return false
        end
        Utils.Wave(owner)

        -- A bowl of treats and the dog's ball, left behind.
        ctx:spawnObject('prop_bowl_crisps', ctx.coords + ctx.forward * 0.9, ctx.heading)
        ctx:spawnObject('prop_tennis_ball', ctx.coords + ctx.forward * 1.3 + ctx.right * 0.3, ctx.heading)

        ctx.data.owner = owner
        ctx:setContact(owner)
    end,

    start = function(ctx)
        local d = ctx.data
        Utils.LoadAnimDict(WHISTLE_ANIM[1])

        local dogPos = Utils.FindSpotAround(ctx.coords, 50.0, 100.0)
        local dog = ctx:spawnPed(Utils.Pick(Config.Models.Dogs), dogPos, math.random() * 360.0, 28)
        if not dog then
            return false
        end
        TaskWanderInArea(dog, dogPos.x, dogPos.y, dogPos.z, 8.0, 2.0, 5.0)
        d.dog = dog

        ClearPedTasks(d.owner)
        TaskStartScenarioInPlace(d.owner, 'WORLD_HUMAN_STAND_MOBILE', 0, true)

        local angle = math.random() * math.pi * 2.0
        local center = dogPos + vector3(math.cos(angle), math.sin(angle), 0.0) * (math.random() * 20.0)
        d.areaBlip = ctx:addRadiusBlip(center, 50.0, 5)
        d.areaCenterBlip = ctx:addBlip(center, 442, 5, 'Last seen here')
        ctx:setObjective('Search the ~y~highlighted area~s~ for the lost dog.')
    end,

    update = function(ctx)
        local d = ctx.data
        if ctx:isDead(d.dog) then
            return 'fail', 'The dog didn\'t make it.'
        end
        if ctx:isDead(d.owner) then
            return 'fail', 'The owner was badly hurt.'
        end

        local player = PlayerPedId()
        local playerPos = GetEntityCoords(player)
        local dogPos = GetEntityCoords(d.dog)

        if not d.found then
            if #(playerPos - dogPos) < 30.0 and not d.dogBlip then
                d.dogBlip = ctx:addEntityBlip(d.dog, 442, 2, 'Lost dog')
                ctx:setObjective('There\'s the ~g~dog~s~! Get close and call it over.')
            end
            if d.dogBlip then
                ctx:markerOn(d.dog, 1.0)
            end
            if ctx:interact(dogPos, 3.0, 'whistle for the dog') then
                d.found = true
                Utils.PlayAnim(player, WHISTLE_ANIM[1], WHISTLE_ANIM[2], 48, 2500)
                ClearPedTasks(d.dog)
                ctx:removeBlip(d.areaBlip)
                ctx:removeBlip(d.areaCenterBlip)
                d.ownerBlip = ctx:addEntityBlip(d.owner, 280, 3, 'Dog owner')
                ctx.anchor = d.dog
            end
            return
        end

        if d.reunitedAt then
            if #(dogPos - GetEntityCoords(d.owner)) < 2.0 or GetGameTimer() - d.reunitedAt > 8000 then
                Utils.Speech(d.owner, 'GENERIC_THANKS')
                return 'success'
            end
            return
        end

        local status = ctx:escort(d.dog, GetEntityCoords(d.owner), { follow = true, warp = true, radius = 8.0 })
        if status == 'arrived' then
            d.reunitedAt = GetGameTimer()
            TaskGoToEntity(d.dog, d.owner, -1, 1.0, 2.0, 0, 0)
            ClearPedTasks(d.owner)
            TaskTurnPedToFaceEntity(d.owner, d.dog, -1)
            ctx:setObjective('Reunited!')
        elseif status == 'riding' then
            ctx:setObjective('Drive the dog back to its ~b~owner~s~.')
        elseif status == 'waiting' then
            ctx:setObjective('Stop next to the dog to let it jump in, or walk it back.')
        else
            ctx:setObjective('Lead the dog back to its ~b~owner~s~.')
        end
    end,

    onEnd = function(ctx, outcome)
        local d = ctx.data
        if outcome == 'success' and DoesEntityExist(d.dog) and DoesEntityExist(d.owner) then
            ClearPedTasks(d.owner)
            TaskWanderStandard(d.owner, 10.0, 10)
            TaskFollowToOffsetOfEntity(d.dog, d.owner, 0.8, -0.8, 0.0, 1.5, -1, 1.0, true)
            ctx:keepTask(d.owner)
            ctx:keepTask(d.dog)
        end
    end,
})
