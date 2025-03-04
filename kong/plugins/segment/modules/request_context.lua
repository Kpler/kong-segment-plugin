local SegmentEvent = require "kong.plugins.segment.modules.segment_event"
local jwt_utils = require("kong.plugins.segment.modules.jwt_utils")

local RequestContext = {}

RequestContext.__index = RequestContext

function RequestContext.get_user_id()
  local userId, get_user_id_err = jwt_utils.get_user_id()

  if get_user_id_err then
    kong.log.error(get_user_id_err)
    return nil, get_user_id_err
  end
  return userId, nil
end

function RequestContext.get_headers_info()
  local requestId = kong.request.get_header("x-kong-request-id")
  local userAgent = kong.request.get_header("user-agent")
  return requestId, userAgent
end

function RequestContext.get_full_url()
  local scheme = kong.request.get_scheme()
  local host = kong.request.get_host()
  local port = kong.request.get_port()
  local path = kong.request.get_path()
  local query = kong.request.get_raw_query()

  local url = scheme .. "://" .. host
  if (scheme == "http" and port ~= 80) or (scheme == "https" and port ~= 443) then
    url = url .. ":" .. port
  end
  url = url .. path
  if query and query ~= "" then
    url = url .. "?" .. query
  end

  return url
end

function RequestContext.get_ip()
  return kong.client.get_ip()
end

function RequestContext.get_host()
  return kong.request.get_host()
end

function RequestContext.get_path()
  return kong.request.get_path()
end

function RequestContext.get_query_params()

end

return RequestContext
