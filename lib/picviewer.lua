local _ = require("gettext")
local table = require("table")
local https = require("ssl.https")
local bit = require("bit")
local ltn12 = require("ltn12")

local InfoMessage = require("ui/widget/infomessage")
local ImageViewer = require("ui/widget/imageviewer")
local UIManager = require("ui/uimanager")
local RenderImage = require("ui/renderimage")
local Blitbuffer = require("ffi/blitbuffer")

local PicViewer = {
    current_page = 1,
    loaded_picture = 0,
    pic_data = {},
    preload_finished = false,
    batch_size = 2,  -- Load 2 pages at a time (double page)
    loaded_pages = {},
    url_list = nil,
    fused_images = {},
}

function PicViewer:decryptXOR(encrypted, encryption_hex)
    if not encrypted or not encryption_hex then return encrypted end

    local key = encryption_hex:gsub("%x%x", function(c)
        return string.char(tonumber(c, 16))
    end)

    local parsed = {}
    for i = 1, #encrypted do
        local xor_result = bit.bxor(
            string.byte(encrypted, i),
            string.byte(key, ((i - 1) % #key) + 1)
        )
        parsed[i] = string.char(xor_result)
    end

    return table.concat(parsed)
end

function PicViewer:displayPic(url_list)
    if not url_list or #url_list == 0 then
        UIManager:show(InfoMessage:new{ text = _("No images to display."), timeout = 3 })
        return
    end

    self.url_list = url_list

    print("Starting to display pics, total pages:", #url_list)

    if #url_list % 2 ~= 0 and self.current_page == 1 then
        -- Insert a placeholder image in the second position
        table.insert(url_list, 2, { path = "white", key = nil })  -- Placeholder image
    end

    self:loadPagesRange(1, math.min(self.batch_size, #url_list), function()
        self.fused_images = self:createFusedImages()
        self.viewer = ImageViewer:new{
            image = self.fused_images,
            fullscreen = true,
            with_title_bar = false,
            images_list_nb = math.ceil(#url_list / 2),
            onShowNextImage = function() self:loadNextPage() end,
            onShowPrevImage = function() self:loadPrevPage() end,
            onClose = function() self:cleanup() end,
        }
        self.viewer.image_disposable = false
        UIManager:show(self.viewer)
    end)
end

function PicViewer:loadNextPage()
    if not self.url_list then return end

    local next_page_start = self.current_page + self.batch_size
    local next_page_end = math.min(next_page_start + self.batch_size - 1, #self.url_list)

    if next_page_start > #self.url_list then
        UIManager:show(InfoMessage:new{ text = _("Chapter ended."), timeout = 3 })
        PicViewer:cleanup()
        return
    end

    if next_page_start <= self.current_page then
        return
    end

    print("Loading next page set:", next_page_start, "to", next_page_end)
    self:loadPagesRange(next_page_start, next_page_end, function()
        self.current_page = next_page_start
        self.fused_images = self:createFusedImages()
        self.viewer:switchToImageNum(#self.fused_images)
    end)
end

function PicViewer:loadPrevPage()
    if not self.url_list then return end

    local prev_page_end = self.current_page - 1
    local prev_page_start = math.max(1, prev_page_end - self.batch_size + 1)

    if prev_page_start < 1 then return end

    if prev_page_start >= self.current_page then
        return
    end

    print("Moving to previous page set:", prev_page_start, "to", prev_page_end)
    self:loadPagesRange(prev_page_start, prev_page_end, function()
        self.current_page = prev_page_start
        self.fused_images = self:createFusedImages()
        self.viewer:switchToImageNum(#self.fused_images - 1)
    end)
end

function PicViewer:createFusedImages()
    for i = #self.fused_images, 1, -1 do
        self.fused_images[i] = nil
    end

    for i = 1, #self.pic_data, 2 do
        local img1 = self.pic_data[i]
        local img2 = self.pic_data[i + 1] or nil
        if img1 then
            table.insert(self.fused_images, img2 and self:fuseImages(img2, img1) or img1)
        end
    end

    return self.fused_images
end

function PicViewer:loadPagesRange(start_page, end_page, callback)
    end_page = math.min(end_page, #self.url_list)
    local loaded_count = 0
    local total_to_load = end_page - start_page + 1

    for i = start_page, end_page do
        if not self.loaded_pages[i] then
            print("Loading page:", i)

            local image_path = self.url_list[i].path
            if image_path == "white" then
                print("Odd total page number")
            else
                local success, content = pcall(function()
                    local response_body = {}
                    local result, code = https.request{
                        url = image_path,
                        sink = ltn12.sink.table(response_body),
                        headers = { ["User-Agent"] = "Mozilla/5.0" },
                    }

                    if code ~= 200 then
                        error(string.format("Failed to load image %d: HTTP %d", i, code))
                    end
                    local content = table.concat(response_body)
                    if self.url_list[i].key then
                        content = self:decryptXOR(content, self.url_list[i].key)
                    end
                    return content
                end)

                if success then
                    local bmp = RenderImage:renderImageData(content, #content, false)
                    if bmp then
                        self.pic_data[i] = bmp
                        self.loaded_pages[i] = true
                        self.loaded_picture = self.loaded_picture + 1
                        print("Successfully loaded page:", i)
                    end
                else
                    UIManager:show(InfoMessage:new{ text = _("Failed to load image: " .. tostring(content)), timeout = 3 })
                    print("Failed to load page:", i)
                end
            end
        end
        loaded_count = loaded_count + 1
        if loaded_count == total_to_load and callback then
            callback()
        end
    end
end

function PicViewer:fuseImages(bb1, bb2)
    if not bb1 then return bb2 end
    if not bb2 then return bb1 end

    local fused_bb = Blitbuffer.new(bb1:getWidth() + bb2:getWidth(), math.max(bb1:getHeight(), bb2:getHeight()), bb1:getType())
    fused_bb:blitFrom(bb1, 0, 0)
    fused_bb:blitFrom(bb2, bb1:getWidth(), 0)

    return fused_bb
end

function PicViewer:cleanup()
    -- Clear all loaded picture data
    self.pic_data = {}
    self.loaded_pages = {}
    self.fused_images = {}

    -- Reset current page to the first page
    self.current_page = 1
    self.loaded_picture = 0
    self.preload_finished = false
    self.batch_size = 2  -- Reset batch size if needed

    -- Close the viewer widget (if it's open)
    if self.viewer then
        UIManager:close(self.viewer)
    end

    print("PicViewer resources cleaned up.")
end

return PicViewer
