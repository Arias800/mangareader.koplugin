local WidgetContainer = require("ui/widget/container/widgetcontainer")
local InfoMessage = require("ui/widget/infomessage")
local _ = require("gettext")
local Menu = require("ui/widget/menu")
local UIManager = require("ui/uimanager")
local logger = require("logger")
local table = require("table")
local PicViewer = require("picviewer")
local requestManager = require("requestmanager")

local MangaPlus =
    WidgetContainer:extend {
        module_name = "mangaplus",
        is_doc_only = false,
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
                text = _("Catalogue"),
                callback = function()
                    MangaPlus:printCatalogue()
                end,
            },
        },
    }
    UIManager:show(menu)
end

-- Display the manga catalog
function MangaPlus:printCatalogue()
    local url = string.format("https://%s/api/title_list/all?format=json", self.domain)

    -- Requête personnalisée
    local customHeaders = {
        ["User-Agent"] = "Mozilla/5.0 (X11; Linux x86_64; rv:122.0) Gecko/20100101 Firefox/122.0",
        ["Content-Type"] = "application/json",
    }
    local responses = requestManager:customRequest(url, "GET", nil, customHeaders)

    if responses then
        local baseJSON = responses.success.allTitlesView.titles
        self.results = {}

        -- Extract relevant information from the JSON response
        for i = 1, #baseJSON do
            local temp = {}
            temp.text = baseJSON[i].name
            temp.slug = baseJSON[i].titleId
            table.insert(self.results, temp)
        end

        -- Create and show the menu with catalog content
        self.menu = Menu:new{
            title = "Catalogue content:",
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
        for i = 1, #baseJSON.firstChapterList do
            local temp = {}
            temp.text = baseJSON.firstChapterList[i].name
            temp.number = baseJSON.firstChapterList[i].chapterId
            table.insert(self.results, temp)
        end

        for i = 1, #baseJSON.lastChapterList do
            local temp = {}
            temp.text = baseJSON.lastChapterList[i].name
            temp.number = baseJSON.lastChapterList[i].chapterId
            table.insert(self.results, temp)
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
    logger.info("Chapter NB page " ..#baseJSON)

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