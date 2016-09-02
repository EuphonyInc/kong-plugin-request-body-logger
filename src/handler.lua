local basic_serializer = require "kong.plugins.extended-log-serializer.basic"
local BasePlugin = require "kong.plugins.base_plugin"
local access = require('kong.plugins.request-body-logger.access')
local cjson = require "cjson"
local ngx_decode_args = ngx.decode_args
local encode_args = ngx.encode_args
local url = require "socket.url"

local HttpBodyLogHandler = BasePlugin:extend()

HttpBodyLogHandler.PRIORITY = 1

local HTTPS = "https"

local req_body = {}

local function parse_json(body)
  if body then
    local status, res = pcall(cjson.decode, body)
    if status then
      return res
    end
  end
end

local function decode_args(body)
  if body then
    return ngx_decode_args(body)
  end
  return {}
end

-- Generates http payload .
-- @param `method` http method to be used to send data
-- @param `parsed_url` contains the host details
-- @param `message`  Message to be logged
-- @return `body` http payload
local function generate_post_payload(method, parsed_url, body)

  return string.format(
    "%s %s HTTP/1.1\r\nHost: %s\r\nConnection: Keep-Alive\r\nContent-Type: application/json\r\nContent-Length: %s\r\n\r\n%s",
    method:upper(), parsed_url.path, parsed_url.host, string.len(body), body)
end

-- Parse host url
-- @param `url`  host url
-- @return `parsed_url`  a table with host details like domain name, port, path etc
local function parse_url(host_url)
  local parsed_url = url.parse(host_url)
  if not parsed_url.port then
    if parsed_url.scheme == "http" then
      parsed_url.port = 80
     elseif parsed_url.scheme == HTTPS then
      parsed_url.port = 443
     end
  end
  if not parsed_url.path then
    parsed_url.path = "/"
  end
  return parsed_url
end

-- Log to a Http end point.
-- @param `premature`
-- @param `conf`     Configuration table, holds http endpoint details
-- @param `message`  Message to be logged
local function log(premature, conf, body, name)
  if premature then return end
  name = "["..name.."] "

  local ok, err
  local parsed_url = parse_url(conf.http_endpoint)
  local host = parsed_url.host
  local port = tonumber(parsed_url.port)

  local sock = ngx.socket.tcp()
  sock:settimeout(conf.timeout)

  ok, err = sock:connect(host, port)
  if not ok then
    ngx.log(ngx.ERR, name.."failed to connect to "..host..":"..tostring(port)..": ", err)
    return
  end

  if parsed_url.scheme == HTTPS then
    local _, err = sock:sslhandshake(true, host, false)
    if err then
      ngx.log(ngx.ERR, name.."failed to do SSL handshake with "..host..":"..tostring(port)..": ", err)
    end
  end

  ok, err = sock:send(generate_post_payload(conf.method, parsed_url, body))
  if not ok then
    ngx.log(ngx.ERR, name.."failed to send data to "..host..":"..tostring(port)..": ", err)
  end

  ok, err = sock:setkeepalive(conf.keepalive)
  if not ok then
    ngx.log(ngx.ERR, name.."failed to keepalive to "..host..":"..tostring(port)..": ", err)
    return
  end
end

-- Only provide `name` when deriving from this class. Not when initializing an instance.
function HttpBodyLogHandler:new(name)
  HttpBodyLogHandler.super.new(self, name or "http-log")
end

-- serializes context data into an html message body
-- @param `ngx` The context table for the request being logged
-- @return html body as string
function HttpBodyLogHandler:serialize(ngx)
  return cjson.encode(basic_serializer.serialize(ngx, req_body))
end

function HttpBodyLogHandler:access()
  HttpBodyLogHandler.super.access(self)
  response = access.get_body()
  -- req_body = parse_json(response)
  req_body = decode_args(response)

end

function HttpBodyLogHandler:log(conf)
  HttpBodyLogHandler.super.log(self)

  local ok, err = ngx.timer.at(0, log, conf, self:serialize(ngx), self._name)
  if not ok then
    ngx.log(ngx.ERR, "["..self._name.."] failed to create timer: ", err)
  end
end

return HttpBodyLogHandler
