--[[
    Sonaran CAD Plugins

    Plugin Name: template
    Creator: template
    Description: Describe your plugin here

    Put all server-side logic in this file.
]]

local pluginConfig = Config.GetPluginConfig("esxsupport")

if pluginConfig.enabled then

    ESX = nil

    JobCache = {}

    CreateThread(function()
        local waited = 0
        while waited < 5 do
            if ESX == nil then
                TriggerEvent('esx:getSharedObject', function(obj) ESX = obj end)
                Wait(1000)
                debugLog("Waiting for ESX...")
            end
            waited = waited + 1
        end
        if ESX == nil then
            errorLog("[sonoran_esxsupport] ESX is not configured correctly, but you're attempting to use the ESX support plugin. Please set up ESX or disable this plugin.")
            return
        else
            infoLog("ESX support loaded successfully.")
        end
    end)

    -- Helper function to get the ESX Identity object from your database
    function GetIdentity(target, cb)
        local xPlayer = ESX.GetPlayerFromId(target)
        if xPlayer ~= nil then
            debugLog("GetIdentity OK")
            if cb ~= nil then
                debugLog("Running callback")
                cb(xPlayer)
            else
                debugLog("Running client event")
                TriggerClientEvent('SonoranCAD::esxsupport:returnIdentity', target, xPlayer)
            end
        else
            debugLog("GetIdentity Failed")
            if cb ~= nil then
                cb({})
            else
                TriggerClientEvent('SonoranCAD::esxsupport:returnIdentity', target, {})
            end
        end
    end

    -- Helper function that just returns the current job as a callback
    function GetCurrentJob(player, cb)
        if cb == nil then
            if JobCache[tostring(player)] ~= nil then
                debugLog("Return cached player")
                return JobCache[tostring(player)]
            else
                debugLog(("Player %s has no cached job"):format(player))
            end
        end
        local xPlayer = ESX.GetPlayerFromId(player)
        local currentJob = xPlayer.job.name
        debugLog("Returned job: "..tostring(xPlayer.job.name))
        if cb == nil then
            JobCache[tostring(player)] = currentJob
            return currentJob
        else
            cb(currentJob)
        end
    end

    -- Caching functionality, used locally to reduce database load
    CreateThread(function()
        while ESX == nil do
            Wait(10)
        end
        local xPlayers = ESX.GetPlayers()
        for i=1, #xPlayers, 1 do
            local player = ESX.GetPlayerFromId(xPlayers[i])
            JobCache[tostring(player)] = player.job.name
        end
        Wait(30000)
    end)

    AddEventHandler("playerDropped", function()
        JobCache[tostring(source)] = nil
    end)

    -- Event for clients to request esx_identity information from the server
    RegisterNetEvent('SonoranCAD::esxsupport:getIdentity')
    AddEventHandler('SonoranCAD::esxsupport:getIdentity', function()
        GetIdentity(source)
    end)

end