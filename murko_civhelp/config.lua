Config = {}

-- Print extra information to the F8 / server console.
Config.Debug = false

-- When to roll for a new help request. A request can only pop up while the
-- player is driving a land vehicle (as the driver) above MinSpeedKmh.
Config.Trigger = {
    Enabled = true,
    CheckInterval = 15,         -- seconds between rolls
    Chance = 0.20,              -- chance (0-1) that a roll spawns a request
    Cooldown = 240,             -- seconds after a request ends before the next roll
    FirstDelay = 120,           -- seconds after joining before the first request
    MinSpeedKmh = 20.0,
    SpawnDistance = { min = 140.0, max = 220.0 }, -- metres ahead of the player
    RoadsideOffset = 6.5,       -- metres from the road node to the kerb
    BlockedVehicleClasses = { 14, 15, 16, 21 }, -- boats, helicopters, planes, trains
}

-- Seconds the player has to accept or ignore a request before it counts as ignored.
Config.DecisionTime = 25

-- Driving this far away from an accepted request abandons it.
Config.AbandonWarnDistance = 250.0
Config.AbandonDistance = 400.0

-- false = scenario entities only exist for the player who got the request.
-- This works on every server, including ones with strict entity lockdown.
-- Set to true to network them so other players can see the scenes too.
Config.NetworkedEntities = false

-- Default keys (players can rebind them in Settings > Key Bindings > FiveM).
Config.Keys = {
    Accept = 'Y',
    Decline = 'N',
}

-- Karma for outcomes other than success (success karma is set per scenario below).
Config.Karma = {
    Ignored = -5,     -- declined, or let the request time out
    Abandoned = -10,  -- accepted, then drove off / cancelled
    Failed = -3,      -- the civilian died, the mugger escaped, the time ran out...
    MinScenarioSeconds = 8,        -- server rejects a success reported faster than this
    MinSecondsBetweenRewards = 60, -- server-side anti-spam for positive karma
}

-- Karma ranks, checked from top to bottom.
Config.Ranks = {
    { min = 500, label = 'Guardian Angel' },
    { min = 250, label = 'Local Hero' },
    { min = 100, label = 'Good Samaritan' },
    { min = 25, label = 'Kind Stranger' },
    { min = -24, label = 'Bystander' },
    { min = -99, label = 'Bad Apple' },
    { min = -math.huge, label = 'Menace' },
}

-- Rough split between Los Santos (city) and Blaine County (country):
-- anything south of this Y coordinate counts as city.
Config.CityMaxY = 450.0

-- Per-scenario settings.
--   weight    relative chance of being picked
--   karma     karma for a successful outcome
--   timeLimit seconds after accepting before the request fails
--   area      'city', 'country' or 'any'
Config.Scenarios = {
    broken_down_car = { enabled = true, weight = 12, karma = 10, timeLimit = 300, area = 'any' },
    medical_emergency = { enabled = true, weight = 8, karma = 20, timeLimit = 600, area = 'any' },
    lost_kid = { enabled = true, weight = 8, karma = 15, timeLimit = 420, area = 'city' },
    mugging = { enabled = true, weight = 8, karma = 15, timeLimit = 300, area = 'city', muggerSpeed = 0.92, escapeDistance = 200.0 },
    stranded_hiker = { enabled = true, weight = 10, karma = 12, timeLimit = 900, area = 'country', minDistance = 700.0, maxDistance = 4500.0 },
    fire = { enabled = true, weight = 6, karma = 15, timeLimit = 300, area = 'any', removeExtinguisher = true },
    lost_dog = { enabled = true, weight = 8, karma = 10, timeLimit = 420, area = 'any' },
    elderly_ride = { enabled = true, weight = 10, karma = 15, timeLimit = 900, area = 'city', minDistance = 400.0, maxDistance = 3000.0, maxSpeedKmh = 90.0 },
}

