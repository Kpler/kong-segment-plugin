local RequestContext = require("kong.plugins.segment.modules.request_context")
local SegmentEvent = require("kong.plugins.segment.modules.segment_event")

local SegmentAdapter = {}
SegmentAdapter.__index = SegmentAdapter

function SegmentAdapter:new()
  local self = setmetatable({}, SegmentAdapter)
  return self
end

function SegmentAdapter:convert()
  local userId, err = RequestContext.get_user_id()
  if err then return nil, err end

  local requestId, userAgent = RequestContext.get_headers_info()

  return SegmentEvent:new({
    url = RequestContext.get_full_url(),
    userId = userId,
    userAgent = userAgent,
    messageId = requestId,
    ip = RequestContext.get_ip(),
    host = RequestContext.get_host(),
    path = RequestContext.get_path()
  }), nil
end

return SegmentAdapter
