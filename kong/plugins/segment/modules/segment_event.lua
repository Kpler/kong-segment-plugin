local cjson = require "cjson"

local SegmentEvent = {}

SegmentEvent.__index = SegmentEvent

function SegmentEvent:new(url, userId, messageId)
  local self = setmetatable({}, SegmentEvent)
  self.url = url
  self.userId = userId
  self.messageId = messageId

  return self
end


function SegmentEvent:to_json()
  return cjson.encode({
    url = self.url,
    userId = self.userId,
    messageId = self.messageId
  })
end

return SegmentEvent
