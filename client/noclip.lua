-- This is based on the noclip from qb-adminmenu, but modified to work with the smoke monster effect and slightly better controls 

local IsNoClipping      = false
local PlayerPed         = nil
local NoClipEntity      = nil
local Camera            = nil
local NoClipAlpha       = nil
local PlayerIsInVehicle = false
local ResourceName      = GetCurrentResourceName()

-- Tracks a dummy vehicle that is created when we enter noclip
-- This was necessary because of an issue with the up/down movements when using SetEntityCoordsNoOffset or SetEntityCoords
-- The up/down movements look fine on the client moving, but for other clients it only updates in steps of 1.0
-- Not sure why this issue is happening, but found that it works perfect if the player is in a vehicle
-- Until a better solution can be found, the dummyVehicle is used so the movement is smooth between all clients
local dummyVehicle = nil

local MinY, MaxY        = -89.0, 89.0

--[[
        Configurable values are commented.
]]

-- Perspective values
local PedFirstPersonNoClip      = false      -- No Clip in first person when not in a vehicle
local VehFirstPersonNoClip      = false      -- No Clip in first person when in a vehicle

-- Speed settings
local Speed                     = 0.5         -- Default: 1
local MaxSpeed                  = 16.0      -- Default: 16.0
local MinSpeed                  = 0.1       -- Default: 0.1

-- Key bindings
local MOVE_FORWARDS             = 32        -- Default: W
local MOVE_BACKWARDS            = 33        -- Default: S
local MOVE_LEFT                 = 34        -- Default: A
local MOVE_RIGHT                = 35        -- Default: D
local MOVE_UP                   = 44        -- Default: Q
local MOVE_DOWN                 = 20        -- Default: Z

local SPEED_DECREASE            = 14        -- Default: Mouse wheel down
local SPEED_INCREASE            = 15        -- Default: Mouse wheel up
local SPEED_RESET               = 348       -- Default: Mouse wheel click
local SPEED_SLOW_MODIFIER       = 36        -- Default: Left Control
local SPEED_FAST_MODIFIER       = 21        -- Default: Left Shift
local SPEED_FASTER_MODIFIER     = 19        -- Default: Left Alt


local DisabledControls = function()
    HudWeaponWheelIgnoreSelection()
    DisableAllControlActions(0)
    DisableAllControlActions(1)
    DisableAllControlActions(2)
    EnableControlAction(0, 220, true)
    EnableControlAction(0, 221, true)
    EnableControlAction(0, 245, true)
end

local IsControlAlwaysPressed = function(inputGroup, control)
    return IsControlPressed(inputGroup, control) or IsDisabledControlPressed(inputGroup, control)
end

local IsPedDrivingVehicle = function(ped, veh)
    return ped == GetPedInVehicleSeat(veh, -1)
end

local SetupCam = function(coords, rotation)
    local entityRot = GetEntityRotation(NoClipEntity)
    Camera = CreateCameraWithParams("DEFAULT_SCRIPTED_CAMERA", GetEntityCoords(NoClipEntity), vector3(0.0, 0.0, entityRot.z), 100.0)
    SetCamActive(Camera, true)
    RenderScriptCams(true, true, 1000, false, false)

    AttachCamToEntity(Camera, NoClipEntity, 0.0, 0.0, 0.0, true)
end

local DestroyCamera = function(entity)
    SetGameplayCamRelativeHeading(0)
    RenderScriptCams(false, true, 1000, true, true)
    DetachEntity(NoClipEntity, true, true)
    SetCamActive(Camera, false)
    DestroyCam(Camera, true)
end

local CheckInputRotation = function()
    local rightAxisX = GetControlNormal(0, 220)
    local rightAxisY = GetControlNormal(0, 221)

    local rotation = GetCamRot(Camera, 2)

    local yValue = rightAxisY * -5
    local newX
    local newZ = rotation.z + (rightAxisX * -10)
    if (rotation.x + yValue > MinY) and (rotation.x + yValue < MaxY) then
        newX = rotation.x + yValue
    end
    if newX ~= nil and newZ ~= nil then
        SetCamRot(Camera, vector3(newX, rotation.y, newZ), 2)
    end
    
    SetEntityHeading(NoClipEntity, math.max(0, (rotation.z % 360)))        
end

