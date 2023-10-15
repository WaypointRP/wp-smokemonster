local isSmokeMonster = false

-- Used to keep track of all the active smokemonster particle effects and whether it has been synced on this client yet
-- [netId] = { isSmokeMonster: boolean, particleFxHandle: number, hasSynced: boolean }
local particleFxHandleList = {}

-----------------------------------------------
-- Functions
-----------------------------------------------

-- Load a single particle asset and wait until its loaded
local function LoadParticleAsset(asset)
    if not HasNamedPtfxAssetLoaded(asset) then
        RequestNamedPtfxAsset(asset)
        while not HasNamedPtfxAssetLoaded(asset) do
            Wait(1)
        end
    end
end

-- Starts the smoke monster particle effect on the entity
---@param entity - is the entity that the particle effect will be attached to
---@param entityNetId - is the network id of the entity
local function startSmokeMonsterParticleEffectOnEntity(entity, entityNetId)
    local particleAsset = "scr_xm_spybomb"
    local particleName = "scr_xm_spybomb_plane_smoke_trail"
    local particleScale = 0.2
    local color = { r = 0, g = 0, b = 0 }

    LoadParticleAsset(particleAsset)
    UseParticleFxAssetNextCall(particleAsset)

    local particleFxHandle = StartParticleFxLoopedOnEntity(
        particleName,
        entity,
        0.0,
        0.0,
        0.0,
        0.0,
        0.0,
        0.0,
        particleScale,
        0,
        0,
        0
    )

    SetParticleFxLoopedAlpha(particleFxHandle, 0.6)
    SetParticleFxLoopedColour(particleFxHandle, color.r, color.g, color.b, 0)
    
    particleFxHandleList[entityNetId] = {
        isSmokeMonster = true,
        particleFxHandle = particleFxHandle,
        hasSynced = true
    }
end

-- Toggles the smoke monster effect on/off for the current player
local function toggleSmokeMonster()
    isSmokeMonster = not isSmokeMonster

    local entity = PlayerPedId()
    local entityNetId = NetworkGetNetworkIdFromEntity(entity)

    if isSmokeMonster then -- Toggle On
        if Config.UseSmokeMonsterScreenEffect then AnimpostfxPlay("ChopVision") end
        TriggerEvent('wp-smokemonster:client:ToggleNoClip')

        startSmokeMonsterParticleEffectOnEntity(entity, entityNetId)

        -- The particle effect is a looped effect and does not automatically sync with other clients
        TriggerServerEvent('wp-smokemonster:server:SyncEffect', entityNetId, GetPlayerServerId(PlayerId()), true)
    else -- Toggle Off
        if Config.UseSmokeMonsterScreenEffect then AnimpostfxStop("ChopVision") end
        StopParticleFxLooped(particleFxHandleList[entityNetId].particleFxHandle, 0)
        TriggerServerEvent('wp-smokemonster:server:SyncEffect', entityNetId, GetPlayerServerId(PlayerId()), false)
        TriggerEvent('wp-smokemonster:client:ToggleNoClip')

        particleFxHandleList[entityNetId] = {
            isSmokeMonster = false,
            particleFxHandle = nil,
            hasSynced = false
        }
    end
end

-- Starts/stops the smoke monster effect on the given entityNetId, if the entity exists and has not yet been synced
-- This is used to sync the particle effect with other clients
---@param entityNetId - is the network id of the entity that the particle effect will be attached to
---@param hasSynced - is whether the particle effect for the given netId has already been synced on this client
local function syncSmokeMonsterParticleEffect(entityNetId, hasSynced)
    if not hasSynced and NetworkDoesNetworkIdExist(entityNetId) then
        local entity = NetworkGetEntityFromNetworkId(entityNetId)
        if entity and entity ~= 0 and DoesEntityExist(entity) then
            particleFxHandleList[entityNetId].hasSynced = true

            if particleFxHandleList[entityNetId].isSmokeMonster then
                startSmokeMonsterParticleEffectOnEntity(entity, entityNetId)
            else
                StopParticleFxLooped(particleFxHandleList[entityNetId].particleFxHandle, 0)
                particleFxHandleList[entityNetId] = {
                    isSmokeMonster = false,
                    particleFxHandle = nil,
                    hasSynced = false
                }
            end
        end
    else
        if not NetworkDoesNetworkIdExist(entityNetId) or not DoesEntityExist(NetworkGetEntityFromNetworkId(entityNetId)) then
            -- If entity does not exist, reset the hasSynced to false. 
            -- This is to handle a case where the entity did at exist, moved outside your culling distance and then comes back
            particleFxHandleList[entityNetId].hasSynced = false
        end
    end
