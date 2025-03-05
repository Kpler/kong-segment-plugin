local helpers = require "spec.helpers"
local http_mock = require "spec.helpers.http_mock"
local dns_helpers = require "spec.helpers.dns"
local PLUGIN_NAME = "segment"

for _, strategy in helpers.all_strategies() do
  if strategy ~= "cassandra" then
    describe(PLUGIN_NAME .. ": (access) [#" .. strategy .. "]", function()
      local client

      lazy_setup(function()
        local mock = http_mock.new(443, [[
  ngx.req.set_header("X-Test", "test")
  ngx.print("hello world")
]],  {
          prefix = "mockserver",
          log_opts = {
            resp = true,
            resp_body = true,
          },
          tls = true,
          hostname = "api.segment.io"
        })

        local dns_mock = helpers.dns_mock.new { mocks_only = true }

        local host = "api.segment.io"  -- must be the same for all entries obviously...
        local rec = dns_helpers.dnsA(client, {
          -- defaults: weight = 10, priority = 20, ttl = 600
          { name = host, address = "127.0.0.1", port = 443, ttl = 600 },
        })
        dns_mock:A(rec)

        mock:start()

        local bp = helpers.get_db_utils(strategy == "off" and "postgres" or strategy, nil, { PLUGIN_NAME })

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
            write_key = "abcd"
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
          declarative_config = strategy == "off" and helpers.make_yaml_file() or nil,

          fixtures = {
            dns_mock = dns_mock
          }
        }))
      end)

      lazy_teardown(function()
        helpers.stop_kong(nil, true)
      end)

      local mock_http

      before_each(function()
        client = helpers.proxy_client()
        -- Create a mock HTTP client
      end)

      after_each(function()
        if client then
          client:close()
        end
        http_mock.new:revert()
      end)

      describe("Segment event", function()
        it("Sends a segment event on the fly", function()
          local r = client:get("/request", {
            headers = {
              host = "test1.com",
              ["x-access-token"] = "eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9.eyJzdWIiOiIxMjM0NTY3ODkwIiwibmFtZSI6IkpvaG4gRG9lIiwiaWF0IjoxNTE2MjM5MDIyLCJodHRwczovL2twbGVyLmNvbS91c2VySWQiOiJiMDdjNjgwYy0xNGMxLTRiNDctOTMwZC0wZGRiMDFkOWE5ZTcifQ.sfqKB_35xeUdOoQxn9lcIKgoBUScInkj-dt8qpIkkns",
            }
          })

          ngx.sleep(5)

          assert.response(r).has.status(200)
        end)
      end)

    end)

  end
end