local function spawnVehicle()
    local vehicleModel = "panto"
    local ped = PlayerPedId()
    local hash = GetHashKey(vehicleModel)
    if not IsModelInCdimage(hash) then return end
    RequestModel(hash)
    while not HasModelLoaded(hash) do
        Wait(0)
    end
    local vehicle = CreateVehicle(hash, GetEntityCoords(ped), GetEntityHeading(ped), true, false)
    local vehiclePlate = GetVehicleNumberPlateText(vehicle)
    dummyVehicle = vehicle
    SetEntityVisible(vehicle, false, false)
    SetEntityVisible(ped, false, false)
    TaskWarpPedIntoVehicle(ped, vehicle, -1)
    TriggerEvent("vehiclekeys:client:SetOwner", vehiclePlate) -- This is so it doesnt show "you dont have keys"
    SetVehicleFuelLevel(vehicle, 100.0)
    exports["LegacyFuel"]:SetFuel(vehicle, 100) -- so it doesnt beep low fuel
    SetVehicleRadioEnabled(vehicle, false)
    SetVehicleEngineOn(vehicle, false, true, true)
    SetModelAsNoLongerNeeded(hash)
end

RunNoClipThread = function()
    CreateThread(function()
        while IsNoClipping do
            Wait(0)
            CheckInputRotation()
            DisabledControls()

            if IsControlAlwaysPressed(2, SPEED_DECREASE) then
                Speed = Speed - 0.1
                if Speed < MinSpeed then
                    Speed = MinSpeed
                end
            elseif IsControlAlwaysPressed(2, SPEED_INCREASE) then
                Speed = Speed + 0.1
                if Speed > MaxSpeed then
                    Speed = MaxSpeed
                end
            elseif IsDisabledControlJustReleased(0, SPEED_RESET) then
                Speed = 1
            end

            local multi = 1.0
            if IsControlAlwaysPressed(0, SPEED_FAST_MODIFIER) then
                multi = 2			
            elseif IsControlAlwaysPressed(0, SPEED_FASTER_MODIFIER) then
                multi = 4			
            elseif IsControlAlwaysPressed(0, SPEED_SLOW_MODIFIER) then
                multi = 0.25
            end

            if IsControlAlwaysPressed(0, MOVE_FORWARDS) then
                local pitch = GetCamRot(Camera, 0)

                if pitch.x >= 0 then
                    SetEntityCoordsNoOffset(NoClipEntity, GetOffsetFromEntityInWorldCoords(NoClipEntity, 0.0, 0.5*(Speed * multi), (pitch.x*((Speed/2) * multi))/89))
                else
                    SetEntityCoordsNoOffset(NoClipEntity, GetOffsetFromEntityInWorldCoords(NoClipEntity, 0.0, 0.5*(Speed * multi), -1*((math.abs(pitch.x)*((Speed/2) * multi))/89)))
                end
            elseif IsControlAlwaysPressed(0, MOVE_BACKWARDS) then
                local pitch = GetCamRot(Camera, 2)

                if pitch.x >= 0 then
                    SetEntityCoordsNoOffset(NoClipEntity, GetOffsetFromEntityInWorldCoords(NoClipEntity, 0.0, -0.5*(Speed * multi), -1*(pitch.x*((Speed/2) * multi))/89))
                else
                    SetEntityCoordsNoOffset(NoClipEntity, GetOffsetFromEntityInWorldCoords(NoClipEntity, 0.0, -0.5*(Speed * multi), ((math.abs(pitch.x)*((Speed/2) * multi))/89)))
                end
            end

            if IsControlAlwaysPressed(0, MOVE_LEFT) then 			
                SetEntityCoordsNoOffset(NoClipEntity, GetOffsetFromEntityInWorldCoords(NoClipEntity, -0.5*(Speed * multi), 0.0, 0.0))
            elseif IsControlAlwaysPressed(0, MOVE_RIGHT) then
                SetEntityCoordsNoOffset(NoClipEntity, GetOffsetFromEntityInWorldCoords(NoClipEntity, 0.5*(Speed * multi), 0.0, 0.0))
            end

            if IsControlAlwaysPressed(0, MOVE_UP) then 
                SetEntityCoordsNoOffset(NoClipEntity, GetOffsetFromEntityInWorldCoords(NoClipEntity, 0.0, 0.0, 0.5*(Speed * multi)))
            elseif IsControlAlwaysPressed(0, MOVE_DOWN) then
                SetEntityCoordsNoOffset(NoClipEntity, GetOffsetFromEntityInWorldCoords(NoClipEntity, 0.0, 0.0, -0.5*(Speed * multi)))
            end

            local coords = GetEntityCoords(NoClipEntity)
   
            RequestCollisionAtCoord(coords.x, coords.y, coords.z)

            FreezeEntityPosition(NoClipEntity, true)
            SetEntityCollision(NoClipEntity, false, false)
            SetEntityVisible(NoClipEntity, false, false)
            SetEntityInvincible(NoClipEntity, true)
            SetEveryoneIgnorePlayer(PlayerPed, true)
            SetPoliceIgnorePlayer(PlayerPed, true)
        end
        StopNoClip()
    end)
