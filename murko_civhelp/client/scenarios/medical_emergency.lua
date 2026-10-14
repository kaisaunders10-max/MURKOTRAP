-- Someone collapsed on the pavement. Do CPR, then drive them to the nearest hospital.

local VICTIM_ANIM = { 'mini@cpr@char_b@cpr_def', 'cpr_pumpchest_idle' }
local CPR_ANIM = { 'mini@cpr@char_a@cpr_str', 'cpr_pumpchest' }

RegisterScenario('medical_emergency', {
    label = 'Medical emergency',
    request = '"Somebody help! This man just collapsed and he\'s not breathing!"',

    setup = function(ctx)
        local victim = ctx:spawnPed(Utils.Pick(Config.Models.Civilians), ctx.coords, ctx.heading)
        if not victim then
            return false
        end
        if not Utils.PlayAnim(victim, VICTIM_ANIM[1], VICTIM_ANIM[2], 1) then
            SetPedToRagdoll(victim, 1000000, 1000000, 0, false, false, false)
        end

        local bystanderPos = ctx.coords + ctx.right * 1.0 + ctx.forward * 2.5
        local bystander = ctx:spawnPed(Utils.Pick(Config.Models.Civilians), bystanderPos, ctx.faceRoad)
        if not bystander then
            return false
        end
        Utils.Wave(bystander)

        -- Medical kit on the ground next to the patient.
        ctx:spawnObject('prop_ld_health_pack', ctx.coords + ctx.right * 0.8, ctx.heading)

        ctx.data.victim = victim
        ctx.data.bystander = bystander
        ctx:setContact(bystander)
    end,

    start = function(ctx)
        local d = ctx.data
        Utils.LoadAnimDict(CPR_ANIM[1])
        ClearPedTasks(d.bystander)
        TaskStartScenarioInPlace(d.bystander, 'WORLD_HUMAN_STAND_MOBILE', 0, true)

        d.victimBlip = ctx:addEntityBlip(d.victim, 61, 1, 'Collapsed civilian')
        ctx.anchor = d.victim
        ctx:setObjective('Get to the ~r~collapsed civilian~s~ and perform CPR.')
    end,

    update = function(ctx)
        local d = ctx.data
        if ctx:isDead(d.victim) then
            return 'fail', 'The patient didn\'t make it.'
        end

        if not d.revived then
            local pos = GetEntityCoords(d.victim)
            ctx:marker(pos + vector3(0.0, 0.0, 1.0), 255, 80, 80)
            local done = ctx:hold('cpr', pos, 1.8, {
                help = 'perform CPR',
                progress = 'Performing CPR',
                duration = 12000,
                anim = CPR_ANIM,
            })
            if done then
                d.revived = true
                ClearPedTasks(d.victim)
                if Utils.LoadAnimSet('move_m@injured') then
                    SetPedMovementClipset(d.victim, 'move_m@injured', 1.0)
                end
                Utils.Speech(d.victim, 'GENERIC_THANKS')
                Utils.Speech(d.bystander, 'GENERIC_THANKS')
                ctx:removeBlip(d.victimBlip)
                d.hospital = Utils.Nearest(Config.Hospitals, GetEntityCoords(d.victim))
                Utils.Notify('They\'re breathing again, but they need a doctor. Drive them to ~y~' .. d.hospital.label .. '~s~.')
            end
            return
        end

        if d.arrivedAt then
            if GetGameTimer() - d.arrivedAt > 3000 then
                return 'success'
            end
            return
        end

        local status = ctx:ride(d.victim, d.hospital.coords, d.hospital.label)
        if status == 'arrived' then
            d.arrivedAt = GetGameTimer()
            Utils.Speech(d.victim, 'GENERIC_THANKS')
            TaskGoStraightToCoord(d.victim, d.hospital.coords.x, d.hospital.coords.y, d.hospital.coords.z, 1.0, 20000, 0.0, 0.0)
            ctx:keepTask(d.victim)
            ctx:setObjective('The patient is heading inside. Nice work!')
        end
    end,
})
