--[[
    Sonaran CAD Plugins

    Plugin Name: esxsupport
    Creator: Sonoran Software Systems LLC
    Description: Enable using ESX (or ESX clones) character information in Sonoran integration plugins
]]

CreateThread(function() Config.LoadPlugin("esxsupport", function(pluginConfig)

if pluginConfig.enabled then

    ESX = nil

    JobCache = {}

    CreateThread(function()
        local waited = 0
        local method = 1
        while waited < 5 do
            if ESX == nil then
                if pluginConfig.usingQbus then
                    if method == 1 then 
                        TriggerEvent(pluginConfig.QbusEventName .. ':GetObject', function(obj) ESX = obj end)
                    else
                        ESX = exports[pluginConfig.QbusResourceName]:GetCoreObject()
                    end
                else
                    TriggerEvent('esx:getSharedObject', function(obj) ESX = obj end)
                end
                Wait(1000)
                debugLog("Waiting for ESX...")
            end
            waited = waited + 1
            if waited == 5 and method == 1 then
                method = 2
                waited = 0
            end
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

    -- EVENT_RECORD_ADDED
    RegisterServerEvent('SonoranCAD::pushevents:RecordAdded')
    AddEventHandler('SonoranCAD::pushevents:RecordAdded', function(record)
        -- Check to see if we should be issuing fines.
        if not pluginConfig.issueFines then return end
        debugLog("Receieved new record")

        local isFineable = false
        for _, formName in pairs(pluginConfig.fineableForms) do
            if record.name:upper() == formName:upper() then isFineable = true end
        end
        if isFineable then
            -- Create empty citation object
            local citation = {
                issuer = nil,   -- Issuer of the fine
                first = nil,    -- First name of the fine target
                last = nil,     -- Last name of the fine target
                fine = 0        -- Total sum of all fineable offenses
            }
            debugLog(record.name:upper() .. " is a fineable record.")
            -- Iterate the sections of the record
            for k, sec in pairs(record.sections) do
                -- Iterate the fields of the record section
                for _, field in pairs(sec.fields) do
                    -- Store the first name of the fine target
                    if field.uid == 'first' then citation.first = field.value end
                    -- Store the last name of the fine target
                    if field.uid == 'last' then citation.last = field.value end
                    -- Retrieve the new Unit Name from the Agency Information
                    if field.type == 'UNIT_NAME' then citation.issuer = field.value end
                    -- Get "Special" fields from the report
                    if field.label == 'New Field Name' then
                        if field.data then
                            -- Get and store the name of the issuing officer to the citation
                            if field.data.officer then citation.issuer = field.data.officer end
                            -- Get and add speeding charges to the citation
                            if field.data.fine then
                                citation.fine = citation.fine + tonumber(field.data.fine)
                                debugLog("Added fine of $" .. field.data.fine .. ' for ' .. field.data.vehicleSpeed .. ' in a ' .. field.data.speedLimit .. 'zone.')
                            end
                            -- Get and add other charges to the citation
                            if field.data.charges then
                                for _, charge in pairs(field.data.charges) do
                                    citation.fine = citation.fine + tonumber(charge.arrestBondAmount)
                                    debugLog('Added fine of $' .. charge.arrestBondAmount .. ' for ' .. charge.arrestCharge)
                                end
                            end
                        end
                    end
                end
            end

            debugLog("New Citation to Issue:")
            debugLog("Issuer: " .. citation.issuer)
            debugLog("Issued To: " .. citation.first .. " " .. citation.last)
            debugLog("Total Fines: $" .. citation.fine)

            -- If the citation is missing a first name or a last name we can't issue the fine.
            if citation.first == '' or citation.last == '' then return end

            -- Find the civilian that matches the citation and issue them a fine.
            local xPlayers = ESX.GetPlayers()
            for i=1, #xPlayers, 1 do
                local xPlayer = ESX.GetPlayerFromId(xPlayers[i])
                if xPlayer.getName() == citation.first .. ' ' .. citation.last then
                    xPlayer.removeAccountMoney('bank', citation.fine)
                    ESX.SavePlayer(xPlayer)
                    -- Send a notification message to the server that the fine has been issued and who issued the fine.
                    if pluginConfig.fineNotify then
                        -- Set the message to be displayed to the users.
                        local finemessage = xPlayer.getName() .. ' has been issued a fine of $' .. citation.fine
                        -- Add issuers name if present
                        if citation.issuer ~= '' then finemessage = finemessage .. ' by ' .. citation.issuer end
                        TriggerClientEvent('chat:addMessage', -1, {
                            color = { 255, 0, 0 },
                            multiline = true,
                            args = { finemessage }
                        })
                    end
                end
            end
        end
    end)
end

end) end)