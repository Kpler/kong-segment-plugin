local cjson = require "cjson"

local SegmentEvent = {}

SegmentEvent.__index = SegmentEvent

function SegmentEvent:new(params)
  local self = setmetatable({}, SegmentEvent)
  self.url = params.url
  self.userId = params.userId
  self.messageId = params.messageId
  self.userAgent = params.userAgent
  self.ip = params.ip
  self.host = params.host
  self.path = params.path

  return self
end


function SegmentEvent:to_json()
  return cjson.encode({
    userId = self.userId,
    messageId = self.messageId,
    context = {
      userAgent = self.userAgent,
      ip = self.ip
    },
    properties = {
      url = self.url,
      host = self.host,
      path = self.path
    }
  })
end

return SegmentEvent
