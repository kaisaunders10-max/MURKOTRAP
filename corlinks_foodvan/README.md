# corlinks_foodvan - Murko's Cyber Taco

Only works on the `tacotuck` vehicle model.

## Seller (Murko)
- Get in the tacotuck and type `/foodvan` to OPEN. Type it again to CLOSE (shows sales + money earned).
- A panel on the left shows incoming orders, paid orders, sales and earnings.
- Stay within 12 m of the van or the shop closes itself.
- Lock it to Murko only: put your citizenid in `Config.Owners` in config.lua.

## Customer
- Walk up to the serving hatch (awning side) and third-eye the van -> "Order at Murko's Cyber Taco".
- Pick food with + / -, press SEND ORDER.
- An invoice pops up bottom-right. HOLD LEFT ALT to get the mouse, click PAY (or DECLINE).
- Money comes out of cash first, then bank, and goes straight to Murko.
- After a few seconds of "preparing", the food lands in your inventory.
- If ALT clashes with the third-eye key, rebind it: Settings > Key Bindings > FiveM > "Murko's food van - hold to pay invoice".

## Items
murko_taco, murko_burrito, murko_burger, murko_fries, murko_nachos, murko_shake, murko_slushie, murko_cola, murko_combo
(the combo box opens into taco + fries + shake). Prices are in config.lua.

## Install
1. Put `corlinks_foodvan` in resources and `ensure corlinks_foodvan` after ox_inventory / ox_target.
2. Paste `install/items.lua` into `ox_inventory/data/items.lua` (before the last `}`).
3. Copy `images/*.png` into `ox_inventory/web/images/`.
4. Full server restart (ox_inventory only reads items at start).
