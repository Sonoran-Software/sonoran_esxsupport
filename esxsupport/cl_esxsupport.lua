--[[
    Sonaran CAD Plugins

    Plugin Name: esxsupport
    Creator: Sonoran Software Systems LLC
    Description: Enable using ESX (or ESX clones) character information in Sonoran integration plugins
]]

local pluginConfig = Config.GetPluginConfig("esxsupport")

if pluginConfig.enabled then

    Citizen.CreateThread(function()
        ---------------------------------------------------------------------------
        -- ESX Integration Initialization/Events/Functions
        ---------------------------------------------------------------------------
        -- Initialize ESX Framework hooks to allow obtaining data
        PlayerData = {}
        ESX = nil

        Citizen.CreateThread(function()
            while ESX == nil do
                if pluginConfig.usingQbus then
                    TriggerEvent(pluginConfig.QbusEventName .. ':GetObject', function(obj) ESX = obj end)
                else
                    TriggerEvent('esx:getSharedObject', function(obj) ESX = obj end)
                end
                Citizen.Wait(10)
            end

            if pluginConfig.usingQbus then
                while ESX.Functions.GetPlayerData() == nil do
                    Citizen.Wait(10)
                end
                PlayerData = ESX.Functions.GetPlayerData()
            else
                while ESX.GetPlayerData() == nil do
                    Citizen.Wait(10)
                end
                PlayerData = ESX.GetPlayerData()
            end
        end)

        -- Listen for when new players load into the game
        RegisterNetEvent('esx:playerLoaded')
        AddEventHandler('esx:playerLoaded', function(xPlayer)
            if pluginConfig.usingQbus then
                PlayerData = ESX.Functions.GetPlayerData()
            else
                PlayerData = xPlayer
            end
        end)
        -- Listen for when jobs are changed in esx_jobs
        if pluginConfig.usingQbus then
            RegisterNetEvent(pluginConfig.QbusEventName .. ':Client:OnJobUpdate')
            AddEventHandler(pluginConfig.QbusEventName .. ':Client:OnJobUpdate', function(job)
                PlayerData.job = job
                if PlayerData.job.onduty == true then -- QBUS job.onduty is false when on duty??? okayyyyy
                    PlayerData.job.name = 'offduty' .. PlayerData.job.name
                end
                TriggerServerEvent('SonoranCAD::esxsupport:refreshJobCache')
                TriggerEvent('SonoranCAD::esxsupport:JobUpdate', job)
            end)
        else
            RegisterNetEvent('esx:setJob')
            AddEventHandler('esx:setJob', function(job)
                PlayerData.job = job
                TriggerServerEvent('SonoranCAD::esxsupport:refreshJobCache')
                TriggerEvent('SonoranCAD::esxsupport:JobUpdate', job)
            end)
        end
        -- QBUS onduty change (ESX typically uses jobs to change duty instead)
        if pluginConfig.usingQbus then
            RegisterNetEvent(pluginConfig.QbusEventName .. ':Client:SetDuty')
            AddEventHandler(pluginConfig.QbusEventName .. ':Client:SetDuty', function(onduty)
                local job = PlayerData.job
                if onduty then
                    job.name = string.gsub(job.name,'offduty','')
                else
                    job.name = 'offduty' .. job.name
                end
                PlayerData.job = job
                TriggerServerEvent('SonoranCAD::esxsupport:refreshJobCache')
                TriggerEvent('SonoranCAD::esxsupport:JobUpdate', job)
            end)
        end

        -- Function to return esx_identity data on the client from server
        -- This event listens for data from the server when requested
        local recievedIdentity = false
        returnedIdentity = nil
        RegisterNetEvent('SonoranCAD::esxsupport:returnIdentity')
        AddEventHandler('SonoranCAD::esxsupport:returnIdentity', function(data)
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

        -- Listen for fines being issued to player.
        RegisterNetEvent('SonoranCAD::esxsupport:issueFine')
        AddEventHandler('SonoranCAD::esxsupport:issueFine', function(xPlayer, amount)
            debugLog('Attempted to bill ' .. GetPlayerServerId(PlayerId()) .. ' $' .. amount )
            TriggerServerEvent('esx_billing:sendBill', GetPlayerServerId(PlayerId()), 'society_police', 'CustomFine', amount)
        end)
        
    end)
    

end