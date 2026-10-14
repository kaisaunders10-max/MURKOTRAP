# murko_civhelp — Civilians in need + karma

A standalone FiveM resource. It has no framework or database dependency and works on any server.

While you drive, a civilian at the roadside ahead may ask for help. A blip and a notification
show up, and you choose whether to **help** or **ignore** them. Helping earns
**+ Positive Karma** (big green text). Ignoring or abandoning someone gives **Bad Karma**
(big red text). Karma is saved per player (by Rockstar license) and survives restarts.

## Installation

1. Copy the `murko_civhelp` folder into your server's `resources` directory.
2. Add `ensure murko_civhelp` to `server.cfg`.
3. Optional, for testing: `add_ace group.admin command.civhelp_test allow`

## How it plays

| Step | What happens |
| --- | --- |
| Trigger | Every `CheckInterval` seconds, while you drive a land vehicle above `MinSpeedKmh`, there is a `Chance` roll. A scene spawns at the kerb 140–220 m ahead. |
| Request | Flashing blip, phone notification and help text. Press **Y** to help or **N** to ignore. You have `DecisionTime` seconds to choose. |
| Help | The scenario's objective shows at the bottom of the screen. |
| Result | Success: green **+ Positive Karma**. Ignoring, timing out, abandoning or failing: red **Bad Karma**. |

You can rebind Y/N in *Settings → Key Bindings → FiveM*.

## Scenarios

| ID | Area | Scene | Objective |
| --- | --- | --- | --- |
| `broken_down_car` | any | Smoking car with the hood up and hazards on, driver waving | Hold **E** at the hood to repair the engine. The driver thanks you and drives off. |
| `medical_emergency` | any | Collapsed civilian, a medkit, a panicking bystander | Hold **E** to do CPR, then drive the patient to the nearest hospital. |
| `lost_kid` | city | Worried parent and a dropped teddy bear | Search the marked area, find the kid, then walk or drive them back. |
| `mugging` | city | Victim on the ground with belongings scattered; the mugger runs off with a wallet | Catch the mugger, take the wallet (**E**) and give it back (**E**). |
| `stranded_hiker` | country | Hitchhiker with a duffel bag and a sleeping bag | Pick them up and drive them to their destination (Sandy Shores, Paleto, Chumash…). |
| `fire` | any | Burning dumpster and bin bags, a frightened bystander | You get a fire extinguisher; put out every fire. |
| `lost_dog` | any | Owner by the road with the dog's bowl and ball | Find the dog, whistle for it (**E**), walk or drive it back. |
| `elderly_ride` | city | Elderly civilian with shopping bags | Drive them home. Speeding and crashes lower their comfort and your reward. If comfort hits 0 the ride fails. |

GTA V has no child ped models, so `lost_kid` uses young-looking adult peds by default. If you
have an add-on child ped, put it in `Config.Models.Kids`.

## Karma

| Outcome | Default |
| --- | --- |
| Success | per scenario (`Config.Scenarios.<id>.karma`, 10–20). The elderly ride scales it by comfort. |
| Ignored (declined or timed out) | `-5` |
| Abandoned (drove more than `AbandonDistance` away, or `/civhelp cancel`) | `-10` |
| Failed (civilian died, mugger escaped, time limit, you died) | `-3` |

Ranks: Menace → Bad Apple → Bystander → Kind Stranger → Good Samaritan → Local Hero → Guardian Angel
(see `Config.Ranks`).

The server decides every karma amount; the client only reports the outcome. A success is only
accepted for the scenario the server saw offered, and only after `MinScenarioSeconds`. Positive
karma is also rate-limited by `MinSecondsBetweenRewards`.

## Commands

| Command | Who | Description |
| --- | --- | --- |
| `/karma` | everyone | Show your karma and rank |
| `/civhelp [on\|off]` | everyone | Turn random requests on or off for yourself (saved locally) |
| `/civhelp cancel` | everyone | Ignore the current request, or give up on the one you're doing (counts as abandoned) |
| `/civhelp_test [scenario]` | ACE `command.civhelp_test` | Spawn a request right now: a random one, or the given ID |
| `civhelp_setkarma <id> <value>` | console / ACE | Set a player's karma |

## Integration

Server exports:

```lua
exports.murko_civhelp:GetKarma(src)          -- number
exports.murko_civhelp:AddKarma(src, delta, reason)
exports.murko_civhelp:SetKarma(src, value)
exports.murko_civhelp:GetKarmaRank(src)      -- e.g. 'Good Samaritan'

AddEventHandler('murko_civhelp:karmaChanged', function(src, total, delta, reason) end)
```

The karma total is also replicated as a state bag: `Player(src).state.karma` (server) and
`LocalPlayer.state.karma` (client).

Client exports:

```lua
exports.murko_civhelp:GetKarma()             -- cached total
exports.murko_civhelp:IsBusy()               -- true while a request is offered or active
exports.murko_civhelp:SetEnabled(bool)       -- e.g. disable while on duty
exports.murko_civhelp:TriggerRequest(id)     -- force a request (id optional)
```

## Adding a scenario

Create `client/scenarios/my_scenario.lua` and add an entry to `Config.Scenarios`:

```lua
RegisterScenario('my_scenario', {
    label = 'Short name',
    request = '"What the civilian says"',
    setup = function(ctx)   -- build the scene; must call ctx:setContact(ped)
        local ped = ctx:spawnPed('a_m_y_hipster_01', ctx.coords, ctx.faceRoad)
        Utils.Wave(ped)
        ctx:setContact(ped)
    end,
    start = function(ctx)   -- player accepted
        ctx:setObjective('Do the thing.')
    end,
    update = function(ctx)  -- every frame; return 'success' or 'fail', reason
        if ctx:hold('task', GetEntityCoords(ctx.contact), 2.0, { help = 'help', progress = 'Helping', duration = 5000 }) then
            return 'success'
        end
    end,
})
```

`ctx` provides spawn helpers that clean up after themselves (`spawnPed`, `spawnVehicle`,
`spawnObject`, `attachObject`, `startFire`), blips, `hold`/`interact` prompts, `escort` (follow on
foot or ride along) and `ride` (a full "give them a lift" flow with route blip).

## Notes

- By default scene entities are client-side only (`Config.NetworkedEntities = false`). Each
  player's request is private, and this works even with strict entity lockdown. Set it to
  `true` to let other players see the scenes.
- Props are cosmetic. If a prop model is missing on your build, the scene still works.
- Ride destinations snap to the nearest road once you're within 300 m, so the coordinates in
  `config.lua` only need to be close.
