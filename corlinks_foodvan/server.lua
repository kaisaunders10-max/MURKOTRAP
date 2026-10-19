-- corlinks_foodvan - server
-- Murko opens the shop from inside the tacotuck. Customers order at the hatch, get an invoice,
-- hold ALT and press PAY: the money goes straight to Murko and the food goes to the customer.
local QBCore = exports['qb-core']:GetCoreObject()
local MODEL = joaat(Config.Model)
local MENU = {}
for _, it in ipairs(Config.Menu) do MENU[it.name] = it end

local Shops = {}      -- [vanNet] = { seller = src, sellerName, opened, sales, earned }
local Invoices = {}   -- [id] = { id, van, seller, customer, lines, total, created }
local nextId = 1000

local function P(src) return QBCore.Functions.GetPlayer(src) end
local function name(src)
    local p = P(src); local c = p and p.PlayerData.charinfo or {}
    return ((c.firstname or '') .. ' ' .. (c.lastname or '')):gsub('^%s+', ''):gsub('%s+$', '')
end
local function notify(src, msg, t, ms) TriggerClientEvent('QBCore:Notify', src, msg, t or 'primary', ms or 6000) end
local function vanFromNet(net)
    if type(net) ~= 'number' then return nil end
    local v = NetworkGetEntityFromNetworkId(net)
    if not v or v == 0 or not DoesEntityExist(v) or GetEntityModel(v) ~= MODEL then return nil end
    return v
end
local function dist(src, ent) return #(GetEntityCoords(GetPlayerPed(src)) - GetEntityCoords(ent)) end
local function isOwner(src)
    if #Config.Owners == 0 then return true end
    local p = P(src); if not p then return false end
    for _, cid in ipairs(Config.Owners) do if p.PlayerData.citizenid == cid then return true end end
    return false
