-- IsDuplicityVersion - is used to determine if the function is called by the server or the client (true == from server)

--------------------- SHARED FUNCTIONS ---------------------
local Core = nil
--- @return table Core The core object of the framework
function GetCoreObject()
    if not Core then
        if Config.Framework == "esx" then
            Core = exports["es_extended"]:getSharedObject()
        elseif Config.Framework == "qb" or Config.Framework == "qbx" then
            Core = exports["qb-core"]:GetCoreObject()
        end
    end
    return Core
end

Core = Config.Framework ~= "none" and GetCoreObject() or nil

--- @param text string The text to show in the notification
--- @param notificationType string The type of notification to show ex: 'success', 'error', 'info'
--- @param src - number|nil The source of the player - only required when called from server side
function Notify(text, notificationType, src)
    if IsDuplicityVersion() then
        if Config.Notify == "esx" then
            TriggerClientEvent("esx:showNotification", src, text)
        elseif Config.Notify == "qb" then
            TriggerClientEvent("QBCore:Notify", src, text, notificationType)
        elseif Config.Notify == "ox" then
            TriggerClientEvent("ox_lib:notify", src, {
                description = text,
                type = notificationType,
            })
        end
    else
        if Config.Notify == "esx" then
            Core.ShowNotification(text)
        elseif Config.Notify == "qb" then
            Core.Functions.Notify(text, notificationType)
        elseif Config.Notify == "ox" then
            lib.notify({
                description = text,
                type = notificationType,
            })
        end
    end
end

--------------------- CLIENT FUNCTIONS ---------------------

--- @param name string The name of the event to trigger
--- @param cb function The callback to call when the event is triggered
--- @param ... any The arguments to pass to the event
--- @return any The return value of the event
function TriggerCallback(name, cb, ...)
    if IsDuplicityVersion() then return end
    if Config.Framework == "esx" then
        return Core.TriggerServerCallback(name, cb, ...)
    elseif Config.Framework == "qb" or Config.Framework == "qbx" then
        return Core.Functions.TriggerCallback(name, cb, ...)
    else
        warn("Invalid Config.Framework: <" .. tostring(Config.Framework) .. ">. Update TriggerCallback in framework.lua.")
    end
end

--------------------- SERVER FUNCTIONS ---------------------

function CreateCallback(...)
    if not IsDuplicityVersion() then return end
    if Config.Framework == "esx" then
        return Core.RegisterServerCallback(...)
    elseif Config.Framework == "qb" or Config.Framework == "qbx" then
        return Core.Functions.CreateCallback(...)
    else
        warn("Invalid Config.Framework: <" .. tostring(Config.Framework) .. ">. Update CreateCallback in framework.lua.")
    end
end
