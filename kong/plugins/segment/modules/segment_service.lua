local http = require("resty.http")

local SegmentService = {}

local SEGMENT_API = "https://api.segment.io/v1"

local function make_segment_request(url, json_data)
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

function async_http_request(premature, params)
  if premature then
    return
  end

  make_segment_request(params.url, params.json_data)
end

function SegmentService.track_async(segmentEvent)
  local url = SEGMENT_API .. "/track"
  local json_segment_data = segmentEvent:to_json()
  -- Schedule the HTTP request to be made asynchronously
  ngx.timer.at(0, async_http_request, {url = url, json_data = json_segment_data})
end

return SegmentService
