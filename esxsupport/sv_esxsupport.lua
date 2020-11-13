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
        while waited < 100 do
            if ESX == nil then
                TriggerEvent('esx:getSharedObject', function(obj) ESX = obj end)
                Wait(10)
            end
            waited = waited + 1
        end
        if ESX == nil then
            errorLog("[sonoran_esxsupport] ESX is not configured correctly, but you're attempting to use the ESX support plugin. Please set up ESX or disable this plugin.")
            return
        end
    end)

    -- Helper function to get the ESX Identity object from your database
    function GetIdentity(target, cb)
        local identifier = GetIdentifiers(target)[pluginConfig.identityType]
        local result = MySQL.Sync.fetchAll("SELECT firstname, lastname, sex, dateofbirth, height, job FROM users WHERE identifier = @identifier", {
                ['@identifier'] = ("%s%s"):format(pluginConfig.usePrefix and pluginConfig.identityType..":" or "",identifier)
        })
        if result ~= nil then
            local user = result[1]
            local payload = {
                firstname = user['firstname'],
                lastname = user['lastname'],
                dateofbirth = user['dateofbirth'],
                sex = user['sex'],
                height = user['height'],
                job = user['job']
            }
            debugLog("Got identity data: "..json.encode(payload))
            if cb ~= nil then
                cb(payload)
            else
                TriggerClientEvent('SonoranCAD::esxsupport:returnIdentity', target, payload)
            end
        else
            debugLog("No identity found for: "..("%s%s"):format(pluginConfig.usePrefix and pluginConfig.identityType..":" or "",identifier))
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
        local identifier = GetIdentifiers(player)[pluginConfig.identityType]
        local result = MySQL.Sync.fetchAll("SELECT job FROM es_extended.users WHERE identifier = @identifier", {
                ['@identifier'] = ("%s%s"):format(pluginConfig.usePrefix and pluginConfig.identityType..":" or "",identifier)
        })
        local currentJob = nil
        if result ~= nil then
            currentJob = result[1]['job']
        else
            warnLog("Unable to find job: "..("%s%s"):format(pluginConfig.usePrefix and pluginConfig.identityType..":" or "",identifier))
        end
        if cb == nil then
            JobCache[tostring(player)] = currentJob
            return currentJob
        else
            cb(currentJob)
        end
    end

    -- Caching functionality, used locally to reduce database load
    CreateThread(function()
        for i=0, GetNumPlayerIndices()-1 do
            local player = GetPlayerFromIndex(i)
            GetCurrentJob(player, function(job)
                debugLog(("Set player %s to job %s"):format(player, job))
                JobCache[tostring(player)] = job
            end)
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