# Waypoint Smoke Monster

![wp-smokemonster-preview](https://github.com/WaypointRP/wp-smokemonster/assets/83190290/7882d926-bd36-4f2d-b72d-c97bd212cb54)

[Preview Video](https://youtu.be/r97PeiGR7EU)

Waypoint Smoke Monster is a simple script that lets the player become a flying smoke monster. The smoke monster can fly around the map, leaving a trail of smoke behind it. This can be used during Halloween events to scare players or could be used for any other purpose.

_The smoke monster from the TV show Lost was used as inspiration for this script._ 

# Usage

The smokemonster can be toggled on/off via the `/smokemonster` command or you can trigger it via the `wp-smokemonster:client:ToggleSmokeMonster` event. _The command can only be used by players with the `smokemonster` ace permission._

Controls:
- W/A/S/D: Move forward/backward/left/right
- Q/Z: Move up/down
- Hold SHIFT while moving any direction: Move faster
- Hold CTRL while moving any direction: Move slower
- Scroll wheel up/down: Change speed
- Scroll wheel click: Reset speed to default

# Performance

Resource monitor results:
- Idle (no smoke monsters): 0.00ms
- While active as a smoke monster: 0.05ms - 0.26ms 
    - Takes up less resources when sitting still
    - More resources are used as you move around since the particle effect leaves a trail behind the smoke monster
- Smoke monster active by another client, but not on this client: 0.00 - 0.01ms

# Setup
1. Enable the script in your server.cfg
2. Add the ace permission to the server.cfg
   - Ex: `add_ace group.admin smokemonster allow;`
   - For more info on ace permissions, see: https://forum.cfx.re/t/basic-aces-principals-overview-guide/90917
3. Choose your framework via `Config.Framework`
    - Framework is only needed for CreateCallback / TriggerCallback.
4. Choose whether you want a screen effect to be applied to the smoke monster's client via `Config.UseSmokeMonsterScreenEffect`

# Notes
We currently use a slightly customized version of qb-adminmenu noclip for controlling the movement of the smoke monster. There is a bug in the native functions SetEntityCoordsNoOffset and SetEntityCoords. The bug causes the up/down movements to only sync to other clients in steps of 1.0, even though on your own client it appears to be moving slowly. As a result any up/down movements will appear to be very choppy to other clients.

We found that _for some reason_, this issue does not happen while the player is in a vehicle. As a workaround, we spawn and place the player in a "dummyVehicle" and then set it to invisible. This allows the player to move around smoothly (on all clients) while in the smoke monster.
