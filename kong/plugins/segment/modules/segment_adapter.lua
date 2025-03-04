local SegmentEvent = require("kong.plugins.segment.modules.segment_event")

local SegmentAdapter = {}
SegmentAdapter.__index = SegmentAdapter

function SegmentAdapter:new(requestInfo)
  local self = setmetatable({}, SegmentAdapter)
  self.requestInfo = requestInfo
  return self
end

function SegmentAdapter:convert()
  local userId, err = self.requestInfo:get_user_id()
  if err then return nil, err end

  local requestId, userAgent = self.requestInfo:get_headers_info()
  local url = self.requestInfo:get_full_url()

  return SegmentEvent:new({
    url = url,
    userId = userId,
    userAgent = userAgent,
    messageId = requestId
  })
end

return SegmentAdapter
