-- corlinks_foodvan - client
local MODEL = joaat(Config.Model)
local myInvoice = nil      -- invoice the customer must pay
local menuVan = nil        -- van net id while the menu is open
local payHeld = false
local blips = {}
local myShop = nil         -- net id of the van I am running

local function notify(msg, t, ms) TriggerEvent('QBCore:Notify', msg, t or 'primary', ms or 6000) end
local function nui(action, data) data = data or {}; data.action = action; SendNUIMessage(data) end

local function isFoodVan(veh) return veh and veh ~= 0 and DoesEntityExist(veh) and GetEntityModel(veh) == MODEL end

-- true when the player stands on the hatch (awning, -x) side of the van
local function atHatch(veh)
    local off = GetOffsetFromEntityGivenWorldCoords(veh, GetEntityCoords(PlayerPedId()))
    return off.x < -0.5 and math.abs(off.y) < 3.2
end

local function menuData()
    local items = {}
    for _, it in ipairs(Config.Menu) do
        items[#items + 1] = { name = it.name, label = it.label, price = it.price, kind = it.kind, desc = it.desc,
            img = ('../images/%s.png'):format(it.name), alt = ('nui://ox_inventory/web/images/%s.png'):format(it.name) }
    end
    return items
end

-- seller --------------------------------------------------------------------------
local function toggleShop()
    local ped = PlayerPedId()
    local veh = GetVehiclePedIsIn(ped, false)
    if not isFoodVan(veh) then veh = lib.getClosestVehicle(GetEntityCoords(ped), 4.0, false) end
    if not isFoodVan(veh) then notify('You need to be in your food van.', 'error') return end
    local r = lib.callback.await('corlinks_foodvan:toggle', false, VehToNet(veh))
    if not r or not r.ok then notify(r and r.err or 'Could not open the van.', 'error') return end
    if r.open then
        myShop = VehToNet(veh)
        nui('seller', { show = true, shop = Config.ShopName, sales = 0, earned = 0 })
        notify(Config.ShopName .. ' is OPEN. Customers order at the hatch.', 'success')
    else
        myShop = nil
        nui('seller', { show = false })
        notify(('%s closed. %d sales, $%d earned.'):format(Config.ShopName, r.sales or 0, r.earned or 0), 'primary', 9000)
    end
end
RegisterCommand('foodvan', toggleShop, false)
TriggerEvent('chat:addSuggestion', '/foodvan', 'Open or close your food van (sit in the tacotuck)')

RegisterNetEvent('corlinks_foodvan:incoming', function(inv)
    nui('incoming', { inv = inv })
    PlaySoundFrontend(-1, 'Text_Arrive_Tone', 'Phone_SoundSet_Default', true)
end)
RegisterNetEvent('corlinks_foodvan:sold', function(inv, acc, sales, earned)
    nui('sold', { id = inv.id, total = inv.total, who = inv.customerName, sales = sales, earned = earned, acc = acc })
    PlaySoundFrontend(-1, 'PURCHASE', 'HUD_LIQUOR_STORE_SOUNDSET', true)
end)
RegisterNetEvent('corlinks_foodvan:declined', function(inv)
    nui('declined', { id = inv.id, who = inv.customerName })
end)

-- customer ------------------------------------------------------------------------
local function openMenu(veh)
    local net = VehToNet(veh)
    local st = lib.callback.await('corlinks_foodvan:status', false, net)
    if not st or not st.open then notify('The hatch is shut - nobody is serving.', 'error') return end
    if st.mine then notify("That's your own van.", 'error') return end
    if myInvoice then notify('Pay or decline your invoice first (hold ALT).', 'error') return end
    menuVan = net
    SetNuiFocus(true, true)
    nui('menu', { show = true, shop = Config.ShopName, seller = st.seller, items = menuData(), max = Config.MaxPerItem })
end

CreateThread(function()
    exports.ox_target:addModel(Config.Model, {
        {
            name = 'murko_order', icon = 'fa-solid fa-burger', label = 'Order at ' .. Config.ShopName, distance = Config.OrderDistance,
            canInteract = function(entity)
                if IsPedInAnyVehicle(PlayerPedId(), false) then return false end
                return atHatch(entity)
            end,
            onSelect = function(data) openMenu(data.entity) end,
        },
    })
end)

RegisterNUICallback('close', function(_, cb)
    menuVan = nil
    if not payHeld then SetNuiFocus(false, false) end
    cb(1)
end)

RegisterNUICallback('order', function(data, cb)
    local net = menuVan
    menuVan = nil
    SetNuiFocus(false, false)
    if not net then cb(1) return end
    local r = lib.callback.await('corlinks_foodvan:order', false, net, data.cart or {})
    if not r or not r.ok then notify(r and r.err or 'Order failed.', 'error') end
    cb(1)
end)

