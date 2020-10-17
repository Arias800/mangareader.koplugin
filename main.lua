local DataStorage = require("datastorage")
local InputContainer = require("ui/widget/container/inputcontainer")
local InfoMessage = require("ui/widget/infomessage")
local UIManager = require("ui/uimanager")
local ltn12 = require("ltn12")
local DEBUG = require("dbg")
local _ = require("gettext")
local json = require("json")
local http = require("socket.http")
local https = require("ssl.https")
local Menu = require("ui/widget/menu")
local UIManager = require("ui/uimanager")
local Screen = require("device").screen
local DownloadBackend = require("internaldownloadbackend")
local Device = require("device")
local logger = require("logger")
local lfs = require("libs/libkoreader-lfs")
local turbo = require("turbo")
local httpclient = require("httpclient")
local InputDialog = require("ui/widget/inputdialog")

local ffi = require("ffi")
local C = ffi.C
ffi.cdef[[
int remove(const char *);
int rmdir(const char *);
]]

require("ffi/zeromq_h")


local WLNReader = InputContainer:new{
    name = "wlnreader",
    is_doc_only = false,
    results = {},
}




function WLNReader:init()
    self.ui.menu:registerToMainMenu(self)

end

function WLNReader:addToMainMenu(menu_items)
    menu_items.wlnreader = {
        text = _("WLN Reader"),
        sub_item_table = {
            {
                text_func = function()
                    return  _("Search")
                end,
                callback = function()
		     WLNReader: searchInput()                
                end
            },
            {
                text_func = function()
                    return  _("Bye")
                end,
                callback = function()
                     UIManager:show(InfoMessage:new{
                     	text = _("Hello, plugin world"),
            	      })
                end
            }
        }
    }
end

function WLNReader:_makeRequest(url, method, request_body)
    local sink = {}
    local source = ltn12.source.string(request_body)
    local respbody = {}
    http.request{
        url = url,
        method = method,
        sink = ltn12.sink.table(sink),
        source = source,
        headers = {
            ["Content-Length"] = #request_body,
            ["Content-Type"] = "application/json"
        }
    }

    if not sink[1] then
        error("No response from WLN Server")
    end
    -- print log from response body
    print(table.concat(sink))
    local response = json.decode(table.concat(sink))
   -- print("series id: ".. response.data.results[1].sid)
    if response.error then
        error(response.error)
    end

    return response
end

function WLNReader:printSearchResult(title)
   -- get response from site
   -- local request_body = '{"mode" : "search-advanced","title-search-text" : "' .. title .. '"}'
    local request_body = '{"title": "'.. title ..'", "mode": "search-title"}'
    local url = "https://www.wlnupdates.com/api" 
    local responses = self:_makeRequest(url, "POST", request_body)	
    print("series id: ".. responses.data.results[1].sid)
    --- print results
   local WLNSearch = Menu:new{
    title = "Search results:",
    width = Screen:getWidth(),
    height = Screen:getHeight(),
    no_title = false,
    parent = nil,
    } 
    self.results = {}
    	for i=1,#responses.data.results do
    	temp = {}
    		temp.text = responses.data.results[i].match[1][2]
    		temp.name = nil
                temp.callback = function()
                        WLNReader:searchDetail(responses.data.results[i].sid)
                        UIManager:close(WLNSearch)	
                end
    		print(temp.text)
    		table.insert(self.results, temp)
    	end
    	local items = #self.results
    WLNSearch:switchItemTable("Results", self.results , items, nil)  
    UIManager:show(WLNSearch)	
    WLNSearch:onFirstPage()
    print("showed")
    return responses.id
end

