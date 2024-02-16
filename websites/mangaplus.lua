local _ = require("gettext")
local table = require("table")
local logger = require("logger")

local WidgetContainer = require("ui/widget/container/widgetcontainer")
local InfoMessage = require("ui/widget/infomessage")
local Menu = require("ui/widget/menu")
local UIManager = require("ui/uimanager")
local InputDialog = require("ui/widget/inputdialog")

local PicViewer = require("lib/picviewer")
local requestManager = require("lib/requestmanager")

local MangaPlus =
    WidgetContainer:extend {
        module_name = "mangaplus",
        domain = "jumpg-webapi.tokyo-cdn.com",
}

-- Initialization function for MangaPlus
function MangaPlus:init()
    -- Create and show the main menu
    local menu = Menu:new{
        title = "Manga plus menu :",
        no_title = false,
        item_table = {
            {
                text = _("Search"),
                callback = function()
                    MangaPlus:searchTitle()
                end,
            },
            {
                text = _("Catalogue"),
                callback = function()
                    MangaPlus:printCatalogue(nil)
                end,
            },
        },
    }
    UIManager:show(menu)
end

-- Search keyboard
function MangaPlus:searchTitle()
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
                        MangaPlus:printCatalogue(string.lower(self.search_server_dialog:getInputText()))
                    end,
                },
            }
        },
    }
    UIManager:show(self.search_server_dialog)
    self.search_server_dialog:onShowKeyboard()
end

-- Display the manga catalog
function MangaPlus:printCatalogue(query)
    local url = string.format("https://%s/api/title_list/allV2?format=json", self.domain)

    local customHeaders = {
        ["User-Agent"] = "Mozilla/5.0 (X11; Linux x86_64; rv:122.0) Gecko/20100101 Firefox/122.0",
        ["Content-Type"] = "application/json",
    }
    local responses = requestManager:customRequest(url, "GET", nil, customHeaders)

    if responses then
        local baseJSON = responses.success.allTitlesViewV2.AllTitlesGroup
        self.results = {}

        -- Extract relevant information from the JSON response
        for i = 1, #baseJSON do
            local temp = {}

            if query == nil then
                temp.text = baseJSON[i].theTitle
                temp.lang = baseJSON[i].titles
            -- It's a search
            elseif string.find(string.lower(baseJSON[i].theTitle), query) ~= nil then
                temp.text = baseJSON[i].theTitle
                temp.lang = baseJSON[i].titles
            end
            if temp.text then
                table.insert(self.results, temp)
            end
        end

        -- Cna happend if search return any result.
        if self.results == {} then
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
                if #item.lang > 1 then
                    UIManager:close(self.menu)
                    MangaPlus:langaugeParse(item.lang)
                else
                    UIManager:close(self.menu)
                    MangaPlus:titleDetail(item.lang[1].titleId)
                end
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
function MangaPlus:langaugeParse(lang)
    self.results = {}

    -- Extract information about chapters from the JSON response
    for i = 1, #lang do
        local temp = {}
        if lang[i].language then
            temp.text = lang[i].language
        else
            temp.text = "English"
        end
        temp.slug = lang[i].titleId
        table.insert(self.results, temp)
    end

    -- Create and show the menu with the langauge available for this title.
    self.menu = Menu:new{
        title = "Langauge list :",
        no_title = false,
        item_table = self.results,

        onMenuSelect = function(self_menu, item)
            UIManager:close(self.menu)
            MangaPlus:titleDetail(item.slug)
        end,
        close_callback = function()
            UIManager:close(self.menu)
            if self.fm_updated then
                self.ui:onRefresh()
            end
        end,
    }
    UIManager:show(self.menu)
end

-- Display details of a specific manga title
function MangaPlus:titleDetail(slug)
    local url = string.format("https://%s/api/title_detail?title_id=%s&format=json", self.domain, slug)

    -- Requête personnalisée
    local customHeaders = {
        ["User-Agent"] = "Mozilla/5.0 (X11; Linux x86_64; rv:122.0) Gecko/20100101 Firefox/122.0",
        ["Content-Type"] = "application/json",
    }
    local responses = requestManager:customRequest(url, "GET", nil, customHeaders)
    local baseJSON = responses.success.titleDetailView

    if responses then
        self.results = {}

        -- Extract information about chapters from the JSON response
        for k, v in pairs(baseJSON) do
            if k == "firstChapterList" or k == "lastChapterList" then
                for i = 1, #v do
                    local temp = {}
                    temp.text = v[i].name
                    temp.number = v[i].chapterId
                    table.insert(self.results, temp)
                end
            end
        end

        -- Create and show the menu with the chapter list
        self.menu = Menu:new{
            title = "Chapter list :",
            no_title = false,
            item_table = self.results,

            onMenuSelect = function(self_menu, item)
                UIManager:close(self.menu)
                MangaPlus:picList(item.number)
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
function MangaPlus:picList(chap_id)
    local url = string.format("https://%s/api/manga_viewer?chapter_id=%s&split=yes&img_quality=super_high&format=json", self.domain, chap_id)

    -- Requête personnalisée
    local customHeaders = {
        ["User-Agent"] = "Mozilla/5.0 (X11; Linux x86_64; rv:122.0) Gecko/20100101 Firefox/122.0",
        ["Content-Type"] = "application/json",
    }
    local responses = requestManager:customRequest(url, "GET", nil, customHeaders)
    local baseJSON = responses.success.mangaViewer.pages

    if responses then
        self.results = {}

        -- Extract picture information from the JSON response
        for i = 1, #baseJSON do
            local temp = {}
            if baseJSON[i].mangaPage then
                temp.path = baseJSON[i].mangaPage.imageUrl
                temp.key = baseJSON[i].mangaPage.encryptionKey
                table.insert(self.results, temp)
            end
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

return MangaPlus