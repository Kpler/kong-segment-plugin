local cjson = require "cjson"

local PLUGIN_NAME = "segment"

-- Test data definition

local TEST_DATA = {
    VALID_REQUEST = {
        scheme = "https",
        host = "api.kpler.com",
        port = 443,
        path = "/v2/cargo/flows",
        raw_query = "flowDirection=Import&granularity=daily&split=Grades",
        method = "GET",
        headers = {
          [x-access-token] = "eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9.eyJzdWIiOiIxMjM0NTY3ODkwIiwibmFtZSI6IkpvaG4gRG9lIiwiaWF0IjoxNTE2MjM5MDIyLCJodHRwczovL2twbGVyLmNvbS91c2VySWQiOjF9.holp-rKGHuBhBF91ridgosecMobDjc0-n5vakZb7xdk",
          [user-agent] = "Mozilla/5.0",
          [x-kong-request-id] = "12345"
        }
    }
}

-- Fixtures definition

local build_kong_fixture = function()
    local state = {}
    return {
        log = {
            info = print,
            debug = print
        },
        request = {
            get_scheme = function()
                return state.request.scheme
            end,
            get_host = function()
                return state.request.host
            end,
            get_port = function()
                return state.request.port
            end,
            get_path = function()
                return state.request.path
            end,
            get_raw_query = function()
                return state.request.raw_query
            end
        },
        set_incoming_request = function(request)
            state.request = request
        end
    }
end

local build_segment_fixture = function()
    local state = {
        received_events = {}
    }
    return {
        resty_http_fixture = {
            new = function()
                return {
                    request_uri = function(self, url, options)
                        if not string.match(url, "^https://api%.segment%.io/") then
                            return nil, "DNS resolution failed"
                        elseif url == "https://api.segment.io/v1/track" and options.method == "POST" then
                            table.insert(state.received_events, cjson.decode(options.body))
                            return {
                                status = 200,
                                body = '{}'
                            }, nil
                        else
                            return {
                                status = 404,
                                body = ""
                            }, nil
                        end
                    end
                }
            end
        },
        get_received_events = function()
            return state.received_events
        end
    }
end

local build_ngx_fixture = function()
    return {
        timer = {
            at = function(delay, callback, url)
                -- No need to simulate async execution here, we just execute the callback immediately
                callback(false, url)
            end
        }
    }
end

-- Test definition

describe(PLUGIN_NAME .. ": (unit)", function()

    local plugin, config
    local segment_fixture

    before_each(function()
        -- overriding package loaded should happen before plugin loading
        segment_fixture = build_segment_fixture()
        package.loaded["resty.http"] = segment_fixture.resty_http_fixture

        _G.kong = build_kong_fixture()
        _G.ngx = build_ngx_fixture()

        plugin = require("kong.plugins." .. PLUGIN_NAME .. ".handler")
        config = {}
    end)

    describe("Given a valid request, when the plugin is executed,", function()
        before_each(function()
            kong.set_incoming_request(TEST_DATA.VALID_REQUEST)
            plugin:log(config)
        end)

        it("it should send a track event data to segment", function()
            local segment_received_events = segment_fixture.get_received_events()
            assert.is.equal(#segment_received_events, 1)
            assert.is.same(segment_received_events[1], {
                userId = "b07c680c-14c1-4b47-930d-0ddb01d9a9e7",
                messageId = "random-message-id",
                context = {
                  userAgent = "Mozilla/5.0",
                  ip = "222.222.222.222"
                },
                properties = {
                  url = "https://api.kpler.com/v2/cargo/products?query=value",
                  query_params = {
                    flowDirection = "Import",
                    granularity = "daily",
                    split = "Grades"
                  }
                },
            })
        end)

    end)
end)