end

-- Loops through the particleFxHandleList and syncs the smoke monster particle effect for all entities that exist on the client
local function syncAllSmokeMonsterParticleEffects()
    for entityNetId, v in pairs(particleFxHandleList) do
        syncSmokeMonsterParticleEffect(entityNetId, v.hasSynced)
    end
end

-- Adds the entityNetId to the particleFxHandleList if it does not yet exist, else if
-- it does exist do nothing so we dont override its fields
---@param entityNetId - is the network id of the entity that the particle effect will be attached to
local function initializeParticleFxHandleListByNetId(entityNetId)
    if particleFxHandleList[entityNetId] == nil then
        particleFxHandleList[entityNetId] = {
            isSmokeMonster = false,
            particleFxHandle = nil,
            hasSynced = false
        }
    end
end

-- Fetches the particleFxHandleList from the server and then syncs to all entities that exist on the client
-- This is primarily used to sync all active effects to a client that is just joining the server
local function fetchParticleFxHandleList()
    local p = promise.new()

    TriggerCallback("wp-smokemonster:server:FetchParticleFxHandleList", function(result)
        p:resolve(result)
    end)

    local particlesList = Citizen.Await(p)
    particleFxHandleList = particlesList

    syncAllSmokeMonsterParticleEffects()
end

-----------------------------------------------
-- NUI Callbacks and Events
-----------------------------------------------

-- On PlayerLoaded, fetch the list of particleFxHandleList and sync to the entities
RegisterNetEvent('QBCore:Client:OnPlayerLoaded', function() 
    fetchParticleFxHandleList() 
end)

-- Trigger this event to toggle the effect on/off
RegisterNetEvent("wp-smokemonster:client:ToggleSmokeMonster", function()
    toggleSmokeMonster()
end)

-- Anytime a client starts/stops the smokemonster effect, all clients will receive this event to sync the change
-- This is necessary since the StartParticleFxLoopedOnEntity native does not sync automatically
---@param entityNetId - number - the network id of the entity that the particle effect will be attached to
---@param callerPlayerId - number - the PlayerId of the player who used the effect (used to make sure we dont sync the effect on their end twice)
---@param isPlayingEffect - boolean -whether the effect is being started or stopped (true for active, false for stopped)
RegisterNetEvent('wp-smokemonster:client:SyncEffect', function(entityNetId, callerPlayerId, isPlayingEffect) 
    if callerPlayerId ~= GetPlayerServerId(PlayerId()) then
        initializeParticleFxHandleListByNetId(entityNetId)
        particleFxHandleList[entityNetId].isSmokeMonster = isPlayingEffect
        particleFxHandleList[entityNetId].hasSynced = false
        syncSmokeMonsterParticleEffect(entityNetId, false)
    end
end)


-- This thread acts as a periodic delta sync to keep all clients in sync with the smokemonster particle effects
-- This mainly handles the case where someone enables the effect when they are out of range of the current client (outside the culling distance)
-- When the entity does come into range, this thread will sync the effect to the client
-- If we detect that we've already synced the effect for the given netId, then we will short circuit the logic
-- Unfortunately this thread needs to always run to make sure that it picks up any changes, the wait time is intentionally slow to offset the perf hits
CreateThread(function()
    while true do
        syncAllSmokeMonsterParticleEffects()

        Wait(20000)
    end
end)

AddEventHandler('onResourceStop', function(resourceName)
    if resourceName == ResourceName then
        if Config.UseSmokeMonsterScreenEffect then AnimpostfxStop("ChopVision") end
    end
end)
