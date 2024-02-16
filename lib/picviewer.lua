local _ = require("gettext")
local table = require("table")
local https = require("ssl.https")
local bit = require("bit")
local ltn12 = require("ltn12")

local InfoMessage = require("ui/widget/infomessage")
local ImageViewer = require("ui/widget/imageviewer")
local UIManager = require("ui/uimanager")
local RenderImage = require("ui/renderimage")

local PicViewer = {
    -- Current page
    current_page = 1,
    -- Total number of loaded picture
    loaded_picture = 0,
    pic_data = {},
}

function PicViewer:decryptXOR(encrypted, encryption_hex)
    -- Convert the hexadecimal key into a character string
    local key = encryption_hex:gsub("%x%x", function(c) return c.char(tonumber(c, 16)) end)

    -- Initialize an array to store decrypted characters
    local parsed = {}

    -- Browse each character of the encrypted string
    for i = 1, #encrypted do
        -- Use the XOR operation on the corresponding bytes of the encrypted string and key
        local xor_result = bit.bxor(string.byte(encrypted, i), string.byte(key, ((i - 1) % #key) + 1))

        -- Convert the XOR result into a character and add it to the array
        parsed[i] = string.char(xor_result)
    end

    -- Concatenate the decoded characters to form the final decoded string
    return table.concat(parsed, "")
end

function PicViewer:displayPic(url_list)
    -- Current page
    self.current_page = 1 -- Lua isn't zero based
    -- Total number of loaded picture
    self.loaded_picture = 1
    self.pic_data = {}
    local response_body = {}

    https.request {
        url = url_list[self.current_page].path,
        sink = ltn12.sink.table(response_body),
        headers = {
            ["User-Agent"] = "Mozilla/5.0 (X11; Linux x86_64; rv:122.0) Gecko/20100101 Firefox/122.0",
        },
    }
    local content = table.concat(response_body)

    if url_list[self.current_page].key then
        content = PicViewer:decryptXOR(content, url_list[self.current_page].key)
    end

    -- Initialize the viewer with the first page
    local bmp = RenderImage:renderImageData(content, #content, false)
    table.insert(self.pic_data, bmp)

    local viewer = ImageViewer:new{
        image = self.pic_data,
        fullscreen = true,
        with_title_bar = false,
        images_list_nb = #url_list,

        onShowNextImage = function(viewer)
            -- Function to load next picture
            PicViewer:lazy(viewer, url_list)
        end,

        onShowPrevImage = function(viewer)
            -- Return to the previous page.
            -- Obviously we don't want to go under 1.
            if self.current_page ~= 1 then
                self.current_page = self.current_page - 1
                viewer:switchToImageNum(self.current_page)
            end
            return self.current_page
        end,
    }
    -- Needed to reuse picture
    viewer.image_disposable = false
    UIManager:show(viewer)

end

function PicViewer:lazy(viewer, url_list)
    self.current_page = self.current_page + 1
    local response_body = {}
    if self.current_page > #url_list then
        UIManager:show(
            InfoMessage:new {
                text = _("Chapter ended."),
                timeout = 3
            }
        )
        UIManager:close(viewer)
    else
        -- No need to load picture twice
        if self.current_page > self.loaded_picture then
            https.request {
                url = url_list[self.current_page].path,
                sink = ltn12.sink.table(response_body),
                headers = {
                    ["User-Agent"] = "Mozilla/5.0 (X11; Linux x86_64; rv:122.0) Gecko/20100101 Firefox/122.0",
                },
            }
            local content = table.concat(response_body)

            if url_list[self.current_page].key then
                content = PicViewer:decryptXOR(content, url_list[self.current_page].key)
            end

            local bmp = RenderImage:renderImageData(content, #content, false)
            table.insert(self.pic_data, bmp)

            self.loaded_picture = self.loaded_picture + 1
        end
        viewer:switchToImageNum(self.current_page)
    end
end

return PicViewer