local _ = require("gettext")
local table = require("table")

local UIManager = require("ui/uimanager")
local Menu = require("ui/widget/menu")
local WidgetContainer = require("ui/widget/container/widgetcontainer")
local InfoMessage = require("ui/widget/infomessage")
local InputDialog = require("ui/widget/inputdialog")

local PicViewer = require("lib/picviewer")
local requestManager = require("lib/requestmanager")
local config = require ("config")

local MangaNova =
    WidgetContainer:extend {
        module_name = "manganova",
        results = {},
        domain = "api.manga-nova.com",
        token = config.manganova.token,
}

function MangaNova:init()
    local menu = Menu:new{
        title = "Manga Nova menu :",
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
                    MangaNova:printCatalogue(nil)
                end,
            },
        },
    }
    UIManager:show(menu)
end

-- Search keyboard
function MangaNova:searchTitle()
 self.search_server_dialog = InputDialog:new{
        title = _("Search manga"),
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

-- Display the manga catalog
function MangaNova:printCatalogue(query)
    local url = string.format("https://%s/catalogue/", self.domain)

    -- Requête personnalisée
    local custom_headers = {
        ["User-Agent"] = "Mozilla/5.0 (X11; Linux x86_64; rv:122.0) Gecko/20100101 Firefox/122.0",
        ["Authorization"] = "Bearer " .. self.token,
        ["Origin"] = "https://www.manga-nova.com",
        ["Referer"] = "https://www.manga-nova.com/",
        ["Content-Type"] = "application/json",
    }
    local responses = requestManager:customRequest(url, "GET", nil, custom_headers)

    if responses then
        self.results = {}

        -- Extract relevant information from the JSON response
        for i = 1, #responses.series do
            local temp = {}

            if query == nil or string.match(string.lower(responses.series[i].title), query) ~= nil then
                temp.text = responses.series[i].title
                temp.slug = responses.series[i].slug
            end

            if temp.text then
                table.insert(self.results, temp)
        end
    end

    -- Can happend if search return any result.
    if next(self.results) == nil then
        -- Display an info message if no manga is found
        UIManager:show(
            InfoMessage:new {
                text = _("No manga found!"),
                timeout = 3
            }
        )
        return
    end

        -- Create and show the menu with catalog content
        self.menu = Menu:new{
            title = "Catalogue content:",
            no_title = false,
            item_table = self.results,

            onMenuSelect = function(self_menu, item)
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
        -- Display an info message if no manga is found
        UIManager:show(
            InfoMessage:new {
                text = _("No manga found!"),
                timeout = 3
            }
        )
    end
    return
end

-- Display details of a specific manga title
function MangaNova:titleDetail(slug)
    local url = string.format("https://%s/mangas/%s", self.domain, slug)

    -- Custom request
    local custom_headers = {
        ["User-Agent"] = "Mozilla/5.0 (X11; Linux x86_64; rv:122.0) Gecko/20100101 Firefox/122.0",
        ["Authorization"] = "Bearer " .. self.token,
        ["Origin"] = "https://www.manga-nova.com",
        ["Referer"] = "https://www.manga-nova.com/",
        ["Content-Type"] = "application/json",
    }
    local responses = requestManager:customRequest(url, "GET", nil, custom_headers)
    if responses then
        self.results = {}

        -- Extract information about chapters from the JSON response
        for i = 1, #responses.serie.chapitres do
            for j = 1, #responses.serie.chapitres[i].chapitres do
                local temp = {}
                temp.text = responses.serie.chapitres[i].chapitres[j].title
                temp.number = responses.serie.chapitres[i].chapitres[j].number
                temp.slug = slug
                table.insert(self.results, temp)
            end
        end

        -- Create and show the menu with the chapter list
        self.menu = Menu:new{
            title = "Chapter list :",
            no_title = false,
            item_table = self.results,

            onMenuSelect = function(self_menu, item)
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
        -- Display an info message if no chapters are found
        UIManager:show(
            InfoMessage:new {
                text = _("No chapter found!"),
                timeout = 3
            }
        )
    end
end

-- Display the list of pictures for a specific chapter
function MangaNova:picList(slug, chap_id)
    local url = string.format("https://%s/mangas/%s/chapitres/%s", self.domain, slug, chap_id)

    -- Custom request
    local custom_headers = {
        ["User-Agent"] = "Mozilla/5.0 (X11; Linux x86_64; rv:122.0) Gecko/20100101 Firefox/122.0",
        ["Authorization"] = "Bearer " .. self.token,
        ["Origin"] = "https://www.manga-nova.com",
        ["Referer"] = "https://www.manga-nova.com/",
        ["Content-Type"] = "application/json",
    }
    local responses = requestManager:customRequest(url, "GET", nil, custom_headers)

    if responses then
        self.results = {}

        -- Extract picture information from the JSON response
        for i = 1, #responses.images do
            local temp = {}
            temp.path = responses.images[i].image
            temp.key = nil
            table.insert(self.results, temp)
        end

        -- Use the PicViewer to display the pictures
        PicViewer:displayPic(self.results)
    else
        -- Display an info message if no pictures are found
        UIManager:show(
            InfoMessage:new {
                text = _("No chapter found!"),
                timeout = 3
            }
        )
    end
end

return MangaNova
