local WidgetContainer = require("ui/widget/container/widgetcontainer")
local InfoMessage = require("ui/widget/infomessage")
local ImageViewer = require("ui/widget/imageviewer")
local _ = require("gettext")
local UIManager = require("ui/uimanager")
local logger = require("logger")
local RenderImage = require("ui/renderimage")
local table = require("table")
local https = require("ssl.https")
local bit = require("bit")
local ltn12 = require("ltn12")

local PicViewer =
    WidgetContainer:new {
        module_name = "picviewer",
        is_doc_only = false,
        results = {},
        path = {}
}

function PicViewer:decryptXOR(encrypted, encryptionHex)
    -- Convertir la clé hexadécimale en une chaîne de caractères
    local key = encryptionHex:gsub("%x%x", function(c) return c.char(tonumber(c, 16)) end)

    -- Initialiser un tableau pour stocker les caractères déchiffrés
    local parsed = {}

    -- Parcourir chaque caractère de la chaîne chiffrée
    for i = 1, #encrypted do
        -- Effectuer l'opération XOR sur les octets correspondants de la chaîne chiffrée et de la clé
        local xorResult = bit.bxor(string.byte(encrypted, i), string.byte(key, ((i - 1) % #key) + 1))

        -- Convertir le résultat XOR en caractère et l'ajouter au tableau
        parsed[i] = string.char(xorResult)
    end

    -- Concaténer les caractères déchiffrés pour former la chaîne déchiffrée finale
    return table.concat(parsed, "")
end

function PicViewer:displayPic(url_list)
    local picData = {}
    local responseBody = {}

    -- Current page
    local p = 1
    -- Total number of loaded picture
    local loaded_picture = 0
    logger.info("Loading chapters in memory")

    https.request {
        url = url_list[p].path,
        sink = ltn12.sink.table(responseBody),
        headers = {
            ["User-Agent"] = "Mozilla/5.0 (X11; Linux x86_64; rv:122.0) Gecko/20100101 Firefox/122.0",
        },
    }
    local content = table.concat(responseBody)

    if url_list[p].key then
        logger.info("XOR protect")
        content = PicViewer:decryptXOR(content, url_list[p].key)
    end

    local bmp = RenderImage:renderImageData(content, #content, false)
    table.insert(picData, bmp)
    p = p + 1

    local viewer = UIManager:show(ImageViewer:new{
        image = picData,
        fullscreen = true,
        with_title_bar = false,
        image_disposable = false,
        images_list_nb = #url_list,

        onShowNextImage = function(viewer)
            if p > #url_list then
                UIManager:show(
                    InfoMessage:new {
                        text = _("Chapter ended."),
                        timeout = 3
                    }
                )
                UIManager:close(viewer)
            else
                picData, p = PicViewer:lazyload(viewer, url_list, picData, p, loaded_picture)
            end
        end,

        onShowPrevImage = function(viewer)
            picData, p  = PicViewer:prevImage(viewer, p, picData)
        end,
    })

end

function PicViewer:lazyload(viewer, url_list, picData, p, loaded_picture)
    logger.info(p)
    local responseBody = {}
    -- No need to load picture twice
    if p > loaded_picture then
        logger.info("Load picture number " ..p)

        https.request {
            url = url_list[p].path,
            sink = ltn12.sink.table(responseBody),
            headers = {
                ["User-Agent"] = "Mozilla/5.0 (X11; Linux x86_64; rv:122.0) Gecko/20100101 Firefox/122.0",
            },
        }
        local content = table.concat(responseBody)

        if url_list[p].key then
            logger.info("XOR protect")
            content = PicViewer:decryptXOR(content, url_list[p].key)
        end

        local bmp = RenderImage:renderImageData(content, #content, false)
        table.insert(picData, bmp)
    end
    viewer:switchToImageNum(p)
    p = p + 1
    loaded_picture = loaded_picture + 1
    return picData, p
end

function PicViewer:prevImage(viewer, p, picData)
    p = p - 1
    viewer:switchToImageNum(p)
    return picData, p
end

return PicViewer