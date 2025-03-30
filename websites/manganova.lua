-- Import necessary modules
local _ = require("gettext")
local table = require("table")

local UIManager = require("ui/uimanager")
local Menu = require("ui/widget/menu")
local WidgetContainer = require("ui/widget/container/widgetcontainer")
local InfoMessage = require("ui/widget/infomessage")
local InputDialog = require("ui/widget/inputdialog")

local PicViewer = require("lib/picviewer")
local requestManager = require("lib/requestmanager")
local Settings = require("lib/settings")

-- Load the settings (or use the existing loaded config)
local MainConfig = Settings.initializeConfig()  -- You can skip this if MainConfig is already globally accessible

--- MangaNova Class
-- Handles interactions with the MangaNova API to search, display, and read manga.
local MangaNova = WidgetContainer:extend{
    module_name = "manganova",
    results = {},
    domain = "api.manga-nova.com",
    token = MainConfig.manganova.token,
}

--- Initialize MangaNova
-- Sets up the initial menu for MangaNova.
function MangaNova:init()
    local menu = Menu:new{
        title = _("Manga Nova Menu"),
        no_title = false,
        item_table = {
            {
                text = _("Search"),
                callback = function()
                    MangaNova:searchTitle()
                end,
            },
            {
                text = _("Catalogue"),
                callback = function()
                    MangaNova:printCatalogue()
                end,
            },
        },
    }
    UIManager:show(menu)
end

--- Display search dialog for manga titles
-- Allows the user to input a search string to find manga titles.
function MangaNova:searchTitle()
    self.search_server_dialog = InputDialog:new{
        title = _("Search Manga"),
        input = "",
        hint = _("Search string"),
        input_hint = _("One Piece"),
        input_type = "string",
        description = _("Title of the manga:"),
        buttons = {
            {
                {
                    text = _("Cancel"),
                    callback = function()
                        UIManager:close(self.search_server_dialog)
                    end,
                },
                {
                    text = _("Search"),
                    is_enter_default = true,
                    callback = function()
                        UIManager:close(self.search_server_dialog)
                        MangaNova:printCatalogue(string.lower(self.search_server_dialog:getInputText()))
                    end,
                },
            }
        },
    }
    UIManager:show(self.search_server_dialog)
    self.search_server_dialog:onShowKeyboard()
end

--- Display the manga catalog
-- Fetches and displays the list of manga titles from the MangaNova API.
-- @param query Optional search query to filter manga titles.
function MangaNova:printCatalogue(query)
    local url = string.format("https://%s/catalogue/", self.domain)
    local custom_headers = MangaNova:getCustomHeaders()
    local responses = requestManager:customRequest(url, "GET", nil, custom_headers)

    if responses then
        self.results = {}

        -- Extract relevant information from the JSON response
        for i = 1, #responses.series do
            local temp = {}
            if query == nil or string.match(string.lower(responses.series[i].title), query) ~= nil then
                temp.text = responses.series[i].title
                temp.slug = responses.series[i].slug
                table.insert(self.results, temp)
            end
        end

        -- Display an info message if no manga is found
        if next(self.results) == nil then
            UIManager:show(InfoMessage:new{ text = _("No manga found!"), timeout = 3 })
            return
        end

        -- Create and show the menu with catalog content
        self.menu = Menu:new{
            title = _("Catalogue Content"),
            no_title = false,
            item_table = self.results,
            onMenuSelect = function(_, item)
                UIManager:close(self.menu)
                MangaNova:titleDetail(item.slug)
            end,
            close_callback = function()
                UIManager:close(self.menu)
                if self.fm_updated then
                    self.ui:onRefresh()
                end
            end,
        }
        UIManager:show(self.menu)
    else
        UIManager:show(InfoMessage:new{ text = _("No manga found!"), timeout = 3 })
    end
end

--- Display details of a specific manga title
-- Fetches and displays the list of chapters for a specific manga title.
-- @param slug The slug identifier of the manga title.
function MangaNova:titleDetail(slug)
    local url = string.format("https://%s/mangas/%s", self.domain, slug)
    local custom_headers = MangaNova:getCustomHeaders()
    local responses = requestManager:customRequest(url, "GET", nil, custom_headers)

    if responses then
        self.results = {}

        -- Extract information about chapters from the JSON response
        for i = 1, #responses.serie.chapitres do
            for j = 1, #responses.serie.chapitres[i].chapitres do
                local temp = {
                    text = responses.serie.chapitres[i].chapitres[j].title,
                    number = responses.serie.chapitres[i].chapitres[j].number,
                    slug = slug
                }
                table.insert(self.results, temp)
            end
        end

        -- Create and show the menu with the chapter list
        self.menu = Menu:new{
            title = _("Chapter List"),
            no_title = false,
            item_table = self.results,
            onMenuSelect = function(_, item)
                UIManager:close(self.menu)
                MangaNova:picList(item.slug, item.number)
            end,
            close_callback = function()
                UIManager:close(self.menu)
                if self.fm_updated then
                    self.ui:onRefresh()
                end
            end,
        }
        UIManager:show(self.menu)
    else
        UIManager:show(InfoMessage:new{ text = _("No chapter found!"), timeout = 3 })
    end
end

--- Display the list of pictures for a specific chapter
-- Fetches and displays the list of pictures for a specific chapter using PicViewer.
-- @param slug The slug identifier of the manga title.
-- @param chap_id The chapter number.
function MangaNova:picList(slug, chap_id)
    local url = string.format("https://%s/mangas/%s/chapitres/%s", self.domain, slug, chap_id)
    local custom_headers = MangaNova:getCustomHeaders()
    local responses = requestManager:customRequest(url, "GET", nil, custom_headers)

    if responses then
        self.results = {}

        -- Extract picture information from the JSON response
        for i = 1, #responses.images do
            local temp = {
                path = responses.images[i].image,
                key = nil
            }
            table.insert(self.results, temp)
        end

        -- Use the PicViewer to display the pictures
        PicViewer:displayPic(self.results)
    else
        UIManager:show(InfoMessage:new{ text = _("No pictures found!"), timeout = 3 })
    end
end

--- Get custom headers for API requests
-- @return A table containing custom headers for API requests.
function MangaNova:getCustomHeaders()
    return {
        ["User-Agent"] = "Mozilla/5.0 (X11; Linux x86_64; rv:122.0) Gecko/20100101 Firefox/122.0",
        ["Authorization"] = "Bearer " .. self.token,
        ["Origin"] = "https://www.manga-nova.com",
        ["Referer"] = "https://www.manga-nova.com/",
        ["Content-Type"] = "application/json",
    }
end

return MangaNova
