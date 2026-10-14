-- A mugger knocked someone down and ran off with their wallet. Catch the mugger,
-- take the wallet back and return it.

local GIVE_ANIM = { 'mp_common', 'givetake1_a' }

RegisterScenario('mugging', {
    label = 'Mugging',
    request = '"He took my wallet! Somebody stop him!"',

    setup = function(ctx)
        local victim = ctx:spawnPed(Utils.Pick(Config.Models.Civilians), ctx.coords, ctx.faceRoad)
        if not victim then
            return false
        end
        Utils.PlayAnim(victim, 'combat@damage@writhe', 'writhe_loop', 1)

        -- The victim's shopping, scattered across the pavement.
        ctx:spawnObject('prop_paper_bag_small', ctx.coords + ctx.forward * 1.0, math.random() * 360.0)
        ctx:spawnObject('prop_cs_mobile_phone', ctx.coords + ctx.forward * -0.9 + ctx.right * 0.4, math.random() * 360.0)

        ctx.data.victim = victim
        ctx:setContact(victim)
    end,

    start = function(ctx)
        local d = ctx.data
        Utils.LoadAnimDict(GIVE_ANIM[1])

        local muggerPos = Utils.FindSpotAround(ctx.coords, 22.0, 32.0)
        local mugger = ctx:spawnPed(Utils.Pick(Config.Models.Muggers), muggerPos, 0.0)
        if not mugger then
            return false
        end
        d.mugger = mugger
        d.wallet = ctx:attachObject('prop_ld_wallet_01', mugger, 57005, vector3(0.12, 0.02, -0.03), vector3(-90.0, 0.0, 0.0))
        TaskSmartFleePed(mugger, PlayerPedId(), 1000.0, -1, false, false)
        Utils.Speech(mugger, 'GENERIC_INSULT_HIGH')

        ClearPedTasks(d.victim)
        TaskStartScenarioInPlace(d.victim, 'WORLD_HUMAN_STAND_IMPATIENT', 0, true)

        d.muggerBlip = ctx:addEntityBlip(mugger, 1, 1, 'Mugger')
        ctx.anchor = mugger
        d.stage = 'chase'
        ctx:setObjective('Chase down the ~r~mugger~s~!')
    end,

    update = function(ctx)
        local d = ctx.data
        local player = PlayerPedId()
        local playerPos = GetEntityCoords(player)

        if ctx:isDead(d.victim) then
            return 'fail', 'The victim didn\'t make it.'
        end

        if d.stage == 'chase' then
            local mugger = d.mugger
            if not DoesEntityExist(mugger) then
                return 'fail', 'The mugger got away.'
            end
            local dist = #(playerPos - GetEntityCoords(mugger))
            if dist > (ctx.cfg.escapeDistance or 200.0) then
                return 'fail', 'The mugger got away.'
            end
            if not IsPedDeadOrDying(mugger, true) then
                SetPedMoveRateOverride(mugger, ctx.cfg.muggerSpeed or 0.92)
            end

            local caughtRange = IsPedInAnyVehicle(player, false) and 7.0 or 2.8
            if IsPedDeadOrDying(mugger, true) or dist <= caughtRange then
                d.stage = 'wallet'
                if not IsPedDeadOrDying(mugger, true) then
                    ClearPedTasksImmediately(mugger)
                    TaskHandsUp(mugger, 60000, player, -1, true)
                    Utils.Speech(mugger, 'GENERIC_FRIGHTENED_HIGH')
                end
                ctx:setObjective('The mugger gave up. Take the ~y~wallet~s~ back.')
            end
            return
        end

        if d.stage == 'wallet' then
            if not DoesEntityExist(d.mugger) then
                return 'fail', 'The mugger got away with the wallet.'
            end
            local muggerPos = GetEntityCoords(d.mugger)
            ctx:markerOn(d.mugger, 1.3)
            if ctx:interact(muggerPos, 2.2, 'take the wallet') then
                ctx:deleteObject(d.wallet)
                Utils.PlayAnim(player, GIVE_ANIM[1], GIVE_ANIM[2], 48, 2000)
                if not IsPedDeadOrDying(d.mugger, true) then
                    ClearPedTasks(d.mugger)
                    TaskSmartFleePed(d.mugger, player, 500.0, -1, false, false)
                    ctx:keepTask(d.mugger)
                end
                ctx:removeBlip(d.muggerBlip)
                d.victimBlip = ctx:addEntityBlip(d.victim, 280, 3, 'Mugging victim')
                ctx.anchor = d.victim
                d.stage = 'return'
                ctx:setObjective('Return the wallet to the ~b~victim~s~.')
            end
            return
        end

        if d.stage == 'return' then
            local victimPos = GetEntityCoords(d.victim)
            ctx:markerOn(d.victim, 1.3)
            if ctx:interact(victimPos, 2.2, 'give the wallet back') then
                ClearPedTasks(d.victim)
                TaskTurnPedToFaceEntity(d.victim, player, 2000)
                Utils.PlayAnim(player, GIVE_ANIM[1], GIVE_ANIM[2], 48, 2000)
                Utils.PlayAnim(d.victim, GIVE_ANIM[1], GIVE_ANIM[2], 48, 2000)
                Utils.Speech(d.victim, 'GENERIC_THANKS')
                d.stage = 'done'
                d.doneAt = GetGameTimer()
            end
            return
        end

        if d.stage == 'done' and GetGameTimer() - d.doneAt > 2000 then
            return 'success'
        end
    end,
})