function WLNReader:searchDetail(sid)
   -- get response from site
   -- local request_body = '{"mode" : "search-advanced","title-search-text" : "' .. title .. '"}'
    local request_body = '{"id": "'.. sid ..'", "mode": "get-series-id"}'
    local url = "https://www.wlnupdates.com/api" 
    local responses = self:_makeRequest(url, "POST", request_body)	
    print("series id: ".. responses.data.releases[1].srcurl)
    --- print results
   local WLNSearch2 = Menu:new{
    title = "Chapters:",
    width = Screen:getWidth(),
    height = Screen:getHeight(),
    no_title = false,
    parent = nil,
    } 
    self.results = {}
    --print(type(responses.data.releases[6].chapter))
    --print(type(responses.data.releases[27].chapter)) 
    print(#responses.data.releases)
    
    if #responses.data.releases > 15 then k =#responses.data.releases  else k = #responses.data.releases end
    	for i=1, k do
    	temp = {}

    	    	if type(responses.data.releases[i].volume) ~= "number" then vol = "" else vol = responses.data.releases[i].volume
    	 end
    	if type(responses.data.releases[i].chapter) ~= "number" then chap = "" else chap = responses.data.releases[i].chapter
    	 end
    	
    		temp.text = "Volume ".. vol .. ", Chapter " .. chap
    		temp.name = nil
                temp.callback = function()
                
                if type(responses.data.releases[i].volume) ~= "number" then vol1 = "" else vol1 = 			responses.data.releases[i].volume end
    	if type(responses.data.releases[i].chapter) ~= "number" then chap1 = "" else chap1 = responses.data.releases[i].chapter end
    		tempname = responses.data.title .." - ".. "Volume ".. vol1 .. ", Chapter " .. chap1
                WLNReader:downloadEbook(responses.data.releases[i].srcurl,tempname)
                end
    		print(temp.text)
    		table.insert(self.results, temp)
    	end
    	local items = #self.results
    WLNSearch2:switchItemTable("Results", self.results , items, nil)
    UIManager:show(WLNSearch2)	
    WLNSearch2:onFirstPage()
    print("showed2")
end

function WLNReader:downloadEbook(url,name)
local request_body = '{"title": "'.. name ..'", "urls": ["' .. url .. '"]}'
print(request_body)
local url2 = "https://epub.press/api/v1/books" 
local responses = self:_makeRequest(url2, "POST", request_body)
print(responses.id)
download_id = responses.id
fulllink ="https://epub.press/api/v1/books/".. download_id .."/download?filetype=epub"
--DownloadBackend:download(fulllink, Device.home_dir .. "/wlnreader/"..name..".pdf")
WLNReader:_makeRequestGET("https://epub.press/api/v1/books/".. download_id .."/download", Device.home_dir .. "/wlnreader/"..name..".epub")
end

function WLNReader:_makeRequestGET(url, fname)
    local sink = {}
    https.request{
        url = url,
        method = "GET",
        header = { ["Host"] = "epub.press" },
        sink = ltn12.sink.table(sink)
    }

    if not sink[1] then
        error("No response from WLN Server")
    end
    -- print log from response body
    print(table.concat(sink))
    
       for i=1,10 do
	local data = ""

	local function collect(chunk)
	  if chunk ~= nil then
	    data = data .. chunk
	    end
	  return true
	end

	local ok, statusCode, headers, statusText = http.request {
	  method = "GET",
	  url = url,
	  sink = collect
	}

	print("ok\t",         ok);
	print("statusCode", statusCode)
	print("statusText", statusText)
	print("headers:")
	for i,v in pairs(headers) do
	  print("\t",i, v)
	end
	print(type(data))
   	print(#data)
   	if #data > 1000 then
   	io.output(fname)
   	io.write(data)
   	io.close()
   	print("file downloaded")
   	
   	local ReaderUI = require("apps/reader/readerui")
        ReaderUI:showReader(fname)
        break
	end
	end
	
    return response
end

function WLNReader:searchInput()
 self.search_server_dialog = InputDialog:new{
        title = _("Search novel updates from WLNUpdates "),
        input = "",
        hint = _("Search string"),

        input_hint = _("Oregairu"),
        input_type = "string",
        description = _("Title of the novel:"),
        buttons = {
            {
                {
                    text = _("Cancel"),
                    callback = function()
                        UIManager:close(search_server_dialog)
                    end,
                },
                {
                    text = _("Search"),
                    is_enter_default = true,
                    callback = function()
                        UIManager:close(self.search_server_dialog)
                        self:printSearchResult(self.search_server_dialog:getInputText()) 
                    end,
                },
            }
        },
    }
    UIManager:show(self.search_server_dialog)
    self.search_server_dialog:onShowKeyboard()
end



return WLNReader
