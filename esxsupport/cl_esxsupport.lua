--[[
    Sonaran CAD Plugins

    Plugin Name: template
    Creator: template
    Description: Describe your plugin here

    Put all client-side logic in this file.
]]

local pluginConfig = Config.GetPluginConfig("esxsupport")

if pluginConfig.enabled then

    Citizen.CreateThread(function()
        while Config.serverType == nil do
            Wait(10)
        end
        ---------------------------------------------------------------------------
        -- ESX Integration Initialization/Events/Functions
        ---------------------------------------------------------------------------
        -- Initialize ESX Framework hooks to allow obtaining data
        PlayerData = {}
        ESX = nil

        Citizen.CreateThread(function()
            while ESX == nil do
                TriggerEvent('esx:getSharedObject', function(obj) ESX = obj end)
                Citizen.Wait(10)
            end

            while ESX.GetPlayerData() == nil do
                Citizen.Wait(10)
            end

            PlayerData = ESX.GetPlayerData()
        end)

            -- Listen for when new players load into the game
        RegisterNetEvent('esx:playerLoaded')
        AddEventHandler('esx:playerLoaded', function(xPlayer)
            PlayerData = xPlayer
        end)
        -- Listen for when jobs are changed in esx_jobs
        RegisterNetEvent('esx:setJob')
        AddEventHandler('esx:setJob', function(job)
            PlayerData.job = job
            TriggerEvent('SonoranCAD::esxsupport:JobUpdate', job)
        end)

        -- Function to return esx_identity data on the client from server
        -- This event listens for data from the server when requested
        local recievedIdentity = false
        returnedIdentity = nil
        RegisterNetEvent('SonoranCAD::esxsupport:returnIdentity')
        AddEventHandler('sonorancad:returnIdentity', function(data)
            recievedIdentity = true
            if data.job == nil then
                warnLog("Warning: no identity data was found.")
            else
                returnedIdentity = data
            end
        end)
        -- This function requests data from the server
        function GetIdentity(callback)
            recievedIdentity = false
            returnIdentity = false
            TriggerServerEvent("SonoranCAD::esxsupport:getIdentity")
            local timeStamp = GetGameTimer()
            while not recievedIdentity do
                Citizen.Wait(0)
            end
            callback(returnedIdentity)
        end
    end)
    

end