end
local function shopList()
    local out = {}
    for net, s in pairs(Shops) do
        local v = vanFromNet(net)
        if v then local c = GetEntityCoords(v); out[#out + 1] = { net = net, seller = s.sellerName, x = c.x, y = c.y, z = c.z } end
    end
    return out
end
local function broadcast() TriggerClientEvent('corlinks_foodvan:shops', -1, shopList()) end

-- ── seller: open / close ────────────────────────────────────────────────
lib.callback.register('corlinks_foodvan:toggle', function(src, net)
    local v = vanFromNet(net)
    if not v then return { ok = false, err = 'You need to be in a food van.' } end
    if GetVehiclePedIsIn(GetPlayerPed(src), false) ~= v and dist(src, v) > 4.0 then return { ok = false, err = 'Get in the van first.' } end
    if Shops[net] then
        if Shops[net].seller ~= src then return { ok = false, err = Shops[net].sellerName .. ' is running this van.' } end
        local s = Shops[net]; Shops[net] = nil
        for id, inv in pairs(Invoices) do if inv.van == net then Invoices[id] = nil; TriggerClientEvent('corlinks_foodvan:invoiceGone', inv.customer, id, 'The van closed.') end end
        broadcast()
        return { ok = true, open = false, sales = s.sales, earned = s.earned }
    end
    if not isOwner(src) then return { ok = false, err = 'Only the owner can open this van.' } end
    for n, s in pairs(Shops) do if s.seller == src then Shops[n] = nil end end
    Shops[net] = { seller = src, sellerName = name(src), opened = os.time(), sales = 0, earned = 0 }
    broadcast()
    return { ok = true, open = true }
end)

lib.callback.register('corlinks_foodvan:status', function(src, net)
    local s = Shops[net]
    return { open = s ~= nil, seller = s and s.sellerName or nil, mine = s and s.seller == src or false, sales = s and s.sales or 0, earned = s and s.earned or 0 }
end)

-- ── customer: order -> invoice ──────────────────────────────────────────
lib.callback.register('corlinks_foodvan:order', function(src, net, cart)
    local v = vanFromNet(net); local s = Shops[net]
    if not v or not s then return { ok = false, err = 'This van is closed.' } end
    if s.seller == src then return { ok = false, err = "You can't order from your own van." } end
    if dist(src, v) > Config.OrderDistance + 4.0 then return { ok = false, err = 'Walk up to the hatch.' } end
    if not GetPlayerName(s.seller) or dist(s.seller, v) > Config.SellerDistance then return { ok = false, err = 'Nobody is serving right now.' } end
    for _, inv in pairs(Invoices) do if inv.customer == src then return { ok = false, err = 'Pay or decline your last invoice first.' } end end
    local lines, total, count = {}, 0, 0
    for item, qty in pairs(type(cart) == 'table' and cart or {}) do
        local it = MENU[item]; qty = math.floor(tonumber(qty) or 0)
        if it and qty > 0 then
            qty = math.min(qty, Config.MaxPerItem)
            lines[#lines + 1] = { name = item, label = it.label, qty = qty, price = it.price, sum = qty * it.price }
            total = total + qty * it.price; count = count + qty
        end
    end
    if count == 0 then return { ok = false, err = 'Your order is empty.' } end
    table.sort(lines, function(a, b) return a.label < b.label end)
    nextId = nextId + 1
    local inv = { id = nextId, van = net, seller = s.seller, sellerName = s.sellerName, customer = src, customerName = name(src),
        lines = lines, total = total, created = os.time(), shop = Config.ShopName }
    Invoices[inv.id] = inv
    TriggerClientEvent('corlinks_foodvan:invoice', src, inv, Config.InvoiceSeconds)
    TriggerClientEvent('corlinks_foodvan:incoming', s.seller, inv)
    return { ok = true, id = inv.id }
end)

local function payWith(p, amount)
    if (p.PlayerData.money.cash or 0) >= amount then return 'cash' end
    if (p.PlayerData.money.bank or 0) >= amount then return 'bank' end
    return nil
end

RegisterNetEvent('corlinks_foodvan:pay', function(id)
    local src = source
    local inv = Invoices[tonumber(id) or -1]
    if not inv or inv.customer ~= src then return end
    local v = vanFromNet(inv.van)
    if not v or not Shops[inv.van] then Invoices[inv.id] = nil; TriggerClientEvent('corlinks_foodvan:invoiceGone', src, inv.id, 'The van closed.') return end
    if dist(src, v) > Config.OrderDistance + 6.0 then notify(src, 'Stay at the hatch to pay.', 'error') return end
    local buyer, seller = P(src), P(inv.seller)
    if not buyer or not seller then Invoices[inv.id] = nil; TriggerClientEvent('corlinks_foodvan:invoiceGone', src, inv.id, 'Murko left.') return end
    -- can they carry it?
    for _, l in ipairs(inv.lines) do
        if not exports.ox_inventory:CanCarryItem(src, l.name, l.qty) then notify(src, "Your pockets are full - make some space first.", 'error') return end
    end
    local acc = payWith(buyer, inv.total)
    if not acc then notify(src, ("You can't afford that ($%d)."):format(inv.total), 'error') return end
    Invoices[inv.id] = nil
    if not buyer.Functions.RemoveMoney(acc, inv.total, 'murko-foodvan-order') then notify(src, 'Payment failed.', 'error') return end
    seller.Functions.AddMoney(acc, inv.total, 'murko-foodvan-sale')
    local s = Shops[inv.van]; s.sales = s.sales + 1; s.earned = s.earned + inv.total
    TriggerClientEvent('corlinks_foodvan:paid', src, inv, acc)
    TriggerClientEvent('corlinks_foodvan:sold', inv.seller, inv, acc, s.sales, s.earned)
    SetTimeout(Config.PrepareMs, function()
        for _, l in ipairs(inv.lines) do exports.ox_inventory:AddItem(src, l.name, l.qty) end
        if GetPlayerName(src) then TriggerClientEvent('corlinks_foodvan:served', src, inv) end
    end)
end)

RegisterNetEvent('corlinks_foodvan:decline', function(id)
    local src = source
    local inv = Invoices[tonumber(id) or -1]
    if not inv or inv.customer ~= src then return end
    Invoices[inv.id] = nil
    TriggerClientEvent('corlinks_foodvan:declined', inv.seller, inv)
end)

-- seller can cancel an unpaid order
RegisterNetEvent('corlinks_foodvan:cancel', function(id)
    local src = source
    local inv = Invoices[tonumber(id) or -1]
    if not inv or inv.seller ~= src then return end
    Invoices[inv.id] = nil
    TriggerClientEvent('corlinks_foodvan:invoiceGone', inv.customer, inv.id, 'Murko cancelled the order.')
end)

-- ── housekeeping ────────────────────────────────────────────────────────
CreateThread(function()
    while true do
        Wait(5000)
        local t = os.time()
        for id, inv in pairs(Invoices) do
            if t - inv.created > Config.InvoiceSeconds or not GetPlayerName(inv.customer) then
                Invoices[id] = nil
                if GetPlayerName(inv.customer) then TriggerClientEvent('corlinks_foodvan:invoiceGone', inv.customer, id, 'The invoice expired.') end
            end
        end
        local changed = false
        for net, s in pairs(Shops) do
            local v = vanFromNet(net)
            if not v or not GetPlayerName(s.seller) or dist(s.seller, v) > Config.SellerDistance * 3 then
                Shops[net] = nil; changed = true
                if GetPlayerName(s.seller) then notify(s.seller, Config.ShopName .. ' closed - you left the van.', 'error') end
            end
        end
        if changed or Config.ShowBlip then broadcast() end
    end
end)

AddEventHandler('playerDropped', function()
    local src = source
    for net, s in pairs(Shops) do if s.seller == src then Shops[net] = nil end end
    for id, inv in pairs(Invoices) do if inv.customer == src then Invoices[id] = nil end end
end)

-- ── the combo box opens into its three items ───────────────────────────
exports('openCombo', function(event, item, inventory, slot, data)
    if event == 'usingItem' then
        local src = inventory.id
        if not exports.ox_inventory:CanCarryItem(src, 'murko_taco', 1) then notify(src, 'No space for the combo.', 'error') return false end
        return true
    elseif event == 'usedItem' then
        local src = inventory.id
        exports.ox_inventory:AddItem(src, 'murko_taco', 1)
        exports.ox_inventory:AddItem(src, 'murko_fries', 1)
        exports.ox_inventory:AddItem(src, 'murko_shake', 1)
        notify(src, 'You open the combo box: taco, fries and a shake.', 'success')
    end
end)

lib.callback.register('corlinks_foodvan:shops', function() return shopList() end)
