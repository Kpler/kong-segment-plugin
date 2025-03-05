local SegmentAdapter = require("kong.plugins.segment.modules.segment_adapter")
local SegmentService = require("kong.plugins.segment.modules.segment_service")
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
  VERSION = "0.1"  -- version in X.Y.Z format. Check hybrid-mode compatibility requirements.
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

-- runs in the 'log_by_lua_block'
function plugin:log(plugin_conf)
  local segment_service = SegmentService:new(plugin_conf.write_key, plugin_conf.segment_url)
  local adapter = SegmentAdapter:new()
  local segmentEvent, err = adapter:convert()

  if err then
    kong.log.debug("Error building Segment event ", err)
    return
  end

  segment_service:track_async(segmentEvent)
end --

-- return our plugin object
return plugin