RegisterNetEvent('corlinks_foodvan:invoice', function(inv, secs)
    myInvoice = inv
    nui('invoice', { inv = inv, secs = secs, key = 'ALT' })
    PlaySoundFrontend(-1, 'Text_Arrive_Tone', 'Phone_SoundSet_Default', true)
    notify(('Invoice from %s: $%d. Hold ALT and press PAY.'):format(inv.sellerName ~= '' and inv.sellerName or 'Murko', inv.total), 'primary', 8000)
end)

RegisterNetEvent('corlinks_foodvan:invoiceGone', function(id, reason)
    if myInvoice and myInvoice.id == id then myInvoice = nil end
    nui('invoiceGone', { id = id })
    if payHeld then SetNuiFocus(false, false); SetNuiFocusKeepInput(false) end
    notify(reason or 'Invoice cancelled.', 'error')
end)

RegisterNetEvent('corlinks_foodvan:paid', function(inv, acc)
    myInvoice = nil
    nui('paid', { id = inv.id, total = inv.total, acc = acc, ms = Config.PrepareMs })
    if payHeld then SetNuiFocus(false, false); SetNuiFocusKeepInput(false) end
    PlaySoundFrontend(-1, 'PURCHASE', 'HUD_LIQUOR_STORE_SOUNDSET', true)
end)

RegisterNetEvent('corlinks_foodvan:served', function(inv)
    nui('served', { id = inv.id })
    notify('Order up! Your food is in your pockets.', 'success')
end)

RegisterNUICallback('pay', function(data, cb)
    if myInvoice and data.id == myInvoice.id then TriggerServerEvent('corlinks_foodvan:pay', myInvoice.id) end
    cb(1)
end)
RegisterNUICallback('decline', function(data, cb)
    if myInvoice and data.id == myInvoice.id then
        TriggerServerEvent('corlinks_foodvan:decline', myInvoice.id)
        myInvoice = nil
        nui('invoiceGone', { id = data.id })
        if payHeld then SetNuiFocus(false, false); SetNuiFocusKeepInput(false) end
    end
    cb(1)
end)
RegisterNUICallback('cancel', function(data, cb)
    TriggerServerEvent('corlinks_foodvan:cancel', tonumber(data.id))
    cb(1)
end)

-- hold ALT -> cursor on the invoice -------------------------------------------------
RegisterCommand('+murko_pay', function()
    if not myInvoice or menuVan then return end
    payHeld = true
    SetNuiFocus(true, true)
    SetNuiFocusKeepInput(true)
    nui('payMode', { on = true })
    CreateThread(function()
        while payHeld do
            DisableControlAction(0, 1, true); DisableControlAction(0, 2, true)       -- look
            DisableControlAction(0, 24, true); DisableControlAction(0, 25, true)     -- attack / aim
            DisableControlAction(0, 257, true); DisableControlAction(0, 140, true)
            DisableControlAction(0, 142, true); DisableControlAction(0, 106, true)
            Wait(0)
        end
    end)
end, false)
RegisterCommand('-murko_pay', function()
    if not payHeld then return end
    payHeld = false
    SetNuiFocusKeepInput(false)
    if not menuVan then SetNuiFocus(false, false) end
    nui('payMode', { on = false })
end, false)
RegisterKeyMapping('+murko_pay', "Murko's food van - hold to pay invoice", 'keyboard', Config.PayKey)

-- map blips for open vans ---------------------------------------------------------
local function clearBlips() for _, b in pairs(blips) do RemoveBlip(b) end; blips = {} end
RegisterNetEvent('corlinks_foodvan:shops', function(list)
    clearBlips()
    if not Config.ShowBlip then return end
    for _, s in ipairs(list or {}) do
        local b = AddBlipForCoord(s.x, s.y, s.z)
        SetBlipSprite(b, 52); SetBlipColour(b, 27); SetBlipScale(b, 0.8); SetBlipAsShortRange(b, true)
        BeginTextCommandSetBlipName('STRING'); AddTextComponentSubstringPlayerName(Config.ShopName .. ' (open)'); EndTextCommandSetBlipName(b)
        blips[#blips + 1] = b
    end
end)

CreateThread(function()
    Wait(3000)
    local list = lib.callback.await('corlinks_foodvan:shops', false)
    TriggerEvent('corlinks_foodvan:shops', list)
end)

AddEventHandler('onResourceStop', function(res)
    if res ~= GetCurrentResourceName() then return end
    clearBlips(); SetNuiFocus(false, false); SetNuiFocusKeepInput(false)
end)
