local WidgetContainer = require("ui/widget/container/widgetcontainer")
local InfoMessage = require("ui/widget/infomessage")
local _ = require("gettext")
local Menu = require("ui/widget/menu")
local UIManager = require("ui/uimanager")
local logger = require("logger")
local table = require("table")
local PicViewer = require("picviewer")
local requestManager = require("requestmanager")

local MangaNova =
    WidgetContainer:extend {
        module_name = "manganova",
        results = {},
        domain = "api.manga-nova.com",
}

-- Offline generic token
local token = "eyJ0eXAiOiJKV1QiLCJhbGciOiJIUzI1NiJ9.eyJtZW1icmVfaWQiOjAsIm1lbWJyZV91c2VybmFtZSI6bnVsbCwiaWF0IjoxNzA1NTc5MDQ1fQ.51qivLd2l3OKbDaYYzlntZJNnreRSBWO7p5Nsa2mAsA"

function MangaNova:init()
    local menu = Menu:new{
        title = "Manga Nova menu :",
        no_title = false,
        item_table = {
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

-- Display the manga catalog
function MangaNova:printCatalogue()
    local url = string.format("https://%s/catalogue/", self.domain)

    -- Requête personnalisée
    local customHeaders = {
        ["User-Agent"] = "Mozilla/5.0 (X11; Linux x86_64; rv:122.0) Gecko/20100101 Firefox/122.0",
        ["Authorization"] = "Bearer " .. token,
        ["Origin"] = "https://www.manga-nova.com",
        ["Referer"] = "https://www.manga-nova.com/",
        ["Content-Type"] = "application/json",
    }
    local responses = requestManager:customRequest(url, "GET", nil, customHeaders)

    if responses then
        self.results = {}

        -- Extract relevant information from the JSON response
        for i = 1, #responses.series do
            local temp = {}
            temp.text = responses.series[i].title
            temp.slug = responses.series[i].slug
            table.insert(self.results, temp)
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

    -- Requête personnalisée
    local customHeaders = {
        ["User-Agent"] = "Mozilla/5.0 (X11; Linux x86_64; rv:122.0) Gecko/20100101 Firefox/122.0",
        ["Authorization"] = "Bearer " .. token,
        ["Origin"] = "https://www.manga-nova.com",
        ["Referer"] = "https://www.manga-nova.com/",
        ["Content-Type"] = "application/json",
    }
    local responses = requestManager:customRequest(url, "GET", nil, customHeaders)
    if responses then
        self.results = {}

        -- Extract information about chapters from the JSON response
        for i = 1, #responses.serie.chapitres[1].chapitres do
            local temp = {}
            temp.text = responses.serie.chapitres[1].chapitres[i].title
            temp.number = responses.serie.chapitres[1].chapitres[i].number
            temp.slug = slug
            table.insert(self.results, temp)
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

    -- Requête personnalisée
    local customHeaders = {
        ["User-Agent"] = "Mozilla/5.0 (X11; Linux x86_64; rv:122.0) Gecko/20100101 Firefox/122.0",
        ["Authorization"] = "Bearer " .. token,
        ["Origin"] = "https://www.manga-nova.com",
        ["Referer"] = "https://www.manga-nova.com/",
        ["Content-Type"] = "application/json",
    }
    local responses = requestManager:customRequest(url, "GET", nil, customHeaders)
    logger.info("Chapter NB page " ..#responses.images)
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