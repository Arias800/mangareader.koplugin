local table = require("table")
local https = require("ssl.https")
local ltn12 = require("ltn12")
local json = require("json")
local logger = require("logger")
local util = require("util")

-- RequestManager Class
local RequestManager = {}

-- Constructor
function RequestManager:new()
    local obj = {}
    setmetatable(obj, self)
    self.__index = self
    return obj
end

-- Method to perform a custom request
function RequestManager:customRequest(url, method, data, headers)
    local response_body = {}  -- Local response body for each request
    local _, status, _ = https.request {
        url = url,
        method = method,
        headers = headers or {},  -- Simplified header handling
        source = ltn12.source.string(data or ""),
        sink = ltn12.sink.table(response_body),
    }

    if status ~= 200 then
        logger.err("Request failed with status: " .. status)  -- Improved error handling
        return nil
    end

    local content = table.concat(response_body)
    -- Check if the response is in JSON format.
    if util.stringStartsWith(content, "{") and util.stringEndsWith(content, "}") then
        logger.dbg("JSON detected")
        content = json.decode(content)
    else
        logger.warn("Response is not in valid JSON format")  -- Additional warning for invalid JSON
    end
    return content
end

return RequestManager
