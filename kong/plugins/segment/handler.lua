local cjson = require "cjson"
local http = require("resty.http")
local jwt_utils = require("kong.plugins.segment.modules.jwt_utils")
local Event = require("kong.plugins.segment.modules.event")
-- If you're not sure your plugin is executing, uncomment the line below and restart Kong
-- then it will throw an error which indicates the plugin is being loaded at least.
-- assert(ngx.get_phase() == "timer", "The world is coming to an end!")
---------------------------------------------------------------------------------------------
-- In the code below, just remove the opening brackets; `[[` to enable a specific handler
--
-- The handlers are based on the OpenResty handlers, see the OpenResty docs for details
-- on when exactly they are invoked and what limitations each handler has.
---------------------------------------------------------------------------------------------
local plugin = {
    PRIORITY = 1000, -- set the plugin priority, which determines plugin execution order
    VERSION = "0.1" -- version in X.Y.Z format. Check hybrid-mode compatibility requirements.
}

-- do initialization here, any module level code runs in the 'init_by_lua_block',
-- before worker processes are forked. So anything you add here will run once,
-- but be available in all workers.

-- handles more initialization, but AFTER the worker process has been forked/created.
-- It runs in the 'init_worker_by_lua_block'
function plugin:init_worker()
    kong.log.debug("Initializing Segment plugin")
end -- ]]

---[[ Executed every time a plugin config changes.
-- This can run in the `init_worker` or `timer` phase.
-- @param configs table|nil A table with all the plugin configs of this plugin type.
function plugin:configure(configs)
    kong.log.notice("Configuring Segment plugin", (configs and #configs or 0), " configs")

    if configs == nil then
        return -- no configs, nothing to do
    end

    -- your custom code here

end -- ]]

--[[ runs in the 'ssl_certificate_by_lua_block'
-- IMPORTANT: during the `certificate` phase neither `route`, `service`, nor `consumer`
-- will have been identified, hence this handler will only be executed if the plugin is
-- configured as a global plugin!
function plugin:certificate(plugin_conf)

  -- your custom code here
  kong.log.debug("saying hi from the 'certificate' handler")

end --]]

local function make_http_request(url, data)
    local httpc = http.new()

    local json_data = cjson.encode(data)

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

local function async_http_request(premature, event)
    if premature then
        return
    end
    make_http_request("https://api.segment.io/v1/track", event:to_table())
end

-- runs in the 'log_by_lua_block'
function plugin:log(plugin_conf)

    local scheme = kong.request.get_scheme()
    local host = kong.request.get_host()
    local port = kong.request.get_port()
    local path = kong.request.get_path()
    local query = kong.request.get_raw_query()

    local userId, err = jwt_utils.get_user_id()

    if err then
      kong.log.warn(err)
      return
    end

    local event = Event:new(userId)

    local url = scheme .. "://" .. host
    if (scheme == "http" and port ~= 80) or (scheme == "https" and port ~= 443) then
        url = url .. ":" .. port
    end
    url = url .. path
    if query and query ~= "" then
        url = url .. "?" .. query
    end

    -- Schedule the HTTP request to be made asynchronously
    ngx.timer.at(0, async_http_request, event)

    kong.log.debug("Full URL: ", event)

end --

-- return our plugin object
return plugin
