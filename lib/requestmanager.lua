local table = require("table")
local https = require("ssl.https")
local ltn12 = require("ltn12")
local json = require("json")
local logger = require("logger")
local util = require("util")

-- RequestManager Class
local RequestManager = {}
local response_body = {}

-- Constructor
function RequestManager:new()
    local obj = {}
    setmetatable(obj, self)
    self.__index = self
    return obj
end

-- Method to perform a custom request
function RequestManager:customRequest(url, method, data, headers)
    local _, status, _ = https.request {
        url = url,
        method = method,
        headers = headers == nil and {} or headers,
        source = ltn12.source.string(data == nil and "" or data),
        sink = ltn12.sink.table(response_body),
    }

    if status ~= 200 then
        return nil
    end

    local content = table.concat(response_body)
    -- Check if the response is in JSON format.
    -- Don't rely on headers, as they are unreliable for Manga Nova.
    if util.stringStartsWith(content, "{") and util.stringEndsWith(content, "}") then
        logger.dbg("JSON detected")
        content = json.decode(content)
    end
    return content
end

return RequestManager