end

StopNoClip = function()
    FreezeEntityPosition(NoClipEntity, false)
    SetEntityCollision(NoClipEntity, true, true)
    SetEntityVisible(NoClipEntity, true, false)
    SetLocalPlayerVisibleLocally(true)
    ResetEntityAlpha(NoClipEntity)
    ResetEntityAlpha(PlayerPed)
    SetEveryoneIgnorePlayer(PlayerPed, false)
    SetPoliceIgnorePlayer(PlayerPed, false)
    ResetEntityAlpha(NoClipEntity)
    SetPoliceIgnorePlayer(PlayerPed, true)

    if GetVehiclePedIsIn(PlayerPed, false) ~= 0 then
        while (not IsVehicleOnAllWheels(NoClipEntity)) and not IsNoClipping do
            Wait(0)
        end
        while not IsNoClipping do
            Wait(0)
            if IsVehicleOnAllWheels(NoClipEntity) then
                return SetEntityInvincible(NoClipEntity, false)
            end
        end
    else
        if (IsPedFalling(NoClipEntity) and math.abs(1 - GetEntityHeightAboveGround(NoClipEntity)) > 1.00) then
            while (IsPedStopped(NoClipEntity) or not IsPedFalling(NoClipEntity)) and not IsNoClipping do
                Wait(0)
            end
        end
        while not IsNoClipping do
            Wait(0)
            if (not IsPedFalling(NoClipEntity)) and (not IsPedRagdoll(NoClipEntity)) then
                return SetEntityInvincible(NoClipEntity, false)
            end
        end
    end
end

ToggleNoClip = function(state)
    IsNoClipping = state or not IsNoClipping
    if IsNoClipping then
        spawnVehicle()
        Wait(1000)
    end
    PlayerPed    = PlayerPedId()
    PlayerIsInVehicle = IsPedInAnyVehicle(PlayerPed, false)
    if PlayerIsInVehicle ~= 0 and IsPedDrivingVehicle(PlayerPed, GetVehiclePedIsIn(PlayerPed, false)) then
        NoClipEntity = GetVehiclePedIsIn(PlayerPed, false)
        SetVehicleEngineOn(NoClipEntity, not IsNoClipping, true, IsNoClipping)
        NoClipAlpha = PedFirstPersonNoClip == true and 0 or 51
    else
        NoClipEntity = PlayerPed
        NoClipAlpha = VehFirstPersonNoClip == true and 0 or 51
    end

    if IsNoClipping then
        FreezeEntityPosition(PlayerPed)
        SetupCam()
        PlaySoundFromEntity(-1, "SELECT", PlayerPed, "HUD_LIQUOR_STORE_SOUNDSET", 0, 0)

        if not PlayerIsInVehicle then
            ClearPedTasksImmediately(PlayerPed)
            if PedFirstPersonNoClip then
                Wait(1000) -- Wait for the cinematic effect of the camera transitioning into first person 
            end
        else
            if VehFirstPersonNoClip then
                Wait(1000) -- Wait for the cinematic effect of the camera transitioning into first person 
            end
        end

    else
        DeleteVehicle(dummyVehicle)
        SetEntityVisible(PlayerPedId(), true, false)
        
        Wait(50)
        DestroyCamera(NoClipEntity)
        PlaySoundFromEntity(-1, "CANCEL", PlayerPed, "HUD_LIQUOR_STORE_SOUNDSET", 0, 0)
    end
    
    SetUserRadioControlEnabled(not IsNoClipping)
   
    if IsNoClipping then
        RunNoClipThread()
    end
end

RegisterNetEvent('wp-smokemonster:client:ToggleNoClip', function()
    ToggleNoClip(not IsNoClipping)
end)

AddEventHandler('onResourceStop', function(resourceName)
    if resourceName == ResourceName then
        FreezeEntityPosition(NoClipEntity, false)
        FreezeEntityPosition(PlayerPed, false)
        SetEntityCollision(NoClipEntity, true, true)
        SetEntityVisible(NoClipEntity, true, false)
        SetLocalPlayerVisibleLocally(true)
        ResetEntityAlpha(NoClipEntity)
        ResetEntityAlpha(PlayerPed)
        SetEveryoneIgnorePlayer(PlayerPed, false)
        SetPoliceIgnorePlayer(PlayerPed, false)
        ResetEntityAlpha(NoClipEntity)
        SetPoliceIgnorePlayer(PlayerPed, true)
        SetEntityInvincible(NoClipEntity, false)
        DeleteVehicle(dummyVehicle)
    end
end)
