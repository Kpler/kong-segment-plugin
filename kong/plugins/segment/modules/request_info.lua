local SegmentEvent = require "kong.plugins.segment.modules.segment_event"
local jwt_utils = require("kong.plugins.segment.modules.jwt_utils")

local RequestInfo = {}
local get_full_url

RequestInfo.__index = RequestInfo

function RequestInfo:new(kongRequest)
  local self = setmetatable({}, RequestInfo)
  self.kongRequest = kongRequest

  return self
end

function RequestInfo:to_segment_event()
  local userId, get_user_id_err = jwt_utils.get_user_id()

  if get_user_id_err then
    kong.log.error(get_user_id_err)
    return nil, get_user_id_err
  end

  local requestId = self.kongRequest.get_header("x-kong-request-id")

  if not requestId then
    kong.log.warn("Could not retrieve request id from request, sending empty value")
    requestId = ""
  end

  local url = get_full_url(self)

  local segmentEvent =  SegmentEvent:new(
    url,
    userId,
    requestId
  )
  return segmentEvent, nil
end


get_full_url = function(self)
  local scheme = self.kongRequest.get_scheme()
  local host = self.kongRequest.get_host()
  local port = self.kongRequest.get_port()
  local path = self.kongRequest.get_path()
  local query = self.kongRequest.get_raw_query()

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

return RequestInfo
