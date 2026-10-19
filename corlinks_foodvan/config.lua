Config = {}

-- Only this vehicle model is a food van
Config.Model = 'tacotuck'
Config.ShopName = "Murko's Cyber Taco"

-- Who may open the shop (run it from the van). Empty = anyone sitting in a tacotuck.
-- Add citizenids to lock it to Murko, e.g. { 'ABC12345' }
Config.Owners = {}

-- Customers order at the serving hatch (the side with the awning)
Config.OrderDistance = 3.0        -- how close to the van the customer must be
Config.SellerDistance = 12.0      -- the seller must stay this close to the van while it is open
Config.InvoiceSeconds = 180       -- unpaid invoices expire after this
Config.MaxPerItem = 10
Config.PrepareMs = 4000           -- "Murko is preparing your order" before the food is handed over
Config.PayKey = 'LMENU'           -- hold this (Left Alt) to get the cursor and press PAY. Rebindable in Settings > Key Bindings > FiveM
Config.ShowBlip = true            -- open vans show on everyone's map

-- name = ox_inventory item, price in $, kind = food / drink
Config.Menu = {
    { name = 'murko_taco',    label = "Murko's Cyber Taco",   price = 25, kind = 'food',  desc = 'Neon-crunch shell, spiced beef, salsa, lettuce.' },
    { name = 'murko_burrito', label = "Murko's Mega Burrito", price = 35, kind = 'food',  desc = 'Rice, beans, chicken and cheese wrapped in foil.' },
    { name = 'murko_burger',  label = "Murko's Smash Burger", price = 30, kind = 'food',  desc = 'Double smashed patty, cheese, pickles, Murko sauce.' },
    { name = 'murko_fries',   label = "Murko's Fries",        price = 15, kind = 'food',  desc = 'Crispy fries in the magenta box. Salted.' },
    { name = 'murko_nachos',  label = "Murko's Neon Nachos",  price = 20, kind = 'food',  desc = 'Loaded nachos with melted cheese and jalapenos.' },
    { name = 'murko_shake',   label = "Murko's Purple Shake", price = 18, kind = 'drink', desc = 'Ube and vanilla shake with whipped cream.' },
    { name = 'murko_slushie', label = "Murko's Bru Slushie",  price = 12, kind = 'drink', desc = 'Ice-cold orange slushie. Scotland in a cup.' },
    { name = 'murko_cola',    label = "Murko's Cyber Cola",   price = 10, kind = 'drink', desc = 'Blue raspberry cola. Very fizzy.' },
    { name = 'murko_combo',   label = "Murko's Combo Box",    price = 60, kind = 'food',  desc = 'Taco, fries and a shake in one box.' },
}
