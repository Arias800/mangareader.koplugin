local _ = require("gettext")
local logger = require("logger")
local table = require("table")
local MultiInputDialog = require("ui/widget/multiinputdialog")
local InfoMessage = require("ui/widget/infomessage")
local lfs = require("libs/libkoreader-lfs")
local UIManager = require("ui/uimanager")
local WidgetContainer = require("ui/widget/container/widgetcontainer")
local Menu = require("ui/widget/menu")
local Settings = require("lib/settings")

-- Initialize the config when the app starts
local MainConfig = Settings.initializeConfig()

--- MangaReader Class
-- Handles the manga reader interface and settings.
local MangaReader = WidgetContainer:extend{
    name = "MangaReader",
}

--- Initialize MangaReader
-- Registers the MangaReader to the main menu.
function MangaReader:init()
    self.ui.menu:registerToMainMenu(self)
end

--- Add MangaReader to the main menu
-- @param menu_items Table containing menu items
function MangaReader:addToMainMenu(menu_items)
    menu_items.MangaReader = {
        text = _("Manga Reader"),
        sub_item_table = {
            {
                text_func = function()
                    return _("Load module")
                end,
                callback = function()
                    self:loadModule()
                end
            },
            {
                text_func = function()
                    return _("Settings")
                end,
                callback = function()
                    self:loadSettings()
                end
            },
        },
    }
end

--- Load available manga reader modules
-- Scans the data directory for available manga reader modules and displays them in a menu.
function MangaReader:loadModule()
    local data_dir = require("datastorage"):getDataDir() .. "/plugins/mangareader.koplugin/websites/"
    self.results = {}

    for lookup_path in lfs.dir(data_dir) do
        if string.find(lookup_path, ".lua") then
            local module_info = {
                text = lookup_path:gsub("%.lua", ""),
                path = data_dir .. lookup_path
            }
            table.insert(self.results, module_info)
        end
    end

    self.menu = Menu:new{
        title = _("Modules available:"),
        no_title = false,
        item_table = self.results,
        onMenuSelect = function(_, item)
            UIManager:close(self.menu)
            local ok, plugin_module = pcall(dofile, item.path)
            if not ok or not plugin_module then
                logger.info("Error when loading", item.path, plugin_module)
                return
            end
            plugin_module.init()
        end,
        close_callback = function()
            UIManager:close(self.menu)
        end,
    }
    UIManager:show(self.menu)
end

--- Load manga reader settings
-- Displays settings dialogs for MangaNova and MangaPlus.
function MangaReader:loadSettings()
    local nova_info = _([[
MangaNova is a manga reading service.
"MangaNova API Token" is a developer setting.
Don't change anything unless you know what you're doing.
    ]])

    local plus_info = _([[
MangaPlus is an official manga reading service.
You can select different quality settings for manga images.
Higher quality requires more bandwidth and storage space.
    ]])

    --- Show MangaNova settings dialog
    local function showNovaSettings()
        self.settings_dialog = MultiInputDialog:new{
            title = _("MangaNova Settings"),
            fields = {
                {
                    text = MainConfig.manganova.token or "",
                    hint = _("MangaNova API Token"),
                },
            },
            buttons = {
                {
                    {
                        text = _("Cancel"),
                        id = "close",
                        callback = function()
                            self.settings_dialog:onClose()
                            UIManager:close(self.settings_dialog)
                        end
                    },
                    {
                        text = _("Info"),
                        callback = function()
                            UIManager:show(InfoMessage:new{ text = nova_info })
                        end
                    },
                    {
                        text = _("Save"),
                        callback = function()
                            local fields = self.settings_dialog:getFields()
                            MainConfig.manganova.token = fields[1]
                            Settings.saveConfig(MainConfig)
                            self.settings_dialog:onClose()
                            UIManager:close(self.settings_dialog)
                            UIManager:show(InfoMessage:new{
                                text = _("Settings saved"),
                            })
                        end
                    },
                },
            },
        }
        UIManager:show(self.settings_dialog)
        self.settings_dialog:onShowKeyboard()
    end

    --- Show MangaPlus settings dialog
    local function showPlusSettings()
        self.plus_dialog = MultiInputDialog:new{
            title = _("MangaPlus Settings"),
            fields = {
                {
                    text = MainConfig.mangaplus.quality or "medium",
                    hint = _("Choose quality: low, medium, high, super_high"),
                },
            },
            buttons = {
                {
                    {
                        text = _("Cancel"),
                        id = "close",
                        callback = function()
                            self.plus_dialog:onClose()
                            UIManager:close(self.plus_dialog)
                        end
                    },
                    {
                        text = _("Info"),
                        callback = function()
                            UIManager:show(InfoMessage:new{ text = plus_info })
                        end
                    },
                    {
                        text = _("Save"),
                        callback = function()
                            local fields = self.plus_dialog:getFields()
                            local quality = fields[1]
                            local valid_qualities = { low = true, medium = true, high = true, super_high = true }
                            if valid_qualities[quality] then
                                MainConfig.mangaplus.quality = quality
                                Settings.saveConfig(MainConfig)
                                self.plus_dialog:onClose()
                                UIManager:close(self.plus_dialog)
                                UIManager:show(InfoMessage:new{
                                    text = _("Quality set to " .. quality),
                                })
                            else
                                UIManager:show(InfoMessage:new{
                                    text = _("Invalid quality setting. Please choose: low, medium, high, or super_high"),
                                })
                            end
                        end
                    },
                },
            },
        }
        UIManager:show(self.plus_dialog)
        self.plus_dialog:onShowKeyboard()
    end

    --- Show Force Single-Page Display setting dialog
    local function showSinglePageSetting()
        self.single_page_dialog = MultiInputDialog:new{
            title = _("Manga Reader Settings"),
            fields = {
                {
                    text = MainConfig.manga_reader.single_page and _("Enable") or _("Disable"),
                    hint = _("Toggle the display mode"),
                },
            },
            buttons = {
                {
                    {
                        text = _("Cancel"),
                        id = "close",
                        callback = function()
                            self.single_page_dialog:onClose()
                            UIManager:close(self.single_page_dialog)
                        end
                    },
                    {
                        text = _("Save"),
                        callback = function()
                            MainConfig.manga_reader.single_page = not MainConfig.manga_reader.single_page
                            Settings.saveConfig(MainConfig)
                            self.single_page_dialog:onClose()
                            UIManager:close(self.single_page_dialog)
                            UIManager:show(InfoMessage:new{
                                text = _("Single page mode is " .. (MainConfig.manga_reader.single_page and "enabled" or "disabled") ..
                                "\nReload Koreader for change to take effect."),
                            })
                        end
                    },
                },
            },
        }
        UIManager:show(self.single_page_dialog)
        self.single_page_dialog:onShowKeyboard()
    end

    local settings_items = {
        { text = _("MangaNova Settings"), callback = showNovaSettings },
        { text = _("MangaPlus Settings"), callback = showPlusSettings },
        { text = _("Force Single-Page Display"), callback = showSinglePageSetting },
    }

    self.settings_menu = Menu:new{
        title = _("Manga Reader Settings"),
        item_table = settings_items,
        close_callback = function()
            UIManager:close(self.settings_menu)
        end,
    }
    UIManager:show(self.settings_menu)
end

return MangaReader
