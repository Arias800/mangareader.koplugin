-- Import necessary modules
local table = require("table")
local https = require("ssl.https")
local ltn12 = require("ltn12")
local json = require("json")
local logger = require("logger")
local util = require("util")

--- RequestManager Class
-- A class to manage HTTP requests with customizable methods and headers.
local RequestManager = {}
RequestManager.__index = RequestManager

--- Constructor
-- Creates a new instance of RequestManager.
-- @return A new RequestManager object.
function RequestManager:new()
    local obj = setmetatable({}, self)
    return obj
end

--- Performs a custom HTTP request.
-- @param url The URL to send the request to.
-- @param method The HTTP method to use (e.g., "GET", "POST").
-- @param data The data to send with the request (optional).
-- @param headers A table of headers to include in the request (optional).
-- @return The response content, either as a string or a decoded JSON table.
function RequestManager:customRequest(url, method, data, headers)
    local response_body = {}  -- Table to store the response body

    -- Perform the HTTP request
    local _, status, _ = https.request {
        url = url,
        method = method,
        headers = headers or {},  -- Use an empty table if headers are not provided
        source = ltn12.source.string(data or ""),  -- Use an empty string if data is not provided
        sink = ltn12.sink.table(response_body),
    }

    -- Check if the request was successful
    if status ~= 200 then
        logger.err("Request failed with status: " .. status)
        return nil
    end

    -- Concatenate the response body into a single string
    local content = table.concat(response_body)

    -- Check if the response is in JSON format
    if util.stringStartsWith(content, "{") and util.stringEndsWith(content, "}") then
        logger.dbg("JSON detected")
        content = json.decode(content)
    else
        logger.warn("Response is not in valid JSON format")
    end

    return content
end

return RequestManager
