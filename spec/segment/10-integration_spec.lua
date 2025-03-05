local cjson = require "cjson"
local helpers = require "spec.helpers"

local PLUGIN_NAME = "segment"

-- Test data definition

local TEST_DATA = {
    VALID_REQUEST = {
        scheme = "https",
        host = "api.kpler.com",
        port = 443,
        path = "/v2/cargo/flows",
        raw_query = "flowDirection=Import&granularity=daily&split=Grades",
        query = {
            flowDirection = "Import",
            granularity = "daily",
            split = "Grades"
        },
        method = "GET",
        headers = {
            ["x-access-token"] =
            "eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9.eyJzdWIiOiIxMjM0NTY3ODkwIiwibmFtZSI6IkpvaG4gRG9lIiwiaWF0IjoxNTE2MjM5MDIyLCJodHRwczovL2twbGVyLmNvbS91c2VySWQiOiJiMDdjNjgwYy0xNGMxLTRiNDctOTMwZC0wZGRiMDFkOWE5ZTcifQ.sfqKB_35xeUdOoQxn9lcIKgoBUScInkj-dt8qpIkkns",
            ["user-agent"] = "Mozilla/5.0",
            ["x-kong-request-id"] = "sample-request-id"
        }
    },
    IP_ADDRESS = "222.222.222.222"
}

-- Helper functions

local function reset_log(logname)
    local client = assert(helpers.http_client(helpers.mock_upstream_host,
        helpers.mock_upstream_port))
    assert(client:send {
        method  = "DELETE",
        path    = "/reset_log/" .. logname,
        headers = {
            Accept = "application/json"
        }
    })
    client:close()
end


local function get_log(typ, n)
    local entries
    helpers.wait_until(function()
        local client = assert(helpers.http_client(helpers.mock_upstream_host,
            helpers.mock_upstream_port))
        local res = client:get("/read_log/" .. typ, {
            headers = {
                Accept = "application/json"
            }
        })
        local raw = assert.res_status(200, res)
        local body = cjson.decode(raw)

        entries = body.entries
        return #entries > 0
    end, 1000)
    if n then
        assert(#entries == n, "expected " .. n .. " log entries, but got " .. #entries)
    end
    return entries
end

local fixtures = {
    dns_mock = helpers.dns_mock.new({
        mocks_only = false
    }),
}

fixtures.dns_mock:A {
    name = "api.segment.io",
    address = "127.0.0.1"
}


-- Test Definition

for _, strategy in helpers.all_strategies() do
    if strategy ~= "cassandra" then
        describe(PLUGIN_NAME .. ": (access) [#" .. strategy .. "]", function()
            local client

            lazy_setup(function()
                local bp = helpers.get_db_utils(strategy == "off" and "postgres" or strategy, nil, { PLUGIN_NAME })

                local http_log_service = bp.services:insert({
                    protocol = "http",
                    host     = helpers.mock_upstream_host,
                    port     = helpers.mock_upstream_port,
                    path     = "/post_log/http",
                })

                local fake_segment_route = bp.routes:insert({
                    hosts = { "api.segment.io" },
                    service = http_log_service,
                    paths = { "/v1/track" },
                    strip_path = true,
                })

                -- Inject a test route. No need to create a service, there is a default
                -- service which will echo the request.
                local route1 = bp.routes:insert({
                    hosts = { "test1.com" }
                })
                -- add the plugin to test to the route we created
                bp.plugins:insert {
                    name = PLUGIN_NAME,
                    route = {
                        id = route1.id
                    },
                    config = {
                        write_key = "abcd",
                        segment_url = "http://api.segment.io:9000",
                    }
                }

                -- start kong
                assert(helpers.start_kong({
                    -- set the strategy
                    database = strategy,
                    -- use the custom test template to create a local mock server
                    nginx_conf = "spec/fixtures/custom_nginx.template",
                    -- make sure our plugin gets loaded
                    plugins = "bundled," .. PLUGIN_NAME,
                    -- write & load declarative config, only if 'strategy=off'
                    declarative_config = strategy == "off" and helpers.make_yaml_file() or nil
                }, nil, nil, fixtures))
            end)

            lazy_teardown(function()
                helpers.stop_kong(nil, true)
            end)

            before_each(function()
                reset_log("http")
                client = helpers.proxy_client()
            end)

            after_each(function()
                if client then
                    client:close()
                end
            end)

            describe("request", function()
                it("is successful", function()
                    local headers = table.clone(TEST_DATA.VALID_REQUEST.headers)
                    headers["host"] = "test1.com"
                    local r = client:get("/request", {
                        headers = headers
                    })
                    assert.response(r).has.status(200)
                    local entries = get_log("http", 1)
                    assert.is_same({
                        ["ip"] = '127.0.0.1',
                        ["userAgent"] = 'Mozilla/5.0'
                    }, entries[1].context)
                    assert.is_same({
                        ["host"] = 'test1.com',
                        ["path"] = '/request',
                        ["query_params"] = {},
                        ["url"] = 'http://test1.com:9000/request'
                    }, entries[1].properties)
                    assert.is_same('b07c680c-14c1-4b47-930d-0ddb01d9a9e7', entries[1].userId)
                    assert.is_same('abcd', entries[1].writeKey)
                end)
            end)
        end)
    end
end
