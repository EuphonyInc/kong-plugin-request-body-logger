local req_read_body = ngx.req.read_body
local req_get_body_data = ngx.req.get_body_data

local _M = {}

function _M.get_body()
  req_read_body()
  local body = req_get_body_data()
  return body
end


return _M
