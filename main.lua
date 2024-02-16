local WidgetContainer = require("ui/widget/container/widgetcontainer")
local _ = require("gettext")
local UIManager = require("ui/uimanager")
local logger = require("logger")
local table = require("table")
local lfs = require("libs/libkoreader-lfs")
local Menu = require("ui/widget/menu")

local MangaReader =
    WidgetContainer:extend {
        name = "MangaReader",
}

-- Initialization function for MangaReader
function MangaReader:init()
    -- Register the MangaReader to the main menu
    self.ui.menu:registerToMainMenu(self)
end

-- Add MangaReader options to the main menu
function MangaReader:addToMainMenu(menu_items)
    menu_items.MangaReader = {
        text = _("Manga Reader"),
        sub_item_table = {
            {
                text_func = function()
                    return _("Load module")
                end,
                callback = function()
                    MangaReader:loadModule()
                end
            }
        },
    }
end

-- Function to load the manga reading module
function MangaReader:loadModule()
    -- Get the data directory for the plugin
    local data_dir = require("datastorage"):getDataDir()  .. "/plugins/mangareader.koplugin/websites/"
    self.results = {}

    -- Iterate over files in the data directory
    for lookup_path in lfs.dir(data_dir) do
        local modules = {}
        if string.find(lookup_path, ".lua") then
            modules.text = lookup_path:gsub("%.lua", "")
            modules.path = data_dir..lookup_path
            table.insert(self.results, modules)
        end
    end

    -- Create a menu with available modules
    self.menu = Menu:new{
        title = "Module available :",
        no_title = false,
        item_table = self.results,

        -- Handle module selection
        onMenuSelect = function(self_menu, item)
            UIManager:close(self.menu)
            local ok, plugin_module = pcall(dofile, item.path)
            if not ok or not plugin_module then
                logger.info("Error when loading", item.path, plugin_module)
            end
            plugin_module.init()
        end,
        close_callback = function()
            UIManager:close(self.menu)
        end,
    }
    UIManager:show(self.menu)
end

return MangaReader
