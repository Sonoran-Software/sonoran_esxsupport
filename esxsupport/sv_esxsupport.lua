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

    -- check if prereqs are loaded properly
    assert(MySQL ~= nil, "MySQL is required to use the ESX plugin. Please ensure it's included.")
    

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

    -- Helper function to get the ESX Identity object from your database
    function GetIdentity(target, cb)
        local identifier = GetIdentifiers(target)[pluginConfig.identityType]
        local result = MySQL.Async.fetchAll("SELECT firstname, lastname, sex, dateofbirth, height, job FROM users WHERE identifier = @identifier", {
                ['@identifier'] = ("%s%s"):format(pluginConfig.usePrefix and pluginConfig.identityType..":" or "",identifier)
        })
        if result[1] ~= nil then
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
            if JobCache[player] ~= nil then
                debugLog("Return cached player")
                return JobCache[player]
            else
                debugLog("No job?!")
                return "unemployed"
            end
        end
        local identifier = GetIdentifiers(target)[pluginConfig.identityType]
        local result = MySQL.Async.fetchAll("SELECT job FROM users WHERE identifier = @identifier", {
                ['@identifier'] = ("%s%s"):format(pluginConfig.usePrefix and pluginConfig.identityType..":" or "",identifier)
        })
        local currentJob = nil
        if result[1] ~= nil then
            currentJob = result[1]['job']
        end
        cb(currentJob)
    end

    -- Caching functionality, used locally to reduce database load
    CreateThread(function()
        for i=0, GetNumPlayerIndices()-1 do
            local player = GetPlayerFromIndex(i)
            GetCurrentJob(player, function(job)
                JobCache[player] = job
            end)
        end
        Wait(30000)
    end)

    AddEventHandler("playerDropped", function()
        JobCache[source] = nil
    end)

    -- Event for clients to request esx_identity information from the server
    RegisterNetEvent('SonoranCAD::esxsupport:getIdentity')
    AddEventHandler('SonoranCAD::esxsupport:getIdentity', function()
        GetIdentity(source)
    end)

end