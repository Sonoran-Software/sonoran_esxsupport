--[[
    Sonaran CAD Plugins

    Plugin Name: esxsupport
    Creator: Sonoran Software Systems LLC
    Description: Enable using ESX (or ESX clones) character information in Sonoran integration plugins
]]

local pluginConfig = Config.GetPluginConfig("esxsupport")

if pluginConfig.enabled then

    ESX = nil

    JobCache = {}

    CreateThread(function()
        local waited = 0
        while waited < 5 do
            if ESX == nil then
                if pluginConfig.usingQbus then
                    TriggerEvent(pluginConfig.QbusEventName .. ':GetObject', function(obj) ESX = obj end)
                else
                    TriggerEvent('esx:getSharedObject', function(obj) ESX = obj end)
                end
                Wait(1000)
                debugLog("Waiting for ESX...")
            end
            waited = waited + 1
        end
        if ESX == nil then
            errorLog("[sonoran_esxsupport] ESX is not configured correctly, but you're attempting to use the ESX support plugin. Please set up ESX or disable this plugin. Check the esxsupport plugin config for errors if you believe you have set up ESX correctly.")
            return
        else
            infoLog("ESX support loaded successfully.")
        end
    end)

    -- Helper function to get the ESX Identity object from your database
    function GetIdentity(target, cb)
        local xPlayer = nil
        if pluginConfig.usingQbus then
            xPlayer = ESX.Functions.GetPlayer(target) -- Yes I know it says ESX... QBUS is ESX in disguise kappa
        else
            xPlayer = ESX.GetPlayerFromId(target)
        end
        if xPlayer ~= nil then
            debugLog("GetIdentity OK")
            if pluginConfig.usingQbus then
                xPlayer.firstName = xPlayer.PlayerData.charinfo.firstname
                xPlayer.lastName = xPlayer.PlayerData.charinfo.lastname
                xPlayer.name = xPlayer.firstName .. ' ' .. xPlayer.lastName
            end
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
        local currentJob = ""
        if cb == nil then
            if JobCache[tostring(player)] ~= nil then
                debugLog("Return cached player")
                return JobCache[tostring(player)]
            else
                debugLog(("Player %s has no cached job"):format(player))
            end
        end
        local xPlayer = nil
        if pluginConfig.usingQbus then
            xPlayer = ESX.Functions.GetPlayer(tonumber(player))
        else
            xPlayer = ESX.GetPlayerFromId(player)
        end
        if xPlayer == nil then
            warnLog(("Failed to obtain player info from %s. ESX.GetPlayerFromId returned nil."):format(player))
        else
            if pluginConfig.usingQbus then
                if not xPlayer.PlayerData.job.onduty then -- QBUS job.onduty is false when on duty??? okayyyyy
                    currentJob = xPlayer.PlayerData.job.name
                else
                    currentJob = 'offduty' .. xPlayer.PlayerData.job.name
                end
            else
                currentJob = xPlayer.job.name
            end
            debugLog("Returned job: "..tostring(currentJob))
        end
        if cb == nil then
            JobCache[tostring(player)] = currentJob
            return currentJob
        elseif cb == true then
            JobCache[tostring(player)] = currentJob
            debugLog('refreshed job cache for player '..player..'-'..currentJob)
        else
            cb(currentJob)
        end
    end

    -- Caching functionality, used locally to reduce database load
    CreateThread(function()
        while ESX == nil do
            Wait(10)
        end
        local xPlayers = nil
        if pluginConfig.usingQbus then
            xPlayers = ESX.Functions.GetPlayers()
        else
            xPlayers = ESX.GetPlayers()
        end
        for i=1, #xPlayers, 1 do
            local player = nil
            if pluginConfig.usingQbus then
                player = ESX.Functions.GetPlayer(tonumber(xPlayers[i]))
            else
                player = ESX.GetPlayerFromId(xPlayers[i])
            end
            if player == nil then
                debugLog("Failed to obtain job from player "..tostring(xPlayers[i]))
            else
                if pluginConfig.usingQbus then
                    if not player.PlayerData.job.onduty then
                        JobCache[tostring(player)] = player.PlayerData.job.name
                    else
                        JobCache[tostring(player)] = 'offduty' .. player.PlayerData.job.name
                    end
                else
                    JobCache[tostring(player)] = player.job.name
                end
            end
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

    -- Event for clients to trigger job refresh on server (primarily for QBUS onduty handling)
    RegisterNetEvent('SonoranCAD::esxsupport:refreshJobCache')
    AddEventHandler('SonoranCAD::esxsupport:refreshJobCache', function()
        local src = source
        GetCurrentJob(src,true)
    end)

end