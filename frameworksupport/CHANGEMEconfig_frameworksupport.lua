--[[
    Sonoran Plugins

    ESXSupport Plugin Configuration

    Put all needed configuration in this file.

]]
local config = {
    enabled = false,
    configVersion = "4.0",
    pluginName = "esxsupport", -- name your plugin here
    pluginAuthor = "SonoranCAD", -- author
    requiresPlugins = {}, -- required plugins for this plugin to work, separated by commas

    -- Newer ESX versions use license instead of steam for identity, specify the other below if different
    identityType = "license",
    -- Some ESX versions don't use the prefix (such as license:abcdef), set to false to disable the prefix
    usePrefix = false,
    -- Use QBUS (a renamed ESX with some changes)? Set this to "true"
    usingQbus = false,
    -- Have a renamed QBUS Framework? (like RepentzFW) change the "QBCore" name here to whatever the event name uses
    QbusEventName = "QBCore",
    -- If using qbus, enter the name of the core resource (such as qb-core)
    QbusResourceName = "qb-core",

    -- Fine payment system
    issueFines = false,                 -- Use the fine system
    fineNotify = false,                 -- Send a message in chat when someone is fined.
    fineableForms = {"Arrest Report"},  -- List of form names that should issue fines (Don't Include Warrants or Bolos)

    -- ESX Legacy Support (Created for and tested using ESX v1.1.0 esx_identity v1.0.2)
    legacyESX = false                   -- Set to true if default settings do not get character name properly (older esx_identity/ESX legacy versions)
}

if config.enabled then
    Config.RegisterPluginConfig(config.pluginName, config)
end
