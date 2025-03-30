local json = require("json")  -- Assuming you have a JSON library like dkjson
local logger = require("logger")
local lfs = require("libs/libkoreader-lfs")

local Settings = {}

-- Path to the configuration file
local config_file_path = require("datastorage"):getDataDir() .. "/plugins/mangareader.koplugin/config.json"

-- Load the configuration from the config.json file
function Settings.loadConfig()
    local config_file = io.open(config_file_path, "r")

    if config_file then
        local config_json = config_file:read("*a")  -- Read the entire content
        local config = json.decode(config_json)  -- Decode the JSON data into a Lua table
        config_file:close()
        return config
    else
        logger.info("Failed to open config file for reading: " .. config_file_path)
        return nil
    end
end

-- Save the configuration to the config.json file
function Settings.saveConfig(config)
    local config_file = io.open(config_file_path, "w")

    if config_file then
        local config_json = json.encode(config)  -- Serialize the config table to JSON
        config_file:write(config_json)
        config_file:close()
    else
        logger.info("Failed to open config file for writing: " .. config_file_path)
    end
end

-- Initialize the configuration (load it or use defaults)
function Settings.initializeConfig()
    -- Load the config from the file, or use default values if the file does not exist
    local config = Settings.loadConfig()
    return config
end

return Settings
