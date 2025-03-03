local Event = {}

Event.__index = Event

function Event:new(userId)
  local self = setmetatable({}, Event)
  self.userId = userId

  return self
end


function Event:to_table()
  return {
    userId = self.userId,
  }
end

return Event