Config.Models = {
    Civilians = {
        'a_m_m_business_01', 'a_f_y_business_01', 'a_m_y_hipster_01', 'a_f_y_hipster_02',
        'a_m_m_genfat_01', 'a_f_m_bevhills_01', 'a_m_y_genstreet_01', 'a_f_y_tourist_01',
        'a_m_m_skater_01', 'a_f_y_vinewood_01',
    },
    -- GTA V has no child ped models. These are the youngest-looking vanilla peds;
    -- swap in an add-on child ped if your server has one.
    Kids = { 'a_m_y_skater_01', 'a_m_y_skater_02', 'a_f_y_skater_01' },
    Elderly = { 'a_m_o_genstreet_01', 'a_f_o_genstreet_01', 'a_f_o_soucent_01', 'a_m_o_soucent_01', 'a_m_o_ktown_01', 'a_f_o_indian_01' },
    Hikers = { 'a_m_y_hiker_01', 'a_f_y_hiker_01' },
    Muggers = { 'a_m_y_methhead_01', 'a_m_y_stbla_02', 'a_m_y_stwhi_02', 'a_m_y_soucent_04' },
    Dogs = { 'a_c_retriever', 'a_c_shepherd', 'a_c_husky', 'a_c_rottweiler' },
    BrokenCars = { 'asea', 'emperor', 'ingot', 'primo', 'regina', 'stanier', 'premier', 'washington' },
}

-- Ride destinations. Coordinates only need to be close to a road: the script snaps
-- them to the nearest road node once the player gets near.
Config.Hospitals = {
    { label = 'Pillbox Hill Medical Center', coords = vector3(298.5, -584.4, 43.3) },
    { label = 'Central Los Santos Medical Center', coords = vector3(295.8, -1446.9, 29.9) },
    { label = 'Mount Zonah Medical Center', coords = vector3(-449.7, -340.8, 34.5) },
    { label = 'St. Fiacre Hospital', coords = vector3(1151.2, -1529.6, 35.4) },
    { label = 'Sandy Shores Medical Center', coords = vector3(1839.4, 3672.9, 34.3) },
    { label = 'The Bay Care Center', coords = vector3(-247.8, 6331.2, 32.4) },
}

Config.HikerDestinations = {
    { label = 'Sandy Shores', coords = vector3(1961.6, 3740.0, 32.3) },
    { label = 'Grapeseed', coords = vector3(1697.9, 4924.0, 42.1) },
    { label = 'Paleto Bay', coords = vector3(-448.5, 6011.6, 31.7) },
    { label = 'Pala Springs Aerial Tramway', coords = vector3(-745.5, 5595.4, 41.7) },
    { label = 'Harmony', coords = vector3(547.8, 2671.1, 42.2) },
    { label = 'Yellow Jack Inn', coords = vector3(1986.1, 3054.5, 47.2) },
    { label = 'Chumash', coords = vector3(-3241.9, 1001.5, 12.8) },
    { label = 'Legion Square', coords = vector3(195.2, -933.8, 30.7) },
    { label = 'Del Perro Pier', coords = vector3(-1604.5, -1048.8, 13.0) },
}

Config.ResidentialDestinations = {
    { label = 'Grove Street', coords = vector3(104.9, -1938.6, 20.8) },
    { label = 'Forum Drive', coords = vector3(-14.3, -1438.7, 31.1) },
    { label = 'Portola Drive, Rockford Hills', coords = vector3(-817.4, 178.0, 72.2) },
    { label = 'Whispymound Drive, Vinewood Hills', coords = vector3(7.9, 538.5, 176.0) },
    { label = 'Vespucci Beach apartments', coords = vector3(-1150.7, -1520.7, 10.6) },
    { label = 'Eclipse Towers', coords = vector3(-773.9, 309.8, 85.7) },
    { label = 'Del Perro Heights', coords = vector3(-1447.1, -537.6, 34.7) },
    { label = 'Tinsel Towers', coords = vector3(-614.0, 37.0, 43.6) },
    { label = 'Integrity Way', coords = vector3(-47.3, -585.9, 37.9) },
}

function GetKarmaRank(karma)
    for _, rank in ipairs(Config.Ranks) do
        if karma >= rank.min then
            return rank.label
        end
    end
    return 'Unknown'
end
