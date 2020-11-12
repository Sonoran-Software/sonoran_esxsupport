--[[
    Sonoran Plugins

    Plugin Configuration

    Put all needed configuration in this file.

]]
local config = {
    enabled = false,
    configVersion = "1.0",
    pluginName = "esxsupport", -- name your plugin here
    pluginAuthor = "SonoranCAD", -- author
    requiresPlugins = {}, -- required plugins for this plugin to work, separated by commas

    -- Newer ESX versions use license instead of steam for identity, specify the other below if different
    identityType = "license",
    -- Some ESX versions don't use the prefix (such as license:abcdef), set to false to disable the prefix
    usePrefix = false
}
}

if config.enabled then
    Config.RegisterPluginConfig(config.pluginName, config)
end