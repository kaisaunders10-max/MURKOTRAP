Utils = {}

function Utils.Debug(...)
    if Config.Debug then
        print('[murko_civhelp]', ...)
    end
end

function Utils.Pick(list)
    return list[math.random(1, #list)]
end

function Utils.Dist2D(a, b)
    local dx, dy = a.x - b.x, a.y - b.y
    return math.sqrt(dx * dx + dy * dy)
end

function Utils.IsCity(coords)
    return coords.y < Config.CityMaxY
end

-- ---------------------------------------------------------------------------
-- Streaming
-- ---------------------------------------------------------------------------

function Utils.LoadModel(model)
    local hash = type(model) == 'number' and model or GetHashKey(model)
    if not IsModelInCdimage(hash) or not IsModelValid(hash) then
        Utils.Debug('invalid model', model)
        return nil
    end
    RequestModel(hash)
    local timeout = GetGameTimer() + 5000
    while not HasModelLoaded(hash) do
        if GetGameTimer() > timeout then
            Utils.Debug('timed out loading model', model)
            return nil
        end
        Wait(0)
    end
    return hash
end

function Utils.LoadAnimDict(dict)
    if HasAnimDictLoaded(dict) then
        return true
    end
    RequestAnimDict(dict)
    local timeout = GetGameTimer() + 5000
    while not HasAnimDictLoaded(dict) do
        if GetGameTimer() > timeout then
            Utils.Debug('timed out loading anim dict', dict)
            return false
        end
        Wait(0)
    end
    return true
end

function Utils.LoadAnimSet(set)
    if HasAnimSetLoaded(set) then
        return true
    end
    RequestAnimSet(set)
    local timeout = GetGameTimer() + 5000
    while not HasAnimSetLoaded(set) do
        if GetGameTimer() > timeout then
            return false
        end
        Wait(0)
    end
    return true
end

-- ---------------------------------------------------------------------------
-- Ped helpers
-- ---------------------------------------------------------------------------

function Utils.PlayAnim(ped, dict, name, flag, duration)
    if not Utils.LoadAnimDict(dict) then
        return false
    end
    TaskPlayAnim(ped, dict, name, 8.0, -8.0, duration or -1, flag or 1, 0.0, false, false, false)
    return true
end

function Utils.Wave(ped)
    return Utils.PlayAnim(ped, 'friends@frj@ig_1', 'wave_a', 1)
end

function Utils.Speech(ped, name)
    if DoesEntityExist(ped) then
        PlayPedAmbientSpeechNative(ped, name, 'SPEECH_PARAMS_FORCE_NORMAL')
    end
end

function Utils.DeleteEntity(entity)
    if entity and DoesEntityExist(entity) then
        SetEntityAsMissionEntity(entity, true, true)
        DeleteEntity(entity)
    end
end

function Utils.GetFreePassengerSeat(vehicle)
    local max = GetVehicleMaxNumberOfPassengers(vehicle)
    for seat = 0, max - 1 do
        if IsVehicleSeatFree(vehicle, seat) then
            return seat
        end
    end
    return nil
end

-- ---------------------------------------------------------------------------
-- Locations
-- ---------------------------------------------------------------------------

-- Finds a kerbside spot on a road ahead of the player.
-- Returns { coords, road, heading, right, forward, faceRoad } or nil.
function Utils.FindRoadsideSpot(minDist, maxDist)
    local ped = PlayerPedId()
    local origin = GetEntityCoords(ped)
    local entity = GetVehiclePedIsIn(ped, false)
    if entity == 0 then
        entity = ped
    end
    local fwd = GetEntityForwardVector(entity)

    for _ = 1, 10 do
        local dist = minDist + math.random() * (maxDist - minDist)
        local target = origin + fwd * dist
        local found, node, nodeHeading = GetClosestVehicleNodeWithHeading(target.x, target.y, target.z, 1, 3.0, 0)
        if found then
            local toNode = node - origin
            local ahead = toNode.x * fwd.x + toNode.y * fwd.y
            if ahead > 0.0 and Utils.Dist2D(node, origin) >= minDist * 0.6 then
                -- Make the road heading match our direction of travel so the scene
                -- ends up on the kerb to our right.
                local rad = math.rad(nodeHeading)
                local nodeFwdX, nodeFwdY = -math.sin(rad), math.cos(rad)
                if nodeFwdX * fwd.x + nodeFwdY * fwd.y < 0.0 then
                    nodeHeading = (nodeHeading + 180.0) % 360.0
                    rad = math.rad(nodeHeading)
                end
                local right = vector3(math.cos(rad), math.sin(rad), 0.0)
                local side = node + right * Config.Trigger.RoadsideOffset

                local pos
                local ok, safe = GetSafeCoordForPed(side.x, side.y, side.z + 1.0, true, 16)
                if ok and Utils.Dist2D(safe, side) < 6.0 and math.abs(safe.z - side.z) < 4.0 then
                    pos = safe
                else
                    local gOk, groundZ = GetGroundZFor_3dCoord(side.x, side.y, side.z + 5.0, false)
                    pos = vector3(side.x, side.y, gOk and groundZ or side.z)
                end

                return {
                    coords = pos,
                    road = node,
                    heading = nodeHeading,
                    right = right,
                    forward = vector3(-math.sin(rad), math.cos(rad), 0.0),
                    faceRoad = (nodeHeading + 90.0) % 360.0,
                }
            end
        end
    end
    return nil
end

-- Finds a walkable spot between minR and maxR metres from center.
function Utils.FindSpotAround(center, minR, maxR)
    for _ = 1, 12 do
        local angle = math.random() * math.pi * 2.0
        local r = minR + math.random() * (maxR - minR)
        local x, y = center.x + math.cos(angle) * r, center.y + math.sin(angle) * r
        local ok, pos = GetSafeCoordForPed(x, y, center.z + 2.0, true, 16)
        if ok and Utils.Dist2D(pos, center) >= minR * 0.5 and math.abs(pos.z - center.z) < 15.0 then
            return pos
        end
    end
    local angle = math.random() * math.pi * 2.0
    local x, y = center.x + math.cos(angle) * minR, center.y + math.sin(angle) * minR
    local found, groundZ = GetGroundZFor_3dCoord(x, y, center.z + 10.0, false)
    return vector3(x, y, found and groundZ or center.z)
end

-- Snaps a coordinate to the closest road node, if one is close enough.
function Utils.SnapToRoad(coords, maxDist)
    local found, node = GetClosestVehicleNode(coords.x, coords.y, coords.z, 1, 3.0, 0)
    if found and Utils.Dist2D(node, coords) <= (maxDist or 40.0) then
        return node
    end
    return coords
end

function Utils.Nearest(list, from)
    local best, bestDist = nil, math.huge
    for _, entry in ipairs(list) do
        local dist = Utils.Dist2D(entry.coords, from)
        if dist < bestDist then
            best, bestDist = entry, dist
        end
    end
    return best
end

-- Random destination between minD and maxD away; falls back to the closest one beyond minD.
function Utils.PickDestination(list, from, minD, maxD)
    local candidates, fallback, fallbackDist = {}, nil, math.huge
    for _, entry in ipairs(list) do
        local dist = Utils.Dist2D(entry.coords, from)
        if dist >= minD and dist <= maxD then
            candidates[#candidates + 1] = entry
        elseif dist >= minD and dist < fallbackDist then
            fallback, fallbackDist = entry, dist
        end
    end
    if #candidates > 0 then
        return Utils.Pick(candidates)
    end
    return fallback or Utils.Pick(list)
end

-- ---------------------------------------------------------------------------
-- UI
-- ---------------------------------------------------------------------------

-- Help-text token for a RegisterKeyMapping command, e.g. "~INPUT_9A1B2C3D~".
function Utils.InputToken(command)
    local hash = GetHashKey(command) | 0x80000000
    return ('~INPUT_%X~'):format(hash & 0xFFFFFFFF)
end

function Utils.Help(text)
    BeginTextCommandDisplayHelp('STRING')
    AddTextComponentSubstringPlayerName(text)
    EndTextCommandDisplayHelp(0, false, false, -1)
end

function Utils.Notify(message, title, subtitle, icon)
    BeginTextCommandThefeedPost('STRING')
    AddTextComponentSubstringPlayerName(message)
    if title then
        icon = icon or 'CHAR_CHAT_CALL'
        EndTextCommandThefeedPostMessagetext(icon, icon, false, 1, title, subtitle or '')
    end
    EndTextCommandThefeedPostTicker(false, true)
end

function Utils.DrawText2D(text, x, y, scale, r, g, b, a, font)
    SetTextFont(font or 4)
    SetTextScale(scale, scale)
    SetTextColour(r, g, b, a)
    SetTextCentre(true)
    SetTextOutline()
    BeginTextCommandDisplayText('STRING')
    AddTextComponentSubstringPlayerName(text)
    EndTextCommandDisplayText(x, y)
end

function Utils.DrawProgress(label, pct)
    pct = math.max(0.0, math.min(1.0, pct))
    local x, y, w, h = 0.5, 0.885, 0.2, 0.018
    DrawRect(x, y, w + 0.004, h + 0.008, 0, 0, 0, 160)
    DrawRect(x - w / 2 + (w * pct) / 2, y, w * pct, h, 90, 200, 110, 220)
    Utils.DrawText2D(('%s %d%%'):format(label, math.floor(pct * 100)), x, y - 0.042, 0.4, 255, 255, 255, 230)
end

function Utils.Marker(coords, r, g, b)
    DrawMarker(0, coords.x, coords.y, coords.z, 0.0, 0.0, 0.0, 0.0, 0.0, 0.0, 0.35, 0.35, 0.35,
        r or 255, g or 210, b or 60, 180, true, true, 2, false, nil, nil, false)
end
