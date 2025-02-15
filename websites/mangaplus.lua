-- Import necessary modules
local _ = require("gettext")
local table = require("table")

local WidgetContainer = require("ui/widget/container/widgetcontainer")
local InfoMessage = require("ui/widget/infomessage")
local Menu = require("ui/widget/menu")
local UIManager = require("ui/uimanager")
local InputDialog = require("ui/widget/inputdialog")

local PicViewer = require("lib/picviewer")
local requestManager = require("lib/requestmanager")
local config = require("config")

--- MangaPlus Class
-- Handles interactions with the MangaPlus API to search, display, and read manga.
local MangaPlus = WidgetContainer:extend{
    module_name = "mangaplus",
    domain = "jumpg-webapi.tokyo-cdn.com",
    quality = config.mangaplus.quality,
}

--- Initialize MangaPlus
-- Sets up the initial menu for MangaPlus.
function MangaPlus:init()
    local menu = Menu:new{
        title = _("Manga Plus Menu"),
        no_title = false,
        item_table = {
            {
                text = _("Search"),
                callback = function()
                    self:searchTitle()
                end,
            },
            {
                text = _("Catalogue"),
                callback = function()
                    self:printCatalogue(nil)
                end,
            },
        },
    }
    UIManager:show(menu)
end

--- Display search dialog for manga titles
-- Allows the user to input a search string to find manga titles.
function MangaPlus:searchTitle()
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
                        self:printCatalogue(string.lower(self.search_server_dialog:getInputText()))
                    end,
                },
            }
        },
    }
    UIManager:show(self.search_server_dialog)
    self.search_server_dialog:onShowKeyboard()
end

--- Display the manga catalog
-- Fetches and displays the list of manga titles from the MangaPlus API.
-- @param query Optional search query to filter manga titles.
function MangaPlus:printCatalogue(query)
    local url = string.format("https://%s/api/title_list/allV2?format=json", self.domain)
    local customHeaders = self:getCustomHeaders()
    local responses = requestManager:customRequest(url, "GET", nil, customHeaders)

    if responses then
        local baseJSON = responses.success.allTitlesViewV2.AllTitlesGroup
        self.results = {}

        -- Extract relevant information from the JSON response
        for i = 1, #baseJSON do
            local temp = {}
            if query == nil or string.match(string.lower(baseJSON[i].theTitle), query) ~= nil then
                temp.text = baseJSON[i].theTitle
                temp.lang = baseJSON[i].titles
            end

            if temp.text then
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
                if #item.lang > 1 then
                    UIManager:close(self.menu)
                    self:languageParse(item.lang)
                else
                    UIManager:close(self.menu)
                    self:titleDetail(item.lang[1].titleId)
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
        UIManager:show(InfoMessage:new{ text = _("No manga found!"), timeout = 3 })
    end
end

--- Display available languages for a specific manga title
-- Allows the user to select the language for a manga title.
-- @param lang A table containing language information.
function MangaPlus:languageParse(lang)
    self.results = {}

    -- Extract information about available languages from the JSON response
    for i = 1, #lang do
        local temp = {
            text = lang[i].language or "English",
            slug = lang[i].titleId
        }
        table.insert(self.results, temp)
    end

    -- Create and show the menu with available languages
    self.menu = Menu:new{
        title = _("Language List"),
        no_title = false,
        item_table = self.results,
        onMenuSelect = function(_, item)
            UIManager:close(self.menu)
            self:titleDetail(item.slug)
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

--- Display details of a specific manga title
-- Fetches and displays the list of chapters for a specific manga title.
-- @param slug The slug identifier of the manga title.
function MangaPlus:titleDetail(slug)
    local url = string.format("https://%s/api/title_detailV3?title_id=%s&format=json", self.domain, slug)
    local customHeaders = self:getCustomHeaders()
    local responses = requestManager:customRequest(url, "GET", nil, customHeaders)

    if responses then
        self.results = {}
        local baseJSON = responses.success.titleDetailView.chapterListGroup

        -- Extract information about chapters from the JSON response
        for _, chapterList in pairs(baseJSON) do
            for _, chapter in pairs(chapterList) do
                if chapter.firstChapterList or chapter.lastChapterList then
                    for i = 1, #chapter do
                        local temp = {
                            text = chapter[i].name,
                            number = chapter[i].chapterId
                        }
                        table.insert(self.results, temp)
                    end
                end
            end
        end

        -- Create and show the menu with the chapter list
        self.menu = Menu:new{
            title = _("Chapter List"),
            no_title = false,
            item_table = self.results,
            onMenuSelect = function(_, item)
                UIManager:close(self.menu)
                self:picList(item.number)
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
-- @param chap_id The chapter number.
function MangaPlus:picList(chap_id)
    local url = string.format("https://%s/api/manga_viewer?chapter_id=%s&split=yes&img_quality=%s&format=json", self.domain, chap_id, self.quality)
    local customHeaders = self:getCustomHeaders()
    local responses = requestManager:customRequest(url, "GET", nil, customHeaders)

    if responses then
        self.results = {}
        local baseJSON = responses.success.mangaViewer.pages

        -- Extract picture information from the JSON response
        for i = 1, #baseJSON do
            if baseJSON[i].mangaPage then
                local temp = {
                    path = baseJSON[i].mangaPage.imageUrl,
                    key = baseJSON[i].mangaPage.encryptionKey
                }
                table.insert(self.results, temp)
            end
        end

        -- Use the PicViewer to display the pictures
        PicViewer:displayPic(self.results)
    else
        UIManager:show(InfoMessage:new{ text = _("End of chapter"), timeout = 3 })
    end
end

--- Get custom headers for API requests
-- @return A table containing custom headers for API requests.
function MangaPlus:getCustomHeaders()
    return {
        ["User-Agent"] = "Mozilla/5.0 (X11; Linux x86_64; rv:122.0) Gecko/20100101 Firefox/122.0",
        ["Content-Type"] = "application/json",
    }
end

return MangaPlus
