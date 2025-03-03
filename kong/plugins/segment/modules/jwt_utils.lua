local mime = require("mime")
local ngx = require("ngx")

local _M = {}

local AUTH_HEADER = "x-access-token"
local USER_ID_CLAIM = "https://kpler.com/userId"

local function get_token()
  local token = kong.request.get_header(AUTH_HEADER)
  if not token then
    return nil, "JWT not found"
  end
  return token, nil
end

local function get_claims(token)
  local parts = {}
  for part in token:gmatch("[^.]+") do
    table.insert(parts, part)
  end

  if #parts ~= 3 then
    return nil, "Invalid JWT format"
  end
  local payload_b64 = parts[2]

  local payload_json = ngx.decode_base64(payload_b64)

  if not payload_json then
    return nil, "Invalid Base64 encoding"
  end
  local payload = require("cjson").decode(payload_json)

  return payload, nil
end

function _M.get_user_id()
  local token, get_token_err = get_token()
  if get_token_err then
    return nil, get_token_err
  end

  local claims, get_claims_err = get_claims(token)
  if get_claims_err then
    return nil, get_claims_err
  end

  local userId = claims[USER_ID_CLAIM]
  if not userId then
    return nil, "Claim '" .. USER_ID_CLAIM .. "' not found in the passed token"
  end

  return userId, nil
end

return _M
