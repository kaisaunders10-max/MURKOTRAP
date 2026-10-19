-- after a livery pack (re)starts, nudge cars that are already on screen so the new design shows straight away
RegisterNetEvent('corlinks_liveryauto:refresh', function()
    Wait(2500)
    local me = GetEntityCoords(PlayerPedId())
    for _, veh in ipairs(GetGamePool('CVehicle')) do
        if #(GetEntityCoords(veh) - me) < 200.0 then
            local l = GetVehicleLivery(veh)
            if l and l >= 0 then SetVehicleLivery(veh, l) end
        end
    end
end)

-- /liveryfix : re-apply every livery pack on the cars around you (instead of restarting a pack)
RegisterCommand('liveryfix', function()
    TriggerEvent('corlinks_liveryauto:force')
    Wait(500)
    local me = GetEntityCoords(PlayerPedId())
    for _, veh in ipairs(GetGamePool('CVehicle')) do
        if #(GetEntityCoords(veh) - me) < 200.0 then
            local l = GetVehicleLivery(veh)
            if l and l >= 0 then SetVehicleLivery(veh, l) end
        end
    end
    TriggerEvent('chat:addMessage', { args = { '^5livery', 'Liveries re-applied on cars around you.' } })
end, false)
