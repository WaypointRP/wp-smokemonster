ParticleFxHandleList = {}

-- This is used to sync the particle effects with other clients that are nearby where the effect is being used
-- This is only necessary for effects that use the StartParticleFxLoopedOnEntity native, 
-- the StartNetworkedParticleFxNonLoopedOnPedBone native already handles network syncing automatically
---@param netId number - is the network id of the entity that the particle effect is attached to
---@param callerPlayerId - is the PlayerId of the player who used the effect (used to make sure we dont sync the effect on their end twice)
---@param isPlayingEffect boolean - is whether the effect is being started or stopped (true for active, false for stopped)
RegisterNetEvent('wp-smokemonster:server:SyncEffect', function(netId, callerPlayerId, isPlayingEffect)
    ParticleFxHandleList[netId] = { isSmokeMonster = isPlayingEffect }
    TriggerClientEvent('wp-smokemonster:client:SyncEffect', -1, netId, callerPlayerId, isPlayingEffect)
end)

-- Returns the list of custom xenon headlight colors
CreateCallback("wp-smokemonster:server:FetchParticleFxHandleList", function(source, cb)
    cb(ParticleFxHandleList)
 end)

RegisterCommand("smokemonster", function(source, args)
    local src = source
    TriggerClientEvent("wp-smokemonster:client:ToggleSmokeMonster", src)
end, true)
