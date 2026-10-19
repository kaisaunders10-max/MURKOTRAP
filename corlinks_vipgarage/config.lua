Config = {}
Config.Command   = 'vipeditor'                  -- /vipeditor
Config.Ace       = 'corlinks.vipeditor'         -- add_ace group.vip corlinks.vipeditor allow   (to give VIPs access later)
Config.QBPerms   = { 'god', 'admin' }           -- QBCore permission groups that can use it
Config.AdminAces = { 'command', 'corlinks.admin' } -- anyone with these ACEs (server.cfg: add_ace group.admin command allow) can use it
-- apex_adminmenu staff (apex_staff table): groups whose name CONTAINS one of these can use it
Config.StaffGroups = { 'director', 'management', 'admin', 'owner', 'founder', 'dev', 'god' }
Config.SaveOwned = true                         -- save the look to player_vehicles when the car is owned
Config.Range     = 6.0                          -- on foot: edit the car you're standing next to
Config.LiveryFolder = '[Corlinks_Liverys]'       -- Apex Vehicle Studio packs live here (read fresh every time the editor opens)
