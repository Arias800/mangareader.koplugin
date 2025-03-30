-- Import necessary modules
local _ = require("gettext")
local table = require("table")
local bit = require("bit")
local ltn12 = require("ltn12")

local InfoMessage = require("ui/widget/infomessage")
local ImageViewer = require("ui/widget/imageviewer")
local UIManager = require("ui/uimanager")
local RenderImage = require("ui/renderimage")
local Blitbuffer = require("ffi/blitbuffer")
local RequestManager = require("lib/requestmanager")
local Settings = require("lib/settings")

-- Load the settings
local MainConfig = Settings.initializeConfig()

--- PicViewer Module
-- This module handles the display and management of images from a list of URLs.
local PicViewer = {
    current_page = 1,
    loaded_picture = 0,
    pic_data = {},
    preload_finished = false,
    force_single_page = MainConfig.manga_reader.single_page,
    loaded_pages = {},
    url_list = nil,
    fused_images = {},
    request_manager = RequestManager:new(),
}

--- Updates the batch size for loading images.
function PicViewer:updateBatchSize()
    self.batch_size = self.force_single_page and 1 or 2
end

--- Decrypts an encrypted string using XOR with a given hex key.
-- @param encrypted The encrypted string.
-- @param encryption_hex The hex key for decryption.
-- @return The decrypted string.
function PicViewer:decryptXOR(encrypted, encryption_hex)
    if not encrypted or not encryption_hex then return encrypted end

    local key = encryption_hex:gsub("%x%x", function(c)
        return string.char(tonumber(c, 16))
    end)

    local parsed = {}
    for i = 1, #encrypted do
        parsed[i] = string.char(bit.bxor(
            string.byte(encrypted, i),
            string.byte(key, ((i - 1) % #key) + 1)
        ))
    end

    return table.concat(parsed)
end

--- Displays a list of images from given URLs.
-- Initializes the viewer and loads the first batch of images.
-- @param url_list A list of image URLs.
function PicViewer:displayPic(url_list)
    if not url_list or #url_list == 0 then
        UIManager:show(InfoMessage:new{ text = _("No images to display."), timeout = 3 })
        return
    end

    self.url_list = url_list
    self:updateBatchSize()

    if not self.force_single_page and #self.url_list % 2 ~= 0 then
        table.insert(self.url_list, 2, { path = "white", key = nil })
    end

    self:loadPagesRange(1, math.min(self.batch_size, #url_list), function()
        self:createFusedImages()
        self.viewer = ImageViewer:new{
            image = self.fused_images,
            fullscreen = true,
            with_title_bar = false,
            images_list_nb = self.force_single_page and #url_list or math.ceil(#url_list / 2),
            onShowNextImage = function() self:loadNextPage() end,
            onShowPrevImage = function() self:loadPrevPage() end,
            onClose = function() self:cleanup() end,
        }
        self.viewer.image_disposable = false
        UIManager:show(self.viewer)
    end)
end

--- Loads the next set of pages and updates the viewer.
function PicViewer:loadNextPage()
    if not self.url_list then return end

    local next_page_start = self.current_page + self.batch_size
    if next_page_start > #self.url_list then
        UIManager:show(InfoMessage:new{ text = _("Chapter ended."), timeout = 3 })
        self:cleanup()
        return
    end

    local next_page_end = math.min(next_page_start + self.batch_size - 1, #self.url_list)
    self:loadPagesRange(next_page_start, next_page_end, function()
        self.current_page = next_page_start
        self:createFusedImages()
        self.viewer:switchToImageNum(self.force_single_page and self.current_page or math.ceil(self.current_page / 2))
    end)
end

--- Loads the previous set of pages and updates the viewer.
function PicViewer:loadPrevPage()
    if not self.url_list then return end

    local prev_page_end = self.current_page - 1
    local prev_page_start = math.max(1, prev_page_end - self.batch_size + 1)

    if prev_page_start < 1 then return end

    self:loadPagesRange(prev_page_start, prev_page_end, function()
        self.current_page = prev_page_start
        self:createFusedImages()
        self.viewer:switchToImageNum(self.force_single_page and self.current_page or math.ceil(self.current_page / 2))
    end)
end

--- Creates fused images for dual-page mode.
-- If in single-page mode, simply adds the current image.
-- @return A table of fused images.
function PicViewer:createFusedImages()
    if self.force_single_page then
        if self.pic_data[self.current_page] then
            table.insert(self.fused_images, self.pic_data[self.current_page])
        end
    else
        local start_idx = math.floor((self.current_page - 1) / 2) * 2 + 1
        for i = start_idx, math.min(start_idx + 1, #self.url_list), 2 do
            local img1, img2 = self.pic_data[i], self.pic_data[i + 1]
            table.insert(self.fused_images, img2 and img1 and self:fuseImages(img2, img1) or img1)
        end
    end

    return self.fused_images
end

--- Loads a range of pages asynchronously.
-- @param start_page The starting page index.
-- @param end_page The ending page index.
-- @param callback The callback function after loading.
function PicViewer:loadPagesRange(start_page, end_page, callback)
    end_page = math.min(end_page, #self.url_list)
    local loaded_count = 0

    for i = start_page, end_page do
        if not self.loaded_pages[i] then
            local image_path = self.url_list[i].path
            if image_path ~= "white" then
                local success, content = pcall(function()
                    local response = self.request_manager:customRequest(image_path, "GET", nil, { ["User-Agent"] = "Mozilla/5.0" })
                    return self.url_list[i].key and self:decryptXOR(response, self.url_list[i].key) or response
                end)

                if success then
                    local bmp = RenderImage:renderImageData(content, #content, false)
                    if bmp then
                        self.pic_data[i] = bmp
                        self.loaded_pages[i] = true
                    end
                else
                    UIManager:show(InfoMessage:new{ text = _("Failed to load image"), timeout = 3 })
                end
            end
        end
        loaded_count = loaded_count + 1
        if loaded_count == (end_page - start_page + 1) and callback then callback() end
    end
end

--- Fuses two images side by side.
-- @param bb1 The first image.
-- @param bb2 The second image.
-- @return The fused image.
function PicViewer:fuseImages(bb1, bb2)
    local fused_bb = Blitbuffer.new(bb1:getWidth() + bb2:getWidth(), math.max(bb1:getHeight(), bb2:getHeight()), bb1:getType())
    fused_bb:blitFrom(bb1, 0, 0)
    fused_bb:blitFrom(bb2, bb1:getWidth(), 0)
    return fused_bb
end

--- Cleans up resources and resets the viewer.
function PicViewer:cleanup()
    self.pic_data, self.loaded_pages, self.fused_images = {}, {}, {}
    self.current_page, self.loaded_picture, self.preload_finished = 1, 0, false
    if self.viewer then UIManager:close(self.viewer) self.viewer = nil end
end

return PicViewer
