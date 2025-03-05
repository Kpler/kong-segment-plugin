local http = require("resty.http")
local constants = require("kong.plugins.segment.modules.constants")

local SegmentService = {}
SegmentService.__index = SegmentService
local make_segment_request
local async_http_request

function SegmentService:new(write_key, segment_url)
  local self = setmetatable({}, SegmentService)
  self.write_key = write_key
  self.segment_url = segment_url

  return self
end

function SegmentService:track_async(segmentEvent)
  local url = self.segment_url .. "/v1/track"
  local json_segment_data = segmentEvent:to_json(self.write_key)
  -- Schedule the HTTP request to be made asynchronously
  ngx.timer.at(0, async_http_request, { url = url, json_data = json_segment_data })
end

make_segment_request = function(url, json_data)
  local httpc = http.new()
  -- Perform the request
  local res, err = httpc:request_uri(url, {
    method = "POST",
    headers = {
      ["Content-Type"] = "application/json"
    },
    ssl_verify = false,
    body = json_data
  })

  if not res then
    kong.log.err("Failed to make HTTP request: ", err)
    return nil, err
  end

  kong.log.info("HTTP response: ", res.body)
  return res.body
end

async_http_request = function(premature, params)
  if premature then
    return
  end

  make_segment_request(params.url, params.json_data)
end

return SegmentService